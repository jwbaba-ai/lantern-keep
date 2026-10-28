# Day 5 작업 지시 (2026-10-31) — "NPC 동료가 지난 판을 기억하고 말한다"

먼저 AGENTS.md, docs/GAME_DESIGN.md("NPC 동료" 절), 가장 최근 `docs/devlog/` 파일(day4 결과)을 읽는다.
오늘 목표: **두 번째 판을 시작하면 Bram과 Mira가 첫 판에서 실제로 있었던 일을 말한다.** 해커톤 성공 기준("플레이테스터가 NPC가 지난 판을 언급한다는 걸 알아챔")이 걸린 작업이다.

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다.
- `schemas/wave_plan.schema.json`, `src/shared/WaveSchema.luau`, `src/server/Director/prompt.txt`는 고치지 않는다.
- `src/shared/Config.luau`는 **새 키 추가만** 허용한다. 추가한 키는 devlog에 적는다.
- 환경 설정·패키지 설치 명령 금지. 30초 넘게 멈추는 명령은 중단하고 보고한다.
- **개인 데이터 금지**: NPC 기억에는 게임 안 사건(직업, 피해량, 사망, 부활, 뚫린 성문, 결과)만 저장한다. 채팅·이름·외부 정보는 저장하지 않는다. **모델에 보내는 데이터에는 userId와 이름을 넣지 않는다**(플레이어는 `P1`~`P4`로만 부른다).
- **AI 대사는 TextService 필터를 거친 뒤에만 표시**하고, 실패하면 기본 대사를 쓴다. AI 대사 아래에는 "AI가 생성한 대사입니다"를 표시한다.
- **모델 호출은 경기가 끝난 뒤 1회만** 한다(전투 중 호출 금지). 다음 판에서 쓸 대사도 이때 미리 받아 저장한다. 실패하면 기억 요약 없이 사건만 저장하고, 다음 판은 기본 대사로 진행한다.
- 시간이 부족하면 Mira를 빼고 Bram만 완성한다(GAME_DESIGN 범위 축소 규칙). 그 경우 devlog에 적는다.

## 0단계: day4 확인 결과 반영
- day4 devlog의 체크리스트에 사람이 남긴 메모가 있으면 먼저 그 문제부터 고치고 커밋한다.
- **day4 리뷰 수정 (Claude Code)**: 대기 중에 보내는 다음 웨이브 정보(`DirectorState`의 `lanes`, `GateHighlight.start`)가 **파티 인원 보정 전** 계획을 쓴다. 그래서 배너에는 "북문 12"가 나왔다가, 실제 웨이브에는 6마리가 나온다. 대기 중 미리보기에도 웨이브 시작 때와 같은 `PartyScale.scalePlan` 결과를 쓴다(웨이브 시작 시점에 인원이 바뀌면 그때 다시 보정). `DirectorState.spec`에 "보정한 plan을 넘기면 lanes 합계 = 보정 합계" 1건을 추가한다.
- **[높음] 웨이브 1 배너가 비어 있음** (day4 Studio 테스트): `src/client/WaveBanner.client.luau`가 `DirectorState.Changed` 때만 그린다. 웨이브 1 상태는 클라이언트가 접속하기 전에 이미 설정되어 있어서, 첫 웨이브 동안 글자가 비어 있다. 스크립트 시작 시 `Value`가 비어 있지 않으면 한 번 그린다. `LanternBar`도 같은 방식인지 확인하고, 같으면 똑같이 고친다.
- **[중간] 플레이어가 들어오기 전에 경기가 시작됨** (Output `wave=1 party=0`): `DirectorService`가 웨이브 1을 시작하기 전에 플레이어가 1명 이상 들어오고 모두 직업을 고를 때까지 기다린다. 최대 `MatchStartWaitSeconds`(Config 새 키, 시작값 20)까지만 기다리고, 그래도 0명이면 지금처럼 자동 테스트로 진행한다. 기다리는 동안 배너에 "곧 시작합니다 · N초"를 표시한다(`phase="lobby"`).

