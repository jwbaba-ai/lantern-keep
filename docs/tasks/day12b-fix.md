# Day 12b 작업 지시 — day12 Studio 확인에서 나온 수정 (짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day12)" 표와 사진 `docs/devlog/shots/day12/01_dialog_start_default_lines.jpg`, `03_default_camera_lantern.jpg`를 본다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/client/NpcBubble.client.luau`, `src/server/World/MapBuilder.server.luau`(아래 두 곳만), `src/server/NpcMemory/NpcService.server.luau`(이름표 offset만), `src/server/Enemies/EnemyFactory.luau`(이름표 부분만), devlog, `docs/GAME_DESIGN.md`.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. 커밋은 로컬에 둔다. Claude Code가 리뷰 후 push한다.

## 1. [높음] 판 시작 대사를 지원대 투표 결과 창이 덮음 — `NpcBubble.client.luau`
- Studio 확인: 판 시작에 대화창(9초)과 투표 결과 창(`SupportVote.client.luau`, 6초)이 같이 뜨고, 결과 창이 대사 오른쪽 절반을 어둡게 덮는다.
- 고칠 것: 결과 창이 떠 있는 동안에는 **대사를 잠시 미룬다.** `SupportVote.client.luau`는 고치지 않는다.
  - `npcSay.OnClientEvent`에서 `ReplicatedStorage.SupportState`(JSON)를 `pcall`로 읽어 `announce`, `announce_until`을 본다.
  - `announce`가 비어 있지 않고 `announce_until`이 `Workspace:GetServerTimeNow()`보다 뒤면, 남은 시간 + 0.5초 뒤에 `showDialog`와 `showDot`을 부른다. 아니면 지금처럼 바로 부른다.
  - 읽기 실패, 값 없음, 숫자 아님은 모두 바로 표시한다. 어떤 경우에도 대사를 버리지 않는다.
  - 미룬 뒤의 9초 표시, Bram 위·Mira 아래, 고지 줄 규칙은 그대로다.

## 2. [높음] 이름표가 자기 머리에 가림 — `NpcService`, `EnemyFactory`
- Studio 측정: NPC 머리 꼭대기 y 6.60 > 이름표 중심 y 6.5. 졸개 머리 꼭대기 y 5.92, 이름표 중심 y 6.0.
- NPC: `Labels.attach`의 `offset`을 `Vector3.new(0, 4, 0)`에서 `Vector3.new(0, 5.5, 0)`으로 바꾼다.
- 적: 종류와 정예 크기마다 키가 다르므로 고정값을 쓰지 않는다.
  - `buildSilhouette(body, enemyType)` 다음에, 몸체와 자식 BasePart의 윗면(`Position.Y + Size.Y / 2`) 중 가장 높은 값을 구한다.
  - `StudsOffsetWorldSpace`의 Y를 `가장 높은 값 - body.Position.Y + 1.5`로 정한다. `Labels.attach`가 돌려주는 BillboardGui에 넣는다.
- 지원대 이름표는 Studio에서 가림이 나오지 않았으니 고치지 않는다.

## 3. [중간] 등불 기둥이 시작 화면을 가림 — `MapBuilder` 등불 생성부(80~88줄)
- 사진: 플레이어가 등불 바로 옆에서 태어나 기본 카메라 가운데를 불투명한 노란 기둥이 차지한다. 내 캐릭터와 뒤쪽 이름표가 안 보인다. 데모 영상의 첫 장면이기도 하다.
- 고칠 것: `Size`를 `Vector3.new(4, 20, 4)`에서 `Vector3.new(2, 20, 2)`로, `Transparency = 0.3`을 넣는다.
- `Position`, `Neon`, `PointLight`, `Health`, 이름은 그대로 둔다. 코드에서 `lantern.Size`를 쓰는 곳은 없다.
- `MapDecor.luau`의 "위치·크기·Neon" 주석에서 크기 설명이 맞지 않게 되지만 파일은 고치지 않고, devlog에 값이 바뀌었다고 적는다.

## 4. [중간] 성문 글자가 밤하늘에서 안 읽힘 — `MapBuilder.addGateLabel`
- Studio 측정: 북(파랑)·남(빨강)·서(초록)는 밤하늘과 대비가 낮고, 40스터드에서 폭 약 45픽셀이다.
- 고칠 것:
  - 크기를 `UDim2.fromScale(10, 3)`에서 `UDim2.fromScale(16, 5)`로 키운다.
  - 글자 색을 밝게: 북 (120,190,255), 남 (255,130,120), 동은 지금 값, 서 (130,230,130). 검정 외곽선은 그대로 둔다.

## 마무리
- `docs/GAME_DESIGN.md`에 등불 기둥 값과 "투표 결과 창이 떠 있으면 대사를 미룸"을 짧게 적는다.
- devlog에 "day12b" 절로 한 일과 바뀐 값을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS, 오류·경고 없음
- [ ] 지원대 투표 판(결과 창 있음): 결과 창과 대화창이 동시에 보이지 않고, 창이 닫힌 뒤 Bram·Mira 대사가 9초 보임
- [ ] "지원대 없이" 판과 SupportState를 읽지 못하는 경우: 대사가 빠지지 않음
- [ ] Wave 사이 AI 대사는 미룸 없이 바로 나옴
- [ ] NPC와 적 5종(정예 포함) 이름표 중심이 머리 꼭대기보다 위에 있고, 사진에서 안 가림
- [ ] 등불 기둥 2×20×2, 투명도 0.3. 기본 카메라에서 내 캐릭터가 보임. 등불 피해·패배·Fire 크기 그대로
- [ ] 성문 글자 값과 사진(AlwaysOnTop을 잠시 끄고 찍는 것은 day12와 같게)
- [ ] 웨이브 1~3 회귀: 멈춘 적 0, 시간 초과 없음
- [ ] 스크린샷을 `docs/devlog/shots/day12b/`에

사람이 실제 서버에서 확인한다(publish 후 휴대폰).
- [ ] 판 시작 대사가 읽힘, 성문 글자가 AlwaysOnTop으로 보이고 읽힘, 이름표 크기가 적당함
- [ ] Day 2 인사에 지난 판 언급, ranger 사거리, 끊김 없음
