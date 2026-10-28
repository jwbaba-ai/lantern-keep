# Day 4 작업 지시 (2026-10-30) — "AI 디렉터가 짠 웨이브가 화면과 세계에 보인다"

먼저 AGENTS.md, docs/GAME_DESIGN.md, 가장 최근 `docs/devlog/` 파일(day3 결과)을 읽는다.
오늘 목표는 **플레이어가 화면만 보고도 "이번 웨이브는 AI가 우리를 보고 짰다"를 알아채는 것**이다. 데모 영상의 핵심 장면이 된다.

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다.
- `schemas/`, `src/shared/WaveSchema.luau`, `src/server/Director/prompt.txt`는 고치지 않는다.
- `src/shared/Config.luau`는 **이번 작업에 필요한 새 키 추가만** 허용한다(기존 값 변경 금지). 추가한 키는 devlog에 적는다.
- 환경 설정·패키지 설치 명령 금지. 30초 넘게 멈추는 명령은 중단하고 보고한다.
- 클라이언트 코드는 `src/client/`(day3에서 만든 매핑)에 둔다. 매핑이 없으면 day3 규칙대로 추가한다.
- **AI가 만든 글자(`wave_name`, `director_note`)는 서버에서 필터를 거친 뒤에만 클라이언트로 보낸다.** 클라이언트는 원문을 받지 않는다.
- 디렉터 호출 시점·횟수는 바꾸지 않는다(웨이브 사이 1회).

## 0단계: 어제 Studio 확인 결과 반영
day3 devlog의 체크리스트에 사람이 남긴 메모가 있으면 먼저 그 문제부터 고치고 커밋한다. 메모가 없으면 넘어간다.

## 1단계: 화면에 보낼 웨이브 정보 (`src/server/Director/`)
- `ReplicatedStorage.DirectorState`(StringValue, JSON)에 아래 필드를 담는다. 기존 `wave`, `source`, `plan` 필드는 유지하되, **클라이언트용 글자는 새 필드만 쓴다.**
  - `phase`: `"wave"`(전투 중) 또는 `"intermission"`(대기)
  - `display_wave`: 화면에 보여 줄 웨이브 번호 (대기 중에는 다음 웨이브 번호)
  - `display_name`, `display_note`: 필터를 거친 `wave_name`, `director_note`
  - `lanes`: 성문별 적 수 `{ north = 6, east = 4, south = 0, west = 0 }` (plan.enemies 합계)
  - `intermission_ends_at`: 대기 종료 시각(`workspace:GetServerTimeNow()` 기준), 전투 중에는 0
- 필터: `TextService:FilterStringAsync(text, 아무 플레이어 UserId)` → `GetNonChatStringForBroadcastAsync()`. 플레이어가 없거나 필터가 실패하면 **같은 웨이브 번호의 `FallbackWaves` 글자**로 바꾼다.
- 상태 갱신 시점
  1. 웨이브 시작: `phase="wave"`
  2. 대기 시작 직후(디렉터 응답 전): `phase="intermission"`, 다음 웨이브 정보는 "디렉터가 다음 웨이브를 설계하는 중…"(고정 문구, 필터 불필요)
  3. 디렉터 응답 또는 대체 웨이브가 정해지면: `phase="intermission"` 그대로, 다음 웨이브 정보로 갱신
- Output에 `[Director] state phase=... wave=... source=...` 한 줄씩 남긴다.

## 2단계: 웨이브 배너 UI (`src/client/WaveBanner.client.luau`)
- 화면 위 가운데 배너. `DirectorState.Changed`를 듣는다.
- 표시 내용
  - 첫 줄: `웨이브 3 / 7 · {display_name}`
  - 출처 배지
    - `source="muse"` → **"AI 디렉터가 여러분의 플레이를 보고 설계한 웨이브"** (강조색)
    - `source="fallback"` → "기본 웨이브" (회색)
  - 둘째 줄: `display_note`
  - 셋째 줄: 공격 성문 요약, 적 수가 많은 순. 예: `북문 6 · 동문 4` (0인 성문은 숨김)
  - 대기 중이면 남은 초 카운트다운 (`intermission_ends_at` 기준)
  - 배너 아래 작은 글씨 **"AI가 생성한 문구입니다"** (`source="muse"`일 때만)