## 1단계: 응답 스키마 (사람(Babazz) 승인됨 2026-10-28 — 아래 그대로 만든다)
`schemas/npc_memory.schema.json` (strict 규칙: 모든 객체 `additionalProperties: false`, 모든 속성 `required`, 재귀 없음)
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["bram_memory", "mira_memory", "bram_lines", "mira_lines"],
  "properties": {
    "bram_memory": { "type": "string", "description": "Bram's 1-2 sentence memory of this party's battles (gates, waves, results). Use P1..P4 for players." },
    "mira_memory": { "type": "string", "description": "Mira's 1-2 sentence memory of individual players (who revived, who fell, who hit hardest). Use P1..P4 for players." },
    "bram_lines": { "type": "array", "items": { "type": "string" }, "description": "Exactly 3 short lines Bram will say next match: greeting, after wave 1, after wave 3." },
    "mira_lines": { "type": "array", "items": { "type": "string" }, "description": "Exactly 3 short lines Mira will say next match: greeting, after wave 1, after wave 3." }
  }
}
```
- `python tools/gen_schema_luau.py`가 이 파일도 Luau(`src/shared/NpcMemorySchema.luau`)로 만들 수 있게 도구를 확장한다(기존 WaveSchema 출력은 바이트 단위로 그대로여야 한다 — 실행 전후 `git diff --exit-code src/shared/WaveSchema.luau`로 확인).

## 2단계: NPC 프롬프트 (`src/server/NpcMemory/prompt.txt`)
- 영어로 쓴다. 내용:
  - Bram은 노장 대장으로, 전투(성문, 웨이브, 승패)를 기억하고 무뚝뚝하지만 따뜻하다.
  - Mira는 견습 치유사로, 플레이어 개인(누가 살렸는지, 누가 쓰러졌는지)을 기억하고 밝다.
  - 대사는 **한국어**, 각 줄 60자 이내다.
  - 지난 판에 **실제로 있었던 사건을 구체적으로** 언급한다(성문 이름, 웨이브 번호, 직업).
  - 플레이어는 `P1`~`P4`로만 부르고, 입력에 없는 사건은 지어내지 않는다.
- 게임과 PC 도구가 같은 파일을 쓴다.

## 3단계: 경기 사건 기록 (`src/server/NpcMemory/MatchRecord.luau`)
- `DirectorService`가 웨이브마다 이미 만드는 `MatchStats` 요약을 받아 경기 기록을 쌓는다.
  - 웨이브별: `wave`, `breached_lane`, `lantern_health_pct`, `revives`
  - 플레이어별 누적: `{ slot = "P1", role, damage, deaths, revives_given }`
  - 경기 결과: `result`(victory/defeat), `waves_completed`
- `P1`~`P4`는 **userId 오름차순**으로 붙인다. 화면에 표시할 때만 서버에서 `P1` → 그 플레이어의 DisplayName으로 바꾼다. 이름 치환은 필터를 거친 **뒤**에 한다.
- cleric 부활(`revives_given`)을 플레이어별로 세려면 `MatchStats.recordRevive`에 플레이어 인자를 추가한다(기존 합계 `revives`는 그대로 유지).

## 4단계: 기억 저장·요약 (`src/server/NpcMemory/MemoryStore.luau`, `NpcClient.luau`)
- DataStore 이름은 `NpcMemory_v1`, 키는 파티 userId를 오름차순으로 `_` 결합한 값(`party_<id1>_<id2>`)이다.
- 저장 값: `{ events = 최근 10개 경기 기록 요약, bram_memory, mira_memory, bram_lines, mira_lines, updated_at }`. 오래된 것부터 버린다.
- 경기 종료 시:
  1. 이번 경기 기록을 `events`에 추가한다.
  2. `NpcClient.summarize`로 Muse Spark를 1회 호출한다. 입력은 이전 기억 + 최근 events이고, userId와 이름은 넣지 않는다. 모델·Secret·타임아웃은 Config 기존 키를 재사용하고, 응답 형식은 `NpcMemorySchema`(strict)다.
  3. 검증: 줄 수는 각 3개, 각 줄 1~80자, `P` 토큰은 이번 파티 인원 안에서만 허용한다(`P3`인데 2인이면 거부). 실패하면 이전 기억과 대사를 유지한다.
  4. `UpdateAsync`로 저장한다(pcall, 실패 시 warn만 하고 경기 흐름은 막지 않음).
- Output에 `[Npc] summarize source=muse|fallback party_size=N`, `[Npc] saved events=N` 로그를 남긴다(대사 원문은 로그에 남기지 않는다).

## 5단계: NPC 등장과 대사 (`src/server/NpcMemory/NpcService.server.luau`, `src/client/NpcBubble.client.luau`)
- 등불 근처에 NPC 2명을 만든다(그레이박스 파트 + 이름표: "Bram · 노장 대장", "Mira · 견습 치유사"). 전투에는 참여하지 않는다.
- 대사 시점: 웨이브 1 시작 직전(인사), 웨이브 1 종료 후 대기, 웨이브 3 종료 후 대기. 저장된 `*_lines[1..3]`을 순서대로 쓴다.
- 표시 전에 각 줄을 필터한다(`FilterStringAsync` → `GetNonChatStringForBroadcastAsync`). 그다음 `P1` 등을 DisplayName으로 바꾼다. 필터 실패, 기억 없음(첫 판), 해당 플레이어가 없음 중 하나라도 해당하면 Config 새 키 `NpcDefaultLines`의 기본 대사를 쓴다.
- 말풍선은 NPC 머리 위 BillboardGui로 6초간 표시한다. AI 대사일 때만 아래에 작은 글씨로 "AI가 생성한 대사입니다"를 붙인다.
- 경기 시작 시 기억을 불러오지 못해도(DataStore 실패) 경기는 그대로 시작한다.

## 6단계: 테스트 수단
- `src/server/NpcMemory/NpcMemory.spec.luau`: PASS/FAIL 출력, 모델·DataStore 없이 실행된다.
  - 파티 키 정렬
  - events 10개 상한
  - 검증기: 정상 통과 / 줄 수 틀림 거부 / 80자 초과 거부 / 없는 P 토큰 거부
  - 필터 실패 시 기본 대사
  - 이름 치환이 필터 뒤에 일어남
- 디버그 함수 `NpcService.debugEndMatch()`: 명령줄에서 호출하면 가짜 경기 기록(웨이브 3 북문 돌파, cleric 부활 2회, 패배)으로 경기 종료 처리를 한 번 실행한다. 7웨이브를 다 돌지 않고도 기억 저장 → 다음 판 대사를 확인하기 위한 것이다.
- `tools/test_npc.py`: test_director.py와 같은 방식으로 `fixtures/npc_memory/*.json`(새로 3개: 첫 판 패배 / 두 판째 승리 / cleric이 많이 살린 판)을 넣어 스키마 검증 결과와 대사를 출력한다. 실행은 사람이 한다(`MODEL_API_KEY` 필요).

## 7단계: 마무리
- `docs/devlog/2026-10-31.md`에 한 일, 추가한 Config 키, 사람이 확인할 체크리스트, 다음 할 일을 기록한 뒤 커밋한다.
- 커밋 후 `git push`(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 사람이 Studio에서 확인할 것 (devlog에 체크리스트로 복사)
- [ ] Studio: 게임 설정 → Security → **Enable Studio Access to API Services** 켜기(DataStore 사용에 필요)
- [ ] 명령줄에서 `NpcMemory.spec` 실행 → 모두 PASS
- [ ] 첫 판: Bram·Mira가 등불 근처에 있고 기본 대사로 인사함(AI 고지 없음)
- [ ] 명령줄 `debugEndMatch()` → Output에 `[Npc] summarize source=...`, `[Npc] saved events=1`
- [ ] 실제 서버(게시 후)에서 한 판을 끝낸 뒤 다시 들어가면, Bram이 지난 판의 성문이나 웨이브를, Mira가 플레이어 이름과 지난 판 행동을 언급하고, "AI가 생성한 대사입니다"가 표시됨
- [ ] `python tools/test_npc.py fixtures/npc_memory/*.json` → 3개 모두 OK
