"""디렉터 출력 대량 검증 도구 (Studio 불필요).

test_director.py와 같은 호출 방식(같은 프롬프트·스키마·모델·effort)을 쓴다.
게임의 WaveValidator.luau 규칙을 Python으로 옮겨 1건마다 판정한다.

사용법:
  python tools/eval_director.py fixtures/match_summaries/*.json --runs 4 --max-calls 32
  python tools/eval_director.py fixtures/match_summaries/team_a*.json fixtures/match_summaries/team_b*.json --compare team_a team_b --runs 3 --max-calls 18
  python tools/eval_director.py ... --dry-run   (호출 없이 계획만 출력)
  python tools/eval_director.py ... --max-calls 5   (기본 5, 크레딧 보호)

필요: pip install openai jsonschema / 환경 변수 MODEL_API_KEY
"""
import argparse
import copy
import datetime
import glob
import json
import os
import re
import statistics
import sys
import time

from openai import OpenAI
from jsonschema import validate, ValidationError

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.environ.get("DIRECTOR_MODEL", "muse-spark-1.3")
EFFORT = os.environ.get("DIRECTOR_EFFORT", "low")
# 단일 호출 대기 상한(초). day7b 지시: 모델 호출 1회 대기 최대 30초.
CALL_TIMEOUT = 30


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def parse_config():
    """src/shared/Config.luau에서 검증 수치를 정규식으로 읽는다. 숫자를 코드에 다시 적지 않는다."""
    src = load("src/shared/Config.luau")

    def num(key):
        m = re.search(r"\b" + key + r"\s*=\s*(\d+)", src)
        if not m:
            raise ValueError("Config.luau에서 %s를 찾지 못함" % key)
        return int(m.group(1))

    def strlist(key):
        m = re.search(r"\b" + key + r"\s*=\s*\{([^}]*)\}", src)
        if not m:
            raise ValueError("Config.luau에서 %s를 찾지 못함" % key)
        return re.findall(r'"([^"]+)"', m.group(1))

    return {
        "min_enemies": num("MinEnemies"),
        "max_enemies": num("MaxEnemies"),
        "blood_moon_min_wave": num("BloodMoonMinWave"),
        "timeout": num("RequestTimeoutSeconds"),
        "lanes": strlist("Lanes"),
        "enemy_types": strlist("EnemyTypes"),
        "tactics": strlist("Tactics"),
        "events": strlist("Events"),
    }


