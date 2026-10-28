# Day 8 작업 지시 — "Day 단계: 짧게 시작해서 점점 길고 강하게"

먼저 AGENTS.md, docs/GAME_DESIGN.md, 가장 최근 `docs/devlog/` 파일(day7 결과)을 읽는다. **day7이 끝난 뒤에 시작한다.**

## 배경
사람(Babazz)이 실제 서버에서 두 판 연속을 해 보니 한 판(7웨이브)이 길었다. 그래서 한 판을 **Day**로 부르고, 웨이브 수를 단계적으로 늘린다(2026-10-29 사람 요청).

| Day | 웨이브 수 | 비고 |
|---|---|---|
| 1 | 3 | |
| 2 | 5 | |
| 3 | 7 | |
| 4 | 9 | |
| 5 | 10 | 마지막 웨이브에 보스 등장 |
| 6 이상 | 10 | 마지막 웨이브에 보스. Day마다 적 체력·수가 늘어난다 |

- 승리하면 다음 Day로 간다. 패배하면 **같은 Day에 다시 도전**한다.
- Day는 **서버 안에서만** 이어진다. 새 서버는 Day 1부터 시작한다(DataStore에 저장하지 않는다).

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다.
- 이번 작업에 한해 아래 파일 수정을 사람이 승인했다(2026-10-29). 적힌 범위 밖으로는 고치지 않는다.
  - `src/shared/Config.luau`: 아래 새 키 추가, `TotalWaves` 의미 변경
  - `src/shared/FallbackWaves.luau`: 웨이브 8~10 추가
  - `src/shared/EnemyCatalog.luau`: 보스 1종 추가
  - `src/server/Director/prompt.txt`, `src/server/NpcMemory/prompt.txt`: 아래 적은 문장만 수정
  - `schemas/npc_memory.schema.json`: `bram_lines`·`mira_lines`의 `description`만 수정한다. 그다음 `python tools/gen_schema_luau.py`로 다시 생성하고, `git diff --exit-code src/shared/WaveSchema.luau`로 WaveSchema가 그대로인지 확인한다.
- `schemas/wave_plan.schema.json`과 `src/shared/WaveSchema.luau`는 **고치지 않는다.** 보스는 디렉터가 고르지 않고, 서버가 검증 뒤에 붙인다.
- 환경 설정·패키지 설치 명령은 금지한다. 30초 넘게 멈추는 명령은 중단하고 보고한다.
- 기존 규칙은 그대로다: 디렉터 실패 시 대체 웨이브, AI 글자는 필터 후 표시, 모델 호출은 웨이브 사이만.

## 0단계: day7 확인 결과 반영
day7 devlog의 체크리스트에 사람이 남긴 메모가 있으면 먼저 고치고 커밋한다.

## 1단계: 설정과 규칙 모듈
- `Config.luau` 새 키:
  - `DayWaveCounts = { 3, 5, 7, 9, 10 }` — Day 6 이상은 마지막 값(10)을 쓴다.
  - `BossFromDay = 5` — 이 Day부터 마지막 웨이브에 보스가 나온다.
  - `DayScaleFromDay = 6`, `DayHealthStep = 0.15`, `DayCountStep = 0.10`, `DayHealthMax = 2.5`, `DayCountMax = 1.6`
  - `TotalWaves = 10`으로 바꾸고 주석을 "Day별 웨이브 수의 최댓값(= FallbackWaves 개수)"으로 고친다. 한 판의 웨이브 수로는 더 이상 쓰지 않는다.
- 새 모듈 `src/server/Director/DayRules.luau`:
  - `waveCount(day)` → `DayWaveCounts[day]`. 범위를 넘으면 마지막 값
  - `isBossWave(day, wave)` → `day >= BossFromDay and wave == waveCount(day)`
  - `scale(day)` → `{ health = h, count = c }`. Day 5까지는 1이다. 그 뒤로는 `h = min(DayHealthMax, 1 + DayHealthStep*(day-5))`, `c = min(DayCountMax, 1 + DayCountStep*(day-5))`이다.
  - `scalePlan(plan, day)` → 각 항목 `count`에 `c`를 곱해 올림한다. 총합이 `Config.MaxEnemies`를 넘으면 비율을 유지하며 줄인다. 원본은 고치지 않는다.
