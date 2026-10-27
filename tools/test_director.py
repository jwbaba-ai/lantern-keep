"""PC에서 디렉터 프롬프트를 시험하는 도구 (스튜디오 불필요).

사용법:
  python tools/test_director.py fixtures/match_summaries/wave3_north_breach.json
  python tools/test_director.py fixtures/match_summaries/*.json   (여러 개 한 번에)
필요: pip install openai jsonschema / 환경 변수 MODEL_API_KEY
"""
import glob, json, os, sys, time
from openai import OpenAI
from jsonschema import validate

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.environ.get("DIRECTOR_MODEL", "muse-spark-1.3")
EFFORT = os.environ.get("DIRECTOR_EFFORT", "low")

def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()

def main(paths):
    client = OpenAI(base_url="https://api.meta.ai/v1", api_key=os.environ["MODEL_API_KEY"])
    schema = json.loads(load("schemas/wave_plan.schema.json"))
    prompt = load("src/server/Director/prompt.txt")
    files = [p for arg in paths for p in glob.glob(arg)]
    for path in files:
        with open(path, encoding="utf-8") as f:
            summary = f.read()
        start = time.time()
        try:
            res = client.chat.completions.create(
                model=MODEL,
                reasoning_effort=EFFORT,
                messages=[{"role": "system", "content": prompt},
                          {"role": "user", "content": summary}],
                response_format={"type": "json_schema",
                                 "json_schema": {"name": "wave_plan", "strict": True, "schema": schema}},
            )
            plan = json.loads(res.choices[0].message.content)
            validate(plan, schema)
            status = "OK"
        except Exception as e:  # 실패도 결과로 기록
            plan, status, res = {"error": str(e)}, "FAIL", None
        took = time.time() - start
        usage = res.usage if res else None
        print(f"\n=== {os.path.basename(path)} | {status} | {took:.1f}s | model={MODEL} effort={EFFORT}")
        if usage:
            print(f"tokens: in={usage.prompt_tokens} out={usage.completion_tokens}")
        print(json.dumps(plan, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
