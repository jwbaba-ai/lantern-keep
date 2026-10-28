"""NPC 출력 검증 도구 (Studio 불필요).

test_npc.py와 같은 호출 방식(같은 프롬프트·스키마·모델·effort)을 쓴다.
게임의 MemoryStore.validate 규칙을 Python으로 옮기고, 사건 언급률도 잰다.

사용법:
  python tools/eval_npc.py fixtures/npc_memory/*.json --runs 3 --max-calls 9
  python tools/eval_npc.py ... --dry-run   (호출 없이 계획만 출력)
  python tools/eval_npc.py ... --max-calls 5   (기본 5, 크레딧 보호)

필요: pip install openai jsonschema / 환경 변수 MODEL_API_KEY
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys
import time

from openai import OpenAI
from jsonschema import validate, ValidationError

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.environ.get("NPC_MODEL", os.environ.get("DIRECTOR_MODEL", "muse-spark-1.3"))
EFFORT = os.environ.get("DIRECTOR_EFFORT", "low")
# 단일 호출 대기 상한(초). day7b 지시: 모델 호출 1회 대기 최대 30초.
CALL_TIMEOUT = 30

LANE_KO = {"north": "북문", "south": "남문", "east": "동문", "west": "서문"}


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def party_size_of(payload):
    """test_npc.py와 같은 방식: events 플레이어 슬롯 최댓값."""
    slots = set()
    for ev in payload.get("events", []):
        for p in ev.get("players", []):
            m = re.fullmatch(r"P(\d+)", p.get("slot", ""))
            if m:
                slots.add(int(m.group(1)))
    return max(slots) if slots else 0


def check_lines(plan, party_size):
    """MemoryStore.validate를 Python으로 옮긴 것: 줄 수 각 3개, 각 줄 1~80자, P 토큰은 파티 안에서만."""
    problems = []
    for key in ("bram_lines", "mira_lines"):
        lines = plan.get(key, [])
        if not isinstance(lines, list) or len(lines) != 3:
            problems.append("%s count=%s" % (key, len(lines) if isinstance(lines, list) else "?"))
            continue
        for line in lines:
            ln = len(line) if isinstance(line, str) else -1
            if not (1 <= ln <= 80):
                problems.append("%s length=%d" % (key, ln))
    texts = []
    for key in ("bram_memory", "mira_memory"):
        if isinstance(plan.get(key), str):
            texts.append(plan[key])
    for key in ("bram_lines", "mira_lines"):
        if isinstance(plan.get(key), list):
            texts.extend(l for l in plan[key] if isinstance(l, str))
    for text in texts:
        for n in re.findall(r"P(\d+)", text):
            if int(n) < 1 or int(n) > party_size:
                problems.append("bad token P%s (party %d)" % (n, party_size))
                break
    for key in ("bram_memory", "mira_memory"):
        if not isinstance(plan.get(key), str) or plan.get(key) == "":
            problems.append("%s 비었음" % key)
    return problems


def event_markers(payload):
    """언급 판정용 표식: events 안의 성문 이름(영문·한글)과 웨이브 번호 패턴."""
    lanes = set()
    waves = set()
    for ev in payload.get("events", []):
        for w in ev.get("waves", []):
            if w.get("breached_lane"):
                lanes.add(w["breached_lane"])
            if isinstance(w.get("wave"), int):
                waves.add(w["wave"])
    markers = []
    for lane in lanes:
        markers.append(lane)
        if lane in LANE_KO:
            markers.append(LANE_KO[lane])
    wave_pats = []
    for n in waves:
        wave_pats.append(re.compile(r"웨이브\s*%d" % n))
        wave_pats.append(re.compile(r"%d\s*웨이브" % n))
        wave_pats.append(re.compile(r"wave\s*%d" % n, re.IGNORECASE))
    return markers, wave_pats


def mentions_event(plan, payload):
    """입력 events의 성문 이름이나 웨이브 번호가 대사에 한 번 이상 나오면 True와 근거를 돌려준다."""
    markers, wave_pats = event_markers(payload)
    if not markers and not wave_pats:
        return False, "표식 없음"
    lines = []
    for key in ("bram_lines", "mira_lines"):
        if isinstance(plan.get(key), list):
            lines.extend(l for l in plan[key] if isinstance(l, str))
    for line in lines:
        for mk in markers:
            if mk and mk in line:
                return True, "성문 언급: %s" % mk
        for pat in wave_pats:
            m = pat.search(line)
            if m:
                return True, "웨이브 언급: %s" % m.group(0)
    return False, "언급 없음"


def main(argv):
    ap = argparse.ArgumentParser(description="NPC 출력 검증")
    ap.add_argument("paths", nargs="*", help="npc 기억 fixture (glob 가능)")
    ap.add_argument("--runs", type=int, default=1, help="fixture당 반복 횟수")
    ap.add_argument("--max-calls", type=int, default=5, help="모델 호출 상한 (기본 5)")
    ap.add_argument("--dry-run", action="store_true", help="호출 없이 계획만 출력")
    args = ap.parse_args(argv)

    files = [p for pat in args.paths for p in sorted(glob.glob(pat))]
    if not files:
        sys.exit("fixture이 없다: %s" % args.paths)
    print("계획: 파일 %d개 × %d회, 상한 %d회%s"
          % (len(files), args.runs, args.max_calls, " (dry-run)" if args.dry_run else ""))

    schema = json.loads(load("schemas/npc_memory.schema.json"))
    prompt = load("src/server/NpcMemory/prompt.txt")
    client = None
    if not args.dry_run:
        client = OpenAI(base_url="https://api.meta.ai/v1", api_key=os.environ["MODEL_API_KEY"])
    date_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

    results = []
    calls = 0
    for path in files:
        with open(path, encoding="utf-8") as f:
            payload = json.load(f)
        party_size = party_size_of(payload)
        for run in range(1, args.runs + 1):
            if calls >= args.max_calls:
                break
            if args.dry_run:
                print("DRY %s run%d (호출 안 함)" % (os.path.basename(path), run))
                continue
            calls += 1
            start = time.time()
            try:
                res = client.chat.completions.create(
                    model=MODEL,
                    reasoning_effort=EFFORT,
                    messages=[{"role": "system", "content": prompt},
                              {"role": "user", "content": json.dumps(payload, ensure_ascii=False)}],
                    response_format={"type": "json_schema",
                                     "json_schema": {"name": "npc_memory", "strict": True, "schema": schema}},
                    timeout=CALL_TIMEOUT,
                )
                plan = json.loads(res.choices[0].message.content)
                validate(plan, schema)
                problems = check_lines(plan, party_size)
                status = "OK" if not problems else "FAIL:" + ",".join(problems)
                usage = res.usage
                tok = (usage.prompt_tokens, usage.completion_tokens) if usage else (0, 0)
            except Exception as e:
                plan, status, tok = {"error": str(e)}, "FAIL:" + type(e).__name__, (0, 0)
            elapsed = time.time() - start
            mentioned, why = (False, "오류") if "error" in plan else mentions_event(plan, payload)
            results.append({"fixture": os.path.basename(path), "run": run, "status": status,
                            "mentioned": mentioned, "why": why, "elapsed_s": round(elapsed, 1),
                            "tokens_in": tok[0], "tokens_out": tok[1], "plan": plan})
            print("%s run%d | %s | 언급=%s(%s) | %.1fs | in=%d out=%d"
                  % (os.path.basename(path), run, status, "함" if mentioned else "없음",
                     why, elapsed, tok[0], tok[1]))
        if calls >= args.max_calls:
            break

    if args.dry_run:
        return
    total = len(results)
    ok = sum(1 for r in results if r["status"] == "OK")
    ment = sum(1 for r in results if r["mentioned"])
    fails = {}
    for r in results:
        if r["status"] != "OK":
            fails[r["status"]] = fails.get(r["status"], 0) + 1
    avg_in = sum(r["tokens_in"] for r in results) / total if total else 0
    avg_out = sum(r["tokens_out"] for r in results) / total if total else 0
    lines = []
    lines.append("# NPC 출력 검증")
    lines.append("")
    lines.append("- 실행 날짜: %s / 모델: %s / effort: %s" % (date_str, MODEL, EFFORT))
    lines.append("- 총 호출: %d건 (fixture %d개 × 최대 %d회)" % (total, len(files), args.runs))
    lines.append("")
    lines.append("## 검증 통과율")
    lines.append("")
    lines.append("- 통과 %d/%d건 (%.1f%%)" % (ok, total, 100.0 * ok / total if total else 0))
    if fails:
        for st, n in sorted(fails.items(), key=lambda kv: -kv[1]):
            lines.append("  - %d건: %s" % (n, st))
    lines.append("- 규칙: 줄 수 각 3개, 각 줄 1~80자, P 토큰은 파티 인원 안에서만 "
                 "(MemoryStore.validate와 같은 규칙)")
    lines.append("")
    lines.append("## 사건 언급률")
    lines.append("")
    lines.append("- 언급 %d/%d건 (%.1f%%)" % (ment, total, 100.0 * ment / total if total else 0))
    lines.append("- 기준: 입력 events의 성문 이름(영문·한글)이나 웨이브 번호가 대사 6줄 중 한 번 이상 나오면 언급함. "
                 "성공 기준 'NPC가 지난 판을 언급'의 근거다.")
    for r in results:
        lines.append("  - %s run%d: %s (%s)" % (r["fixture"], r["run"],
                                                "언급함" if r["mentioned"] else "언급 없음", r["why"]))
    lines.append("")
    lines.append("## 평균 토큰")
    lines.append("")
    lines.append("- 입력 %.0f / 출력 %.0f" % (avg_in, avg_out))
    lines.append("")
    good = [r for r in results if r["status"] == "OK" and r["mentioned"]]
    if good:
        lines.append("## 언급 성공 대사 예시")
        lines.append("")
        for r in good[:2]:
            plan = r["plan"]
            lines.append("- %s run%d:" % (r["fixture"], r["run"]))
            for i, (b, m) in enumerate(zip(plan["bram_lines"], plan["mira_lines"]), 1):
                lines.append("  - %d. Bram: %s / Mira: %s" % (i, b, m))
        lines.append("")
    out = os.path.join(ROOT, "docs", "reports", "npc_eval.md")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("보고서: %s" % os.path.relpath(out, ROOT).replace(os.sep, "/"))


if __name__ == "__main__":
    main(sys.argv[1:])
