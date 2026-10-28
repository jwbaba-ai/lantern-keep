# Day 6 작업 지시 (2026-11-01) — "판이 끝나면 바로 다음 판, 그리고 그림이 들어간다"

먼저 AGENTS.md, docs/GAME_DESIGN.md, 가장 최근 `docs/devlog/` 파일(day5 결과와 Claude Code 리뷰)을 읽는다.
오늘 목표는 두 가지다.
1. **같은 서버에서 한 판이 끝나면 결과 화면을 보여 준 뒤 다음 판이 시작되고, 다음 판에서 NPC가 방금 판을 언급한다.** 데모 영상의 핵심 장면이다.
2. **Muse Image로 이벤트 배너와 NPC 초상화를 만들어 화면에 넣는다.** "Best Creative Build" 보너스 상의 근거가 된다.

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다.
- `schemas/`, `src/shared/WaveSchema.luau`, `src/shared/NpcMemorySchema.luau`, 두 `prompt.txt`는 고치지 않는다.
- `src/shared/Config.luau`는 **새 키 추가만** 허용한다. 추가한 키는 devlog에 적는다.
- 환경 설정·패키지 설치 명령은 금지한다. 30초 넘게 멈추는 명령은 중단하고 보고한다.
- 기존 규칙(AI 글자는 필터 후 표시, 모델 호출은 웨이브 사이·경기 후만, 개인 데이터 금지)은 그대로 지킨다.
- **저장소는 공개된다.** 생성한 이미지에 실제 인물, 상표, 기존 게임 캐릭터를 닮게 그리지 않는다.

## 0단계: day5 확인 결과 반영
- day5 devlog의 체크리스트에 사람이 남긴 메모가 있으면 먼저 고치고 커밋한다.
- **Claude Code 리뷰 수정** (위에서부터 순서대로, 항목마다 커밋)
  1. **[중간] 서버 종료 시 기억 저장이 끊김**: 경기 종료 처리(요약 + 저장)가 진행 중이면 `game:BindToClose`에서 끝날 때까지 기다린다(최대 25초). 진행 중 여부는 플래그로 관리한다.
  2. **[낮음] 파티 기준 통일**: 파티 키, `partySize`, P 슬롯을 모두 **로비 종료 시점 명단**(`startIds`) 하나로 정한다. 중간에 들어온 플레이어는 그 판 기록에 넣지 않는다. 종료 시점의 `Players:GetPlayers()`는 쓰지 않는다. NpcMemory.spec에 "중간 입장자는 슬롯이 없고, 키는 시작 명단 기준" 1건을 추가한다.
  3. **[낮음] 불러오기 로그**: 판 시작 시 `[Npc] loaded events=N lines=ai|default`를 찍는다(대사 원문은 찍지 않는다).
  4. **[낮음] 첫 판 previous 형식**: 기억이 없을 때 `previous`는 `[]`가 아니라 `{ bram_memory = "", mira_memory = "" }`로 보낸다.

## 1단계: 연속 경기 (`src/server/Director/DirectorService.server.luau`)
- 경기 한 판을 `runMatch()` 함수로 묶고, 서버가 살아 있는 동안 반복한다.
- 한 판이 끝나면 다음 순서로 진행한다.
  1. `DirectorState`에 `phase="result"`를 알린다. 결과(승리/패배), 버틴 웨이브 수, 남은 등불 체력을 함께 보낸다.
  2. 경기 종료 처리(NPC 기억 요약·저장)를 **끝까지 기다린다.**
  3. 결과 화면을 `MatchRestartSeconds`초(Config 새 키, 시작값 15) 보여 준다. 기억 처리가 이보다 오래 걸리면 그만큼 더 기다린다.
  4. 다음 판을 시작하기 전에 초기화한다: 등불 체력 100, 남은 적 제거, 이벤트 효과 복원(`EventEffects.clear`), 성문 강조 끄기, 새 `MatchStats`·`MatchRecord`.
  5. 로비 대기부터 다시 시작한다. 플레이어의 직업은 유지하고, 다시 고르지 않는다.
- 판 번호를 `ReplicatedStorage`의 어트리뷰트 `MatchNumber`로 1부터 올린다.
- `NpcService`는 `MatchNumber`가 바뀔 때마다 기억을 다시 불러와 대사를 준비한다. 그래서 방금 저장한 대사가 다음 판 인사로 나온다.
- 플레이어가 0명이면(자동 테스트) 한 판만 돌고 멈춘다. 지금과 같은 동작이다.

## 2단계: 결과 화면 (`src/client/WaveBanner.client.luau` 또는 새 `ResultScreen.client.luau`)
- `phase="result"`일 때 화면 가운데에 크게 표시한다.
  - 첫 줄: `승리!` 또는 `등불이 꺼졌다…`
  - 둘째 줄: `7웨이브 중 N웨이브 생존 · 등불 체력 M%`
  - 셋째 줄: `Bram과 Mira가 이번 판을 기억합니다` (고정 문구)
  - 다음 판까지 카운트다운
- `phase="lobby"`가 되면 결과 화면이 사라진다.

## 3단계: Muse Image로 이미지 생성 (`assets/images/`)
Muse Code의 Muse Image 기능으로 아래 이미지를 PNG로 만들어 `assets/images/`에 저장한다. 실제 크기는 생성 결과에 맞추되, 가로·세로 1024 이하로 한다.

