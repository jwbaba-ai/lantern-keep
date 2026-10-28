"""schemas/*.schema.json → src/shared/*.luau 생성. 스키마를 고칠 때마다 실행."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SCHEMAS = {
    "schemas/wave_plan.schema.json": "src/shared/WaveSchema.luau",
    "schemas/npc_memory.schema.json": "src/shared/NpcMemorySchema.luau",
}

def to_luau(v, indent=0):
    pad, inner = "\t" * indent, "\t" * (indent + 1)
    if isinstance(v, dict):
        if not v:
            return "{}"
        items = [f'{inner}["{k}"] = {to_luau(x, indent + 1)},' for k, x in v.items()]
        return "{\n" + "\n".join(items) + f"\n{pad}}}"
    if isinstance(v, list):
        if not v:
            return "{}"
        return "{ " + ", ".join(to_luau(x, indent + 1) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    if isinstance(v, (int, float)):
        return repr(v)
    return json.dumps(v, ensure_ascii=False)

def main():
    for schema_rel, out_rel in SCHEMAS.items():
        with open(os.path.join(ROOT, schema_rel), encoding="utf-8") as f:
            schema = json.load(f)
        out = ("-- 자동 생성 파일: 직접 고치지 말고 " + schema_rel + " 수정 후\n"
               "-- python tools/gen_schema_luau.py 를 실행하세요.\n"
               f"return {to_luau(schema)}\n")
        with open(os.path.join(ROOT, out_rel), "w", encoding="utf-8") as f:
            f.write(out)
        print("generated " + out_rel)

if __name__ == "__main__":
    main()