- 전술 이름은 한글로 바꿔 보여 준다: focus_weak_lane=약한 성문 집중, split_push=전 성문 동시 공격, flank=측면 우회, siege=공성
- 대기 시작과 디렉터 응답 도착 때 배너가 0.3초 정도 커졌다 돌아오는 간단한 트윈 효과를 넣는다.

## 3단계: 세계에서도 보이게 — 공격 성문 강조 (`src/server/World/` 또는 Director)
- 다음 웨이브가 정해지면 대기 시간 동안, 적이 오는 성문의 파트를 그 성문 색으로 깜빡이게 한다(적 수가 많을수록 빠르게). 웨이브가 시작되면 원래 색으로 되돌린다.
- 맵 파트 이름·구조는 `MapBuilder`가 만든 것을 그대로 쓴다.

## 4단계: 이벤트 효과 (`src/server/Director/EventEffects.luau`)
GAME_DESIGN.md의 "이벤트 효과" 그대로 구현한다. 웨이브 시작 때 적용하고, 웨이브가 끝나면 원래 값으로 되돌린다.
- fog: `Lighting.FogEnd`를 줄인다 (Config 새 키 `FogEndDuringEvent`, 시작값 120)
- elite_spawn: 그 웨이브의 첫 적 1마리 크기·체력 2배, 이름 표시에 "정예"
- reinforcement_delay: 적 스폰 간격 2배
- blood_moon: 모든 적 체력 1.5배 + 붉은 조명 (6웨이브 이상만, 검증기가 이미 막고 있음)
- 이벤트가 `none`이 아니면 배너 둘째 줄 앞에 이벤트 이름을 한글로 붙인다: 안개 / 정예 출현 / 증원 지연 / 핏빛 달

## 5단계: 등불 체력 표시 (`src/client/`)
- 화면 위 오른쪽에 등불 체력 막대(`Map.Lantern`의 `Health` 어트리뷰트). 30% 이하면 붉게 깜빡인다.

## 6단계: 자동 확인 스크립트
- `src/server/Director/DirectorState.spec.luau`: 필드 구성 검사 함수를 만들어, 가짜 plan 2개(muse 1, fallback 1)로 상태 JSON을 만들고 아래를 PASS/FAIL로 출력한다.
  - 필수 필드 `phase`, `display_wave`, `display_name`, `display_note`, `lanes`, `intermission_ends_at`가 모두 있음
  - `lanes` 합계 = plan.enemies의 count 합계
  - 필터를 쓸 수 없을 때(플레이어 없음) `display_name`이 FallbackWaves 글자와 같음
- Studio 명령줄에서 `require(game.ServerScriptService.Server.Director["DirectorState.spec"])` 한 줄로 실행 가능해야 한다(WaveValidator.spec과 같은 방식).

## 7단계: 마무리
- `docs/devlog/2026-10-30.md`에 한 일, 추가한 Config 키, 사람이 확인할 체크리스트, 다음 할 일 기록 후 커밋
- 커밋 후 `git push` (원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다

## 사람이 Studio에서 확인할 것 (devlog에 체크리스트로 복사)
- [ ] Play → 웨이브 1 배너에 "기본 웨이브", 대기 중 "디렉터가 다음 웨이브를 설계하는 중…" → 카운트다운
- [ ] 실제 서버(게시 후)에서 웨이브 2부터 "AI 디렉터가 … 설계한 웨이브" 배지, 디렉터 한마디, "AI가 생성한 문구입니다" 표시
- [ ] 배너의 공격 성문 요약과 실제로 적이 나오는 성문이 같고, 대기 중 그 성문이 깜빡임
- [ ] 이벤트 웨이브에서 안개/정예/증원 지연/핏빛 달 효과가 보이고, 다음 웨이브에서 원래대로 돌아옴
- [ ] 등불 체력 막대가 줄어들고 30% 이하에서 붉게 깜빡임
- [ ] 명령줄에서 `DirectorState.spec` 실행 → 모두 PASS
