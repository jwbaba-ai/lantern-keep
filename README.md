# roblox-ai-director (스타터 키트)

## 오늘 저녁 설정 순서
1. 이 폴더를 원하는 위치에 풀고 `git init` → **첫 커밋은 10/27 13:00(한국) 이후에** (빌드 기간 시작)
2. `AGENTS.md`의 "게임 정보 (TODO)" 채우기
3. `schemas/wave_plan.schema.json`의 enum(적 종류, 레인, 전술, 이벤트)을 실제 게임 값으로 교체 → `python tools/gen_schema_luau.py`
4. `pip install openai jsonschema` → `python tools/test_director.py fixtures/match_summaries/*.json`
5. 데모 플레이스에서 `rojo serve` → 스튜디오 Rojo 플러그인으로 연결
6. 스튜디오: Experience Settings > Security > Allow HTTP Requests, Local Secrets(`meta_api_key`), Enable Studio Access to API Services
7. Creator Dashboard > 데모 게임 > Secrets > `meta_api_key` (도메인 `api.meta.ai`)
8. `muse` 실행 → 워크스페이스 신뢰 → "AGENTS.md 규칙을 요약해 줘"로 인식 확인
9. 기존 게임 코드를 가져올 경우 `docs/ORIGINS.md`에 반드시 기록

`prompt.txt`는 Rojo가 스튜디오에 `prompt`라는 StringValue로 넣습니다. DirectorClient가 이 값을 읽습니다.