- `DayRules.spec.luau` (PASS/FAIL 출력):
  - `waveCount` 1~7 → 3,5,7,9,10,10,10
  - `isBossWave(5,10)`·`(6,10)` true / `(4,9)`·`(5,9)` false
  - `scale(5)` = 1/1, `scale(6)` = 1.15/1.10, `scale(30)`이 상한에 걸림
  - `scalePlan` 총합 ≤ MaxEnemies

## 2단계: 경기 흐름 (`DirectorService.server.luau`)
- 서버 변수 `currentDay`(시작 1)를 둔다. `ReplicatedStorage`의 어트리뷰트 `Day`로 알린다.
- `runMatch`의 웨이브 반복을 `Config.TotalWaves` 대신 `DayRules.waveCount(currentDay)`까지 돌린다. 마지막 웨이브 판정(`wave == ...`)도 같은 값을 쓴다.
- 웨이브에 적용하는 순서: 검증(`WaveValidator`) → `PartyScale.scalePlan` → `DayRules.scalePlan` → (보스 웨이브면) 보스 추가. 대기 중 미리보기(`previewPlan`)와 성문 강조도 같은 순서로 만든다.
- 적 체력에 `DayRules.scale(day).health`를 곱한다. `EnemyFactory.spawn`의 기존 배율 계산(파티·이벤트)에 이 배율을 하나 더 넣는다. 인자로 넘기고, 전역 상태로 두지 않는다.
- 결과 뒤: 승리면 `currentDay += 1`, 패배면 그대로 둔다. 로그 `[Director] day=N waves=W result=...`를 남긴다.
- 대체 웨이브는 웨이브 번호로 고른다(`FallbackWaves[wave]`). 웨이브 1은 지금처럼 항상 대체 웨이브다.
- `FallbackWaves.luau`에 웨이브 8~10을 추가한다. 7보다 조금씩 강하게 만들고, `blood_moon`은 넣지 않는다. 총합은 `MaxEnemies` 이하로 한다.

## 3단계: 보스
- `EnemyCatalog.luau`에 `Warlord`를 추가한다: 체력 Brute의 8배, `Speed = 5`, `LanternDamage = 40`, 크기는 Brute의 약 2배, 이름표는 `보스 · 그림자 군주`이다.
- `Config.EnemyTypes`와 웨이브 스키마에는 **넣지 않는다.** 그래서 디렉터는 고를 수 없고, 디렉터 출력에 있으면 지금처럼 검증에서 거부된다.
- 보스 웨이브에서는 서버가 계획에 `{ type = "Warlord", count = 1, lane = 적이 가장 많은 성문 }`을 붙인다. 이 적은 웨이브 시작 10초 뒤에 나온다. 파티 체력 배율과 Day 체력 배율을 모두 받는다.
- 배너 셋째 줄 앞에 `[보스] 그림자 군주 · 북문`을 붙인다(고정 문구). 보스 체력이 남아 있으면 웨이브가 끝나지 않는다(기존 `arrived + killed < spawned` 규칙 그대로).
- 자동 테스트(플레이어 0명)의 체력 비례 처치도 보스에 그대로 적용된다. 이 경우 보스가 등불에 닿을 수 있다는 점을 devlog에 적는다.

## 4단계: 화면
- `DirectorState`에 `day`, `total_waves`, `boss`(true/false) 필드를 더한다.
- 배너 첫 줄: `Day 2 · 웨이브 3 / 5 · <웨이브 이름>`. 로비: `Day 2 · 곧 시작합니다`
- 결과 화면:
  - 승리: `Day 2 승리!` / `5웨이브 모두 막아냄 · 등불 체력 M%` / `다음은 Day 3 (웨이브 7)`
  - 패배: `등불이 꺼졌다…` / `5웨이브 중 N웨이브 생존` / `Day 2에 다시 도전합니다`
