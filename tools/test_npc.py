"""PC에서 NPC 기억 프롬프트를 시험하는 도구 (스튜디오 불필요).

사용법:
  python tools/test_npc.py fixtures/npc_memory/first_loss.json
  python tools/test_npc.py fixtures/npc_memory/*.json   (여러 개 한 번에)
필요: pip install openai jsonschema / 환경 변수 MODEL_API_KEY
"""
import glob, json, os, re, sys, time
from openai import OpenAI
from jsonschema import validate

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.environ.get("NPC_MODEL", os.environ.get("DIRECTOR_MODEL", "muse-spark-1.3"))
EFFORT = os.environ.get("DIRECTOR_EFFORT", "low")

def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()

def party_size_of(payload):
    slots = set()
    for ev in payload.get("events", []):
        for p in ev.get("players", []):
            m = re.fullmatch(r"P(\d+)", p.get("slot", ""))
            if m:
                slots.add(int(m.group(1)))
    return max(slots) if slots else 0

def check_lines(plan, party_size):
    problems = []
    for key in ("bram_lines", "mira_lines"):
        lines = plan.get(key, [])
        if len(lines) != 3:
            problems.append(f"{key} count={len(lines)}")
        for line in lines:
            if not (1 <= len(line) <= 80):
                problems.append(f"{key} length={len(line)}")
            for n in re.findall(r"P(\d+)", line):
                if int(n) < 1 or int(n) > party_size:
                    problems.append(f"{key} bad token P{n} (party {party_size})")
    return problems

def main(paths):
    client = OpenAI(base_url="https://api.meta.ai/v1", api_key=os.environ["MODEL_API_KEY"])
    schema = json.loads(load("schemas/npc_memory.schema.json"))
    prompt = load("src/server/NpcMemory/prompt.txt")
    files = [p for arg in paths for p in glob.glob(arg)]
    for path in files:
        with open(path, encoding="utf-8") as f:
            payload = json.load(f)
        start = time.time()
        try:
            res = client.chat.completions.create(
                model=MODEL,
                reasoning_effort=EFFORT,
                messages=[{"role": "system", "content": prompt},
                          {"role": "user", "content": json.dumps(payload, ensure_ascii=False)}],
                response_format={"type": "json_schema",
                                 "json_schema": {"name": "npc_memory", "strict": True, "schema": schema}},
            )
            plan = json.loads(res.choices[0].message.content)
            validate(plan, schema)
            problems = check_lines(plan, party_size_of(payload))
            status = "OK" if not problems else "FAIL:" + ",".join(problems)
        except Exception as e:  # 실패도 결과로 기록
            plan, status, res = {"error": str(e)}, "FAIL", None
        took = time.time() - start
        usage = res.usage if res else None
        print(f"\n=== {os.path.basename(path)} | {status} | {took:.1f}s | model={MODEL} effort={EFFORT}")
        if usage:
            print(f"tokens: in={usage.prompt_tokens} out={usage.completion_tokens}")
        if "error" in plan:
            print(json.dumps(plan, indent=2, ensure_ascii=False))
        else:
            print("bram_memory: " + plan["bram_memory"])
            print("mira_memory: " + plan["mira_memory"])
            for i, (b, m) in enumerate(zip(plan["bram_lines"], plan["mira_lines"]), 1):
                print(f"{i}. Bram: {b} / Mira: {m}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