| 파일 | 내용 | 크기(권장) |
|---|---|---|
| `portrait_bram.png` | Bram: 희끗한 수염의 노장 대장, 낡은 판금 갑옷, 등불 빛을 받은 얼굴, 상반신 | 512×512 |
| `portrait_mira.png` | Mira: 젊은 견습 치유사, 연두색 망토, 손에 작은 빛, 밝은 표정, 상반신 | 512×512 |
| `banner_director.png` | AI 디렉터 표식: 성채 지도 위 4개 성문을 비추는 신비한 눈/등불 문양 | 1024×256 |
| `banner_fog.png` | 안개가 성벽을 덮는 밤 | 1024×256 |
| `banner_elite.png` | 거대한 정예 적의 실루엣이 성문 앞에 선 장면 | 1024×256 |
| `banner_reinforcement.png` | 멀리서 줄지어 오는 적 행렬, 아직 먼 거리 | 1024×256 |
| `banner_blood_moon.png` | 붉은 달 아래 성채 | 1024×256 |
| `thumbnail.png` | 게임 대표 이미지: 등불 성채를 지키는 4명의 영웅 실루엣과 NPC 둘 | 1024×1024 |

- 모든 그림은 같은 화풍으로 통일한다: 따뜻한 등불 빛과 어두운 판타지 성채, 그림책 같은 페인팅 스타일, 글자 없음.
- 사용한 프롬프트 전문과 생성 날짜는 `assets/images/PROMPTS.md`에 이미지마다 기록한다(재현과 심사용).
- `docs/ORIGINS.md` 표에 `assets/images/*.png | 신규 | Muse Image로 해커톤 기간 생성 | 2026-11-01` 형식으로 기록한다.
- 생성 횟수가 이미지당 3번을 넘으면 멈추고 보고한다(크레딧 보호).

## 4단계: 에셋 ID 연결 (`src/shared/AssetIds.luau` 새 파일 — 사람 승인 대기: 승인 표시가 없으면 4단계부터 멈추고 보고)
- 아래 키를 가진 테이블을 만들고, 모든 값은 `0`으로 둔다. 업로드는 사람이 크리에이터 허브에서 하고, 받은 ID를 직접 채운다.
  - `PortraitBram`, `PortraitMira`, `BannerDirector`, `BannerFog`, `BannerElite`, `BannerReinforcement`, `BannerBloodMoon`
- 값이 `0`이면 그 그림 없이 지금처럼 글자만 보여 준다. 오류나 빈 사각형이 보이면 안 된다.
- `docs/tasks/day6-upload.md`에 사람이 할 일을 짧게 적는다: 크리에이터 허브 업로드 → 이미지 ID 확인 → `AssetIds.luau`의 어느 키에 넣는지.

## 5단계: 화면에 그림 넣기
- **웨이브 배너**
  - `source="muse"`일 때 배지 옆에 `BannerDirector`를 작게 붙인다.
  - 이벤트가 있는 웨이브에는 배너 배경에 해당 이벤트 그림을 깐다. 글자는 읽히도록 반투명 어두운 판을 그 위에 둔다.
- **NPC 말풍선**: 말풍선 왼쪽에 초상화(`PortraitBram`, `PortraitMira`)를 둔다.
- **결과 화면**: Bram과 Mira 초상화를 나란히 보여 준다.

## 6단계: 테스트 수단
- `src/shared/AssetIds.spec.luau` 또는 서버 spec: 모든 키가 존재하고 숫자이며, 0이면 그림을 숨기는 함수가 `nil`을 돌려주는지 PASS/FAIL로 출력한다.
- 디버그 함수 `NpcDebug.debugFastMatch()`: 명령줄에서 호출하면 남은 웨이브를 건너뛰고 지금 판을 즉시 승리로 끝낸다. 결과 화면 → 기억 저장 → 다음 판 시작을 빠르게 확인하기 위한 것이다(실제 경기 흐름 코드는 그대로 쓰고, "남은 웨이브 건너뛰기" 플래그만 둔다).

## 7단계: 마무리
- `docs/devlog/2026-11-01.md`에 다음을 기록하고 커밋한다.
  - 한 일
  - 추가한 Config 키
  - 생성한 이미지 목록과 생성 횟수
  - 사람이 확인할 체크리스트
  - 다음 할 일
- 커밋 후 `git push`한다(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 사람이 할 일과 확인할 것 (devlog에 체크리스트로 복사)
- [ ] `assets/images/`의 그림 8장을 확인한다. 이상하면 다시 만들 그림을 devlog에 적는다.
- [ ] 크리에이터 허브에 7장(thumbnail 제외)을 업로드하고 ID를 `AssetIds.luau`에 넣는다(`docs/tasks/day6-upload.md` 참고). thumbnail은 체험 대표 이미지로 등록한다.
- [ ] Play → 명령줄 `debugFastMatch()` → 결과 화면, 카운트다운, 로비, 다음 판 시작, `MatchNumber=2`
- [ ] 2판째 시작 시 Output에 `[Npc] loaded events=1`
- [ ] 실제 서버(게시 후)에서 한 판을 끝내고 같은 서버에서 2판째를 시작하면 Bram·Mira가 방금 판을 언급하고, "AI가 생성한 대사입니다"와 초상화가 보인다.
- [ ] 이벤트 웨이브 배너에 그림이 깔리고 글자가 읽힌다. AI 디렉터 웨이브에 표식이 보인다.
