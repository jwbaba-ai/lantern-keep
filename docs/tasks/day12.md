# Day 12 작업 지시 — 휴대폰 실제 서버에서 본 글자 문제 정리

먼저 AGENTS.md와 `docs/devlog/2026-11-05.md` 끝부분(day11e까지)을 읽는다. 사람(Babazz)이 day11e 빌드를 publish해서 휴대폰 가로 화면으로 플레이했다(2026-10-30).
- 사람 확인 1: NPC 대사가 보이지 않는다(글자 색 때문인 것 같다).
- 사람 확인 2: 성문 이름 글자가 성문 위 구조물 안으로 들어가서 보이지 않는다.
- 사람 스크린샷: 여러 이름표(Mira·지원대·Support2·Grunt)가 한곳에 겹쳐 모두 읽기 어렵다.

새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/client/NpcBubble.client.luau`, `src/server/World/MapBuilder.server.luau`(성문 글자 부분만), `src/server/NpcMemory/NpcService.server.luau`(이름표 부분만), `src/server/Support/SupportSquad.luau`(이름표 부분만), `src/server/Enemies/EnemyFactory.luau`(이름표 부분만), 새 모듈 `src/server/World/Labels.luau`, devlog, `docs/GAME_DESIGN.md`.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- AI 글자 규칙은 그대로다: 필터를 거친 글자만 보이고, AI 대사에는 "AI가 생성한 대사입니다"를 붙인다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.

## 1. [높음] NPC 대사가 보이지 않음 — `NpcBubble.client.luau`
- 지금 동작:
  - AI 대사(`isAI=true`)는 화면 아래 고정 대화창에 나온다.
  - 기본 대사(`isAI=false`)는 NPC 머리 위 BillboardGui 말풍선(260×70, 글자 44)에 나온다.
- 문제: Day 1 첫 판은 기억이 없어서 **모든 대사가 기본 대사**다. 머리 위 말풍선은 카메라가 NPC를 보지 않으면 화면 밖이다. 가까우면 다른 이름표와 겹치고, 멀면 작아진다. 그래서 휴대폰에서 대사를 못 봤다.
- 고칠 것: **기본 대사도 아래 고정 대화창에** 보여 준다.
  - 같은 행 모양(초상화 + 이름 + 대사)을 쓴다. "AI가 생성한 대사입니다" 줄은 `isAI=true`일 때만 붙인다.
  - 표시 시간 9초, Bram 위·Mira 아래로 쌓는 규칙, 3줄에서 자르는 규칙은 지금 AI 대화창과 같다.
  - 머리 위에는 지금 AI 대사처럼 작은 "…" 표시만 9초 동안 둔다. 머리 위 큰 말풍선(`showBubble`)은 쓰지 않는다.
- 대화창 글자 대비를 확인한다. 배경은 어두운 남색(불투명도 0.15 이하 투명), 이름은 NPC 색(Bram 밝은 회청, Mira 밝은 초록), 대사는 흰색이다. 글자에는 `TextStrokeTransparency = 0.5`를 준다.

## 2. [높음] 성문 이름이 성문 위 가로대 안으로 들어감 — `MapBuilder.addGateLabel`
- 원인: 성문 중심 y=6 + `StudsOffsetWorldSpace` 9 = **y 15**인데, day11의 문틀 가로대(`GateLintel_*`)가 바로 y 15(높이 2)에 있다. 게다가 `AlwaysOnTop=false`라 가로대·탑에 가린다.
- 고칠 것:
  - 글자 높이를 **y 30**(성문 중심에서 +24)으로 올린다. 탑 꼭대기(톱니 y 25)보다 위다.
  - `AlwaysOnTop = true`로 한다. 성문 방향 안내라 벽 너머로 보여도 된다. `MaxDistance` 250은 그대로 둔다.
  - 글자 크기는 지금 `UDim2.fromScale(10, 3)`(스터드 단위) 그대로 둔다.

## 3. [높음] 이름표가 겹쳐 읽을 수 없음 — NPC·지원대·적 이름표
- 사람 스크린샷: Mira 이름표, "지원대 · 각개전투파 · 궁수", "Support2", "Grunt"가 한곳에 겹친다. 흰 글자에 배경이 없어 밝은 바닥·벽 위에서 안 보인다.
- 공통 모양을 새 모듈 `src/server/World/Labels.luau`의 함수 하나로 만든다. NPC·지원대·적 이름표가 같은 함수를 쓴다.
  - 크기는 픽셀 기준 `UDim2.new(0, 140, 0, 24)`다(배경 포함).
  - 배경은 검정, 투명도 0.45, 모서리는 둥글게(UICorner 6)다.
  - 글자는 흰색 GothamBold에 외곽선(`TextStrokeTransparency = 0.3`)을 주고, `TextScaled`와 `UITextSizeConstraint` 최대 18을 쓴다.
  - `MaxDistance`: NPC 60, 지원대 50, 적 70.
  - `AlwaysOnTop = false`다. 벽 뒤 이름표가 앞으로 겹쳐 나오지 않게 하기 위해서다. 단, **보스 이름표는 `AlwaysOnTop = true`를 유지**한다.
- 글자를 짧게 줄인다.
  - NPC는 `Bram · 노장 대장`, `Mira · 견습 치유사`를 그대로 둔다.
  - 지원대는 `지원대 · 궁수`처럼 역할만 남기고 파(각개전투파·협력파)는 뺀다. 파는 이미 투표 결과로 보인다.
  - 적은 한국어 이름을 쓴다: Grunt `졸개`, Runner `질주병`, Brute `거한`, Archer `궁병`, Shaman `주술사`. 이 표는 `EnemyFactory` 안 지역 표로 둔다(`EnemyCatalog`는 고치지 않는다). `DisplayName`이 있는 보스는 그대로 쓴다. 이벤트 접두어(`namePrefix`)도 그대로 붙인다.
- 지원대 봇 머리 위 "Support2" 같은 기본 Humanoid 이름은 숨긴다: `Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None`.
- 이름표 높이는 몸체 위 +3~4 그대로 둔다.

## 마무리
- `docs/GAME_DESIGN.md`에 "모든 NPC 대사는 아래 대화창", 이름표 모양, 적 한국어 이름을 짧게 적는다.
- devlog에 "day12" 절로 한 일과 바뀐 값을 적고 커밋한 뒤 `git push`(원격: origin/main)한다. push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS, 오류·경고 없음
- [ ] Day 1 판 시작 기본 대사가 아래 대화창에 Bram·Mira 두 줄로 나오고 "AI가 생성한 대사입니다"는 없음. 가짜 isAI=true면 고지 줄이 붙음. 머리 위에는 "…"만
- [ ] 성문 글자 4개의 높이가 y 30, 가로대·탑에 가리지 않음(성채 안에서 성문 쪽을 본 사진)
- [ ] 이름표: 크기 140×24, 배경·외곽선, MaxDistance 값, 적 이름 한국어, 지원대 "지원대 · 역할", "Support2" 같은 기본 이름 없음
- [ ] 등불 앞 기본 카메라에서 이름표끼리 겹치는 정도가 사람 스크린샷보다 줄었는지 사진으로 비교
- [ ] 스크린샷 3장(대화창, 성문 쪽, 등불 앞 기본 카메라)을 `docs/devlog/shots/day12/`에

사람이 실제 서버에서 확인한다.
- [ ] 휴대폰에서 판 시작 대사가 읽힘, 성문 이름이 보임, 이름표가 읽힘