def scale_counts(entries, target):
    """WaveValidator.luau scaleCounts와 같은 방식: 비율 유지 + 최소 1마리 후 큰 항목부터 분배."""
    total = sum(e["count"] for e in entries)
    if total == target:
        return
    for e in entries:
        e["count"] = max(1, (e["count"] * target) // total)
    guard = 0
    while True:
        s = sum(e["count"] for e in entries)
        diff = target - s
        if diff == 0 or guard > 1000:
            break
        guard += 1
        entries.sort(key=lambda e: e["count"], reverse=True)
        if diff > 0:
            entries[0]["count"] += 1
        else:
            if entries[0]["count"] <= 1:
                break
            entries[0]["count"] -= 1


def is_positive_int(n):
    return isinstance(n, bool) is False and isinstance(n, int) and n >= 1


def validate_plan(plan, wave_number, cfg):
    """WaveValidator.validate를 Python으로 옮긴 것.

    returns (ok, clean_or_None, errors, autofixed):
      ok=False → fallback_reject (구조·enum 오류, 게임이 대체 웨이브를 쓴다)
      ok=True, errors 없음 → muse / errors 있음 → muse_autofix (총합 보정, blood_moon → none)
    """
    if not isinstance(plan, dict):
        return False, None, ["plan은 object여야 한다"], False
    if not isinstance(plan.get("wave_name"), str) or plan.get("wave_name") == "":
        return False, None, ["wave_name이 비었다"], False
    enemies = plan.get("enemies")
    if not isinstance(enemies, list) or len(enemies) == 0:
        return False, None, ["enemies가 비었다"], False
    if plan.get("tactic") not in cfg["tactics"]:
        return False, None, ["tactic이 허용 목록에 없다: %s" % plan.get("tactic")], False
    if plan.get("event") not in cfg["events"]:
        return False, None, ["event가 허용 목록에 없다: %s" % plan.get("event")], False
    if not isinstance(plan.get("director_note"), str) or plan.get("director_note") == "":
        return False, None, ["director_note가 비었다"], False
    for i, e in enumerate(enemies, 1):
        if not isinstance(e, dict):
            return False, None, ["enemies[%d]가 object가 아니다" % i], False
        if e.get("type") not in cfg["enemy_types"]:
            return False, None, ["enemies[%d].type이 허용 목록에 없다: %s" % (i, e.get("type"))], False
        if e.get("lane") not in cfg["lanes"]:
            return False, None, ["enemies[%d].lane이 허용 목록에 없다: %s" % (i, e.get("lane"))], False
        if not is_positive_int(e.get("count")):
            return False, None, ["enemies[%d].count는 1 이상의 정수여야 한다: %s" % (i, e.get("count"))], False

    clean = {
        "wave_name": plan["wave_name"],
        "enemies": [{"type": e["type"], "count": e["count"], "lane": e["lane"]} for e in enemies],
        "tactic": plan["tactic"],
        "event": plan["event"],
        "director_note": plan["director_note"],
    }
    errors = []
    total = sum(e["count"] for e in clean["enemies"])
    if total < cfg["min_enemies"]:
        scale_counts(clean["enemies"], cfg["min_enemies"])
        errors.append("총합 %d마리 < 최소 %d마리: 비율 유지하며 증량" % (total, cfg["min_enemies"]))
    elif total > cfg["max_enemies"]:
        scale_counts(clean["enemies"], cfg["max_enemies"])
        errors.append("총합 %d마리 > 최대 %d마리: 비율 유지하며 감량" % (total, cfg["max_enemies"]))
    if clean["event"] == "blood_moon" and (
        not isinstance(wave_number, int) or wave_number < cfg["blood_moon_min_wave"]
    ):
        clean["event"] = "none"
        errors.append("blood_moon은 %d웨이브부터: none으로 교체" % cfg["blood_moon_min_wave"])
    return True, clean, errors, len(errors) > 0


def request_plan(client, schema, prompt, summary_text):
    """test_director.py와 같은 호출. (plan_text, usage, elapsed) 또는 예외를 돌려준다."""
    start = time.time()
    res = client.chat.completions.create(
        model=MODEL,
        reasoning_effort=EFFORT,
        messages=[{"role": "system", "content": prompt},
                  {"role": "user", "content": summary_text}],
        response_format={"type": "json_schema",
                         "json_schema": {"name": "wave_plan", "strict": True, "schema": schema}},
        timeout=CALL_TIMEOUT,
    )
    elapsed = time.time() - start
    usage = res.usage
    return res.choices[0].message.content, usage, elapsed


def judge_call(summary_text, wave_number, client, schema, prompt, cfg):
    """1회 호출 → (verdict, plan_or_error, detail, elapsed, usage)."""
    try:
        text, usage, elapsed = request_plan(client, schema, prompt, summary_text)
    except Exception as e:
        name = type(e).__name__.lower()
        if "timeout" in name:
            return "fallback_timeout", {"error": str(e)}, "호출 타임아웃", 0.0, None
        return "fallback_error", {"error": str(e)}, "호출 오류: %s" % type(e).__name__, 0.0, None
    if elapsed > cfg["timeout"]:
        return "fallback_timeout", {"error": "late response"}, \
            "응답 %.1fs > 타임아웃 %ds" % (elapsed, cfg["timeout"]), elapsed, usage
    try:
        plan = json.loads(text)
    except Exception as e:
        return "fallback_error", {"error": str(e)}, "잘못된 JSON", elapsed, usage
    try:
        validate(plan, schema)
    except ValidationError as e:
        return "fallback_error", {"error": str(e.message)}, "스키마 실패", elapsed, usage
    ok, clean, errors, autofixed = validate_plan(plan, wave_number, cfg)
    if not ok:
        return "fallback_reject", plan, " / ".join(errors), elapsed, usage
    if autofixed:
        return "muse_autofix", clean, " / ".join(errors), elapsed, usage
    return "muse", clean, "", elapsed, usage


def collect_calls(files, runs, max_calls, dry_run, client, schema, prompt, cfg):
    """fixture × runs 순서로 최대 max_calls회 호출. 1건마다 결과 dict를 돌려준다."""
    calls = []
    for path in files:
        with open(path, encoding="utf-8") as f:
            summary_text = f.read()
        try:
            wave_number = json.loads(summary_text).get("wave")
        except Exception:
            wave_number = None
        for run in range(1, runs + 1):
            if len(calls) >= max_calls:
                return calls
            if dry_run:
                print("DRY %s run%d (호출 안 함)" % (os.path.basename(path), run))
                continue
            verdict, plan, detail, elapsed, usage = judge_call(
                summary_text, wave_number, client, schema, prompt, cfg)
            tok_in = usage.prompt_tokens if usage else 0
            tok_out = usage.completion_tokens if usage else 0
            calls.append({
                "fixture": os.path.basename(path),
                "wave": wave_number,
                "run": run,
                "verdict": verdict,
                "detail": detail,
                "elapsed_s": round(elapsed, 1),
                "tokens_in": tok_in,
                "tokens_out": tok_out,
                "plan": plan,
            })
            print("%s run%d | %s | %.1fs | in=%d out=%d %s"
                  % (os.path.basename(path), run, verdict, elapsed, tok_in, tok_out,
                     ("| " + detail) if detail else ""))
    return calls


def save_raw(calls, date_str):
    raw_dir = os.path.join(ROOT, "docs", "reports", "raw")
    os.makedirs(raw_dir, exist_ok=True)
    raw_path = os.path.join(raw_dir, "director_%s.jsonl" % date_str)
    with open(raw_path, "a", encoding="utf-8") as f:
        for c in calls:
            f.write(json.dumps(c, ensure_ascii=False) + "\n")
    return os.path.relpath(raw_path, ROOT).replace(os.sep, "/")


def write_eval_report(calls, date_str, raw_rel):
    total = len(calls)
    verdicts = ["muse", "muse_autofix", "fallback_reject", "fallback_error", "fallback_timeout"]
    counts = {v: sum(1 for c in calls if c["verdict"] == v) for v in verdicts}
    reasons = {}
    for c in calls:
        if c["verdict"] in ("muse_autofix", "fallback_reject", "fallback_error", "fallback_timeout") and c["detail"]:
            reasons[c["detail"]] = reasons.get(c["detail"], 0) + 1
    elapsed = [c["elapsed_s"] for c in calls]
    med = statistics.median(elapsed) if elapsed else 0
    mx = max(elapsed) if elapsed else 0
    avg_in = sum(c["tokens_in"] for c in calls) / total if total else 0
    avg_out = sum(c["tokens_out"] for c in calls) / total if total else 0
    bad = [c for c in calls if c["verdict"] == "muse"]
    breaking = [c for c in bad if breaks_game(c["plan"])]
    lines = []
    lines.append("# 디렉터 출력 대량 검증")
    lines.append("")
    lines.append("- 실행 날짜: %s / 모델: %s / effort: %s" % (date_str, MODEL, EFFORT))
    lines.append("- 총 호출: %d건" % total)
    lines.append("- 원본 응답: `%s` (키·헤더 제외)" % raw_rel)
    lines.append("")
    lines.append("## 판정별 건수·비율")
    lines.append("")
    lines.append("| 판정 | 건수 | 비율 | 뜻 |")
    lines.append("|---|---|---|---|")
    means = {
        "muse": "스키마 통과 + 검증 통과(보정 없음)",
        "muse_autofix": "검증 통과, 자동 보정 있음(총합 보정, blood_moon → none)",
        "fallback_reject": "검증 거부(구조·enum 오류) → 대체 웨이브",
        "fallback_error": "HTTP 오류, 잘못된 JSON, 스키마 실패 → 대체 웨이브",
        "fallback_timeout": "응답이 타임아웃보다 늦음 → 대체 웨이브",
    }
    for v in verdicts:
        pct = (100.0 * counts[v] / total) if total else 0
        lines.append("| %s | %d | %.1f%% | %s |" % (v, counts[v], pct, means[v]))
    lines.append("")
    lines.append("## 거부·보정 사유")
    lines.append("")
    if reasons:
        for detail, n in sorted(reasons.items(), key=lambda kv: -kv[1]):
            lines.append("- %d건: %s" % (n, detail))
    else:
        lines.append("- 없음")
    lines.append("")
    lines.append("## 응답 시간·토큰")
    lines.append("")
    lines.append("- 응답 시간 중앙값 %.1fs · 최댓값 %.1fs (게임 타임아웃 %ds와 비교)"
                 % (med, mx, parse_config()["timeout"]))
    lines.append("- 평균 토큰: 입력 %.0f / 출력 %.0f" % (avg_in, avg_out))
    lines.append("")
    lines.append('## "경기를 깨뜨리는 출력"의 정의와 결과')
    lines.append("")
    lines.append("대체 웨이브로 넘어간 경우(거부·오류·타임아웃·보정)는 경기가 계속되므로 깨진 것이 아니다. "
                 "깨진 것은 검증을 통과했는데 게임 규칙에 어긋나는 계획이다. "
                 "예를 들어 총합이 Min~Max 밖인데 그대로 적용되거나, 이른 웨이브의 blood_moon이 그대로 "
                 "나오거나, 허용 목록에 없는 적·성문·전술·이벤트가 적용되는 경우다. "
                 "검증기가 이런 경우를 모두 걸러내므로 muse 판정은 깨뜨리지 않는다.")
    lines.append("")
    if breaking:
        lines.append("- 깨뜨리는 출력 %d건:" % len(breaking))
        for c in breaking:
            lines.append("  - %s run%d: %s" % (c["fixture"], c["run"], json.dumps(c["plan"], ensure_ascii=False)))
    else:
        lines.append("- 깨뜨리는 출력 0건 (muse %d건 모두 게임 규칙 안)" % len(bad))
    lines.append("")
    out = os.path.join(ROOT, "docs", "reports", "director_eval.md")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("보고서: %s" % os.path.relpath(out, ROOT))


def breaks_game(plan):
    """검증을 통과한 계획이 게임 규칙에 어긋나는지 마지막으로 확인한다. 현재 검증기가 거르는 항목과 같다."""
    try:
        cfg = parse_config()
        total = sum(e["count"] for e in plan["enemies"])
        if total < cfg["min_enemies"] or total > cfg["max_enemies"]:
            return True
        for e in plan["enemies"]:
            if e["type"] not in cfg["enemy_types"] or e["lane"] not in cfg["lanes"]:
                return True
        if plan["tactic"] not in cfg["tactics"] or plan["event"] not in cfg["events"]:
            return True
        return False
    except Exception:
        return True


def team_summary(calls):
    """팀별 집계: 성문별 적 수 합계, 전술·이벤트 분포, 메모 예시."""
    lane_total = {}
    tactics = {}
    events = {}
    memos = []
    for c in calls:
        plan = c.get("plan") or {}
        if not isinstance(plan, dict) or not isinstance(plan.get("enemies"), list):
            continue
        for e in plan["enemies"]:
            if isinstance(e, dict):
                lane_total[e.get("lane")] = lane_total.get(e.get("lane"), 0) + e.get("count", 0)
        tactics[plan.get("tactic")] = tactics.get(plan.get("tactic"), 0) + 1
        events[plan.get("event")] = events.get(plan.get("event"), 0) + 1
        if plan.get("director_note"):
            memos.append("(%s) %s" % (c["fixture"], plan["director_note"]))
    return lane_total, tactics, events, memos


def write_compare_report(groups, date_str):
    lines = []
    lines.append("# 두 팀 비교 (데모 근거)")
    lines.append("")
    lines.append("- 실행 날짜: %s / 모델: %s / effort: %s" % (date_str, MODEL, EFFORT))
    lines.append("")
    for name, calls in groups:
        lane_total, tactics, events, memos = team_summary(calls)
        lines.append("## %s (%d회)" % (name, len(calls)))
        lines.append("")
        lines.append("- 성문별 적 수 합계: %s"
                     % (", ".join("%s %d" % kv for kv in sorted(lane_total.items())) or "없음"))
        lines.append("- 전술 분포: %s"
                     % (", ".join("%s %d" % kv for kv in sorted(tactics.items())) or "없음"))
        lines.append("- 이벤트 분포: %s"
                     % (", ".join("%s %d" % kv for kv in sorted(events.items())) or "없음"))
        lines.append("- 디렉터 메모 예시:")
        for m in memos[:2]:
            lines.append("  - %s" % m)
        lines.append("")
    out = os.path.join(ROOT, "docs", "reports", "team_compare.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("보고서: %s (3줄 요약·장면 추천은 데이터 확인 뒤 사람이 적는다)" % os.path.relpath(out, ROOT))


def main(argv):
    ap = argparse.ArgumentParser(description="디렉터 출력 대량 검증")
    ap.add_argument("paths", nargs="*", help="매치 요약 fixture (glob 가능)")
    ap.add_argument("--runs", type=int, default=1, help="fixture당 반복 횟수")
    ap.add_argument("--max-calls", type=int, default=5, help="모델 호출 상한 (기본 5)")
    ap.add_argument("--dry-run", action="store_true", help="호출 없이 계획만 출력")
    ap.add_argument("--compare", nargs=2, metavar=("TEAM_A", "TEAM_B"),
                    help="파일명에 각 접두가 든 fixture를 두 팀으로 나눠 비교 보고서를 쓴다")
    args = ap.parse_args(argv)

    files = [p for pat in args.paths for p in sorted(glob.glob(pat))]
    if not files:
        sys.exit("fixture이 없다: %s" % args.paths)
    print("계획: 파일 %d개 × %d회, 상한 %d회%s"
          % (len(files), args.runs, args.max_calls, " (dry-run)" if args.dry_run else ""))
    if args.dry_run:
        collect_calls(files, args.runs, args.max_calls, True, None, None, None, parse_config())
        return

    cfg = parse_config()
    schema = json.loads(load("schemas/wave_plan.schema.json"))
    prompt = load("src/server/Director/prompt.txt")
    client = OpenAI(base_url="https://api.meta.ai/v1", api_key=os.environ["MODEL_API_KEY"])
    date_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

    if args.compare:
        groups = []
        used = 0
        for team in args.compare:
            team_files = [p for p in files if os.path.basename(p).startswith(team)]
            if not team_files:
                sys.exit("접두 '%s'에 맞는 파일이 없다" % team)
            print("== %s: 파일 %d개" % (team, len(team_files)))
            cs = collect_calls(team_files, args.runs, max(0, args.max_calls - used), False,
                               client, schema, prompt, cfg)
            used += len(cs)
            groups.append((team, cs))
        all_calls = [c for _, cs in groups for c in cs]
        save_raw(all_calls, date_str)
        write_compare_report(groups, date_str)
        return

    calls = collect_calls(files, args.runs, args.max_calls, False, client, schema, prompt, cfg)
    raw_rel = save_raw(calls, date_str)
    write_eval_report(calls, date_str, raw_rel)


if __name__ == "__main__":
    main(sys.argv[1:])