- `WaveBanner`의 `TOTAL_WAVES` 상수를 없애고 `total_waves`를 쓴다. `DirectorState.luau`의 `Config.TotalWaves` 사용도 `total_waves`로 바꾼다.
- `DirectorState.spec`에서 "7웨이브 중" 등 웨이브 수를 고정한 검사는 새 필드에 맞춰 고친다. 그리고 "Day 1 결과 → `3웨이브 중`" 1건을 추가한다.

## 5단계: 디렉터·NPC 입력
- `MatchStats.buildSummary` 요약에 `day`, `total_waves`, `waves_left`를 더한다.
- `src/server/Director/prompt.txt`의 "A match has 7 waves." 문장을 다음으로 바꾼다.
  "A match is one Day. Day 1 has 3 waves, Day 2 has 5, Day 3 has 7, Day 4 has 9, and Day 5 and later have 10. The summary tells you day, wave, total_waves and waves_left. Ramp up toward the last wave. The game itself adds a boss to the last wave from Day 5 on, so never add a boss yourself."
- 경기 기록(`MatchRecord`)의 결과에 `day`와 `total_waves`를 더한다.
- `src/server/NpcMemory/prompt.txt`:
  - "for 7 waves"를 "for one Day (3 to 10 waves)"로 바꾼다.
  - 대사 시점 문장 2곳(`after wave 3`)을 "before the final wave"로 바꾼다.
  - "Mention the Day number when it helps (e.g. Day 2)."를 한 줄 더한다.
- `npc_memory.schema.json` 대사 `description`의 "after wave 3"을 "before the final wave"로 바꾸고 Luau를 다시 생성한다.
- `NpcService`의 셋째 대사 시점: `display_wave == 4` 대신 `display_wave == total_waves`(마지막 웨이브 직전 대기)로 바꾼다. Day 1(3웨이브)이면 웨이브 2 뒤에 나온다.
- `tools/test_director.py`·`tools/test_npc.py`의 fixture에 `day`·`total_waves`가 없으면 기본값(1, 3)으로 채워 그대로 돌게 한다.

## 6단계: 테스트 수단
- `NpcDebug.debugSetDay(n)`: 명령줄에서 호출하면 **다음 판**의 Day를 n으로 정한다. `debugFastMatch()`와 함께 쓰면 Day 5 보스를 빨리 볼 수 있다.

## 7단계: 마무리
- `docs/GAME_DESIGN.md`의 "7웨이브" 설명을 Day 표로 바꾼다. AGENTS.md 게임 정보의 "7웨이브 동안 지킨다"는 사람 승인 대상이므로 고치지 않고, 바꿀 문장만 devlog에 제안한다.
- devlog에 한 일, 추가·변경한 Config 키, 사람이 확인할 체크리스트를 기록한 뒤 커밋한다.
- 커밋 후 `git push`(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 사람이 확인할 것 (devlog에 체크리스트로 복사)
- [ ] 명령줄 `DayRules.spec`, `DirectorState.spec`, `WaveValidator.spec`, `NpcMemory.spec` 모두 PASS
- [ ] Play: 배너가 `Day 1 · 웨이브 1 / 3`, 3웨이브 뒤 결과 화면 `Day 1 승리!` → 다음 판 `Day 2 · 웨이브 1 / 5`
- [ ] 패배하면 같은 Day로 다시 시작
- [ ] `debugSetDay(5)` + `debugFastMatch()` → Day 5 웨이브 10에 `[보스] 그림자 군주`가 나오고, 보스를 잡기 전에는 웨이브가 끝나지 않음
- [ ] Day 6에서 적 체력·수가 Day 5보다 많음(Output `scaled_enemies`로 확인)
- [ ] Day 1에서 Bram·Mira 셋째 대사가 웨이브 2 뒤에 나옴
- [ ] 실제 서버에서 Day 1 → Day 2 두 판을 연속으로 해 보고, NPC가 지난 판(Day 1)을 언급함
