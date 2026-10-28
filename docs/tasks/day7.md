# Day 7 작업 지시 (2026-11-02) — "데모 녹화 전 다듬기"

먼저 AGENTS.md, 가장 최근 `docs/devlog/` 파일(day6 결과와 Claude Code 리뷰)을 읽는다.
오늘 목표는 **새 기능 없이, 데모 화면에서 눈에 띄는 어색함만 없애는 것**이다. 작은 수정만 하고 구조는 바꾸지 않는다.

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다.
- `schemas/`, 생성 Luau 스키마 2개, 두 `prompt.txt`, `src/shared/Config.luau`, `src/shared/AssetIds.luau`는 고치지 않는다(AssetIds는 사람이 ID를 채우는 중).
- 환경 설정·패키지 설치 명령은 금지한다. 30초 넘게 멈추는 명령은 중단하고 보고한다.

## 0단계: day6 확인 결과 반영
day6 devlog의 체크리스트에 사람이 남긴 메모가 있으면 먼저 고치고 커밋한다.

## 1단계: Claude Code 리뷰·테스트 수정 (항목마다 커밋)
1. **[높음] 로비 배너에 "곧 시작합니다" 대신 웨이브 1 이름이 나옴** — `src/server/Director/DirectorState.luau`
   - 원인: 로비 고정 문구까지 `filterOrFallback`에 넣는다. 로비 시작 시점에는 플레이어가 0명이라 필터가 실패하고, 웨이브 1 대체 문구로 바뀐다.
   - 고칠 것: `phase == "lobby"`이면 결과 화면처럼 고정 문구를 필터 없이 그대로 쓴다. 고정 문구는 서버 코드에 적힌 글자이고 AI가 만든 글이 아니다.
   - 확인: `DirectorState.spec`에 "플레이어 0명 + lobby → display_name이 `곧 시작합니다`" 1건 추가.
2. **[낮음] 결과 화면 중에도 웨이브 배너가 보임** — `src/client/WaveBanner.client.luau`: `phase == "result"`이면 배너 전체를 숨긴다.
3. **[낮음] 이벤트 그림이 없어도 그 자리가 남음** — `WaveBanner`의 이벤트 그림(`EventArt`)은 이미지가 없으면 `Visible=false`로 두어 배너 높이가 늘어나지 않게 한다. 말풍선·결과 화면의 초상화도 같은 규칙을 따르는지 확인한다.
4. **[낮음] 다음 판 시작 시 플레이어 체력이 그대로 이어짐** — `DirectorService`의 `resetForNextMatch`에서 살아 있는 플레이어의 체력을 직업 최대 체력으로 채운다.

## 1-1단계: 휴대폰 화면 수정 (사람이 실제 서버에서 휴대폰으로 확인, 2026-10-29. 항목마다 커밋)
1. **[높음] 이벤트 배너 그림이 안내 글자를 가림** — `src/client/WaveBanner.client.luau`
   - 원인(추정): `Instance.new("ScreenGui")`의 `ZIndexBehavior` 기본값이 `Global`이다. 그래서 그림(`EventArt` 안의 `Art`·`Dim`)과 글자 라벨이 같은 ZIndex 1로 겹치고, 그리는 순서가 정해지지 않는다.
   - 고칠 것: `gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling`으로 둔다. 배너 전체를 컨테이너 `Frame` 하나로 묶는다. 그 안에 그림 레이어(ZIndex 1)와 글자 프레임(ZIndex 2)을 형제로 둔다. 그러면 크기 조정과 `pop` 트윈이 둘에 같이 걸리고, 그림이 항상 글자 뒤에 있다. `UIListLayout`은 글자 프레임 안에만 둔다. 디렉터 표식도 컨테이너 안 오른쪽 위에 둔다. 지금처럼 절대 좌표로 옮기지 않는다.
2. **[높음] 휴대폰에서 안내 글자가 너무 큼** — 배너·NPC 말풍선·결과 화면·등불 체력바
   - 새 공용 모듈 `src/client/UiScale.luau`: 화면 크기(`workspace.CurrentCamera.ViewportSize`)를 보고 배율을 돌려준다. 배율 = `math.clamp(짧은 변 / 720, 0.55, 1)`. 화면 크기가 바뀌면(회전) 다시 계산한다.
   - 각 화면의 최상위 프레임에 `UIScale`을 달고 이 배율을 쓴다. 배너는 트윈용 `UIScale`과 겹치지 않게 컨테이너 안쪽 프레임에 따로 둔다.
   - 배너 글자 줄 높이는 지금(30/22/24/22/20/16)의 약 80%로 줄이고, `TextScaled` 라벨에는 `UITextSizeConstraint`(MaxTextSize = 줄 높이)를 단다.
   - 확인: Studio 기기 에뮬레이터에서 iPhone 가로 화면(약 844×390)일 때 배너가 화면 높이의 35%를 넘지 않는다. devlog에 측정값을 적는다.
3. **[중간] 성문 상자에 방향 표시가 없음** — `src/server/World/MapBuilder.server.luau`
   - 각 성문 파트 위에 `BillboardGui`를 달고 `북문 N`, `남문 S`, `동문 E`, `서문 W`를 표시한다(고정 문구라 필터 없음). 글자 색은 그 성문 색(`GATE_COLORS`)과 맞추고, 검은 외곽선을 넣는다. `StudsOffset = (0, 9, 0)`, `MaxDistance = 250`, `AlwaysOnTop = false`이다.
   - 크기는 `Size = UDim2.fromScale(10, 3)`(스터드 기준)로 거리에 따라 함께 작아지게 한다. 휴대폰에서도 읽히는지 확인한다.
   - 배너의 `북문 6` 같은 표기와 글자가 같아야 한다(`LANE_KO`와 같은 이름).

## 2단계: 마무리
- `docs/devlog/2026-11-02.md`에 한 일과 사람이 확인할 체크리스트를 기록한 뒤 커밋한다.
- 커밋 후 `git push`한다(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 사람이 Studio에서 확인할 것 (devlog에 체크리스트로 복사)
- [ ] Play 직후 로비 배너가 "곧 시작합니다 · 시작까지 N초"
- [ ] 결과 화면이 떠 있을 때 웨이브 배너가 보이지 않음
- [ ] 이벤트 그림이 없을 때 배너에 빈 자리가 없음
- [ ] 2판째 시작 시 플레이어 체력이 가득 참
- [ ] 명령줄 `DirectorState.spec` 모두 PASS
- [ ] 이벤트 웨이브(웨이브 3 안개 등)에서 배너 그림이 글자 뒤에 깔리고 글자가 모두 읽힘
- [ ] 휴대폰(또는 기기 에뮬레이터 iPhone 가로)에서 배너·말풍선·결과 화면 글자가 화면을 덮지 않음
- [ ] 네 성문 위에 `북문 N`·`남문 S`·`동문 E`·`서문 W`가 보이고, 배너의 성문 이름과 같음
