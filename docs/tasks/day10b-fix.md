# Day 10b 작업 지시 — day10 Studio 확인에서 나온 수정 (짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day10)" 표를 읽는다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/client/NpcBubble.client.luau`, `src/client/LanternBar.client.luau`, `src/server/Support/SupportSquad.luau`, `SupportSquad.spec.luau`, devlog. 그 밖은 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- 참고: 이번 오류는 Roblox Enum 타입 오류라 lune 하네스로는 잡히지 않는다. Roblox 속성에 Enum을 넣을 때는 **속성 이름과 같은 Enum**(`TextYAlignment` → `Enum.TextYAlignment`)인지 한 번 더 확인한다.

## 1. [높음] NPC 대사가 화면에 전혀 나오지 않음 — `NpcBubble.client.luau:240`
- Studio 오류: `body.TextYAlignment = Enum.VerticalAlignment.Top`에서 "EnumItem of type TextYAlignment expected"가 난다.
  - 스크립트가 `makeRow("bram")` 도중 멈춘다.
  - 그래서 `npcSay.OnClientEvent` 연결이 안 되고, AI 대사와 기본 말풍선이 **둘 다** 나오지 않는다.
- 고칠 것:
  - `Enum.TextYAlignment.Top`으로 바꾼다.
  - 같은 파일의 다른 Enum 대입도 모두 속성과 타입이 맞는지 확인한다.
- 대화창의 "AI가 생성한 대사입니다" 글자를 14에서 **16**으로 키운다(AI 고지가 휴대폰에서 잘 보이게).
- 긴 대사가 3줄을 넘으면 넘친다. 본문은 `TextTruncate = Enum.TextTruncate.AtEnd`로 3줄에서 자른다. `ClipsDescendants`로는 자기 글자가 잘리지 않는다.

## 2. [낮음] 체력바가 배너 아래로 내려갈 때 너무 많이 내려감 — `LanternBar.client.luau:63`
- Studio 측정: 의도는 배너 아래 끝 + 8px인데 실제는 + 92px이다.
- 원인: `UIScale`은 자기 프레임의 **위치에는 적용되지 않는다**. 그런데 Position 오프셋을 배율 `s`로 나눴다.
- 고칠 것: `frame.Position = UDim2.new(1, -12, 0, math.floor(bp.Y + bs.Y + 8 + 0.5))`. 나누기를 없앤다.
  - `AbsolutePosition`은 GuiInset 아래 원점 기준이다. 같은 ScreenGui 설정(IgnoreGuiInset)이면 그대로 맞는다. 다르면 보정한다.

## 3. [중간] solo 지원대가 적이 가장 많은 성문을 비워 둠 — `SupportSquad.assignSoloLanes` 호출부
- Studio 측정: 사람이 등불 옆(성채 중앙)에 서 있었는데, `humanLanes`가 가장 가까운 성문(north)을 "사람이 맡은 성문"으로 쳤다. 그래서 적이 가장 많은 north에는 봇이 한 명도 가지 않았다.
- 고칠 것: `humanLanes`는 사람이 **성문에서 25스터드 안**에 있을 때만 그 성문을 맡은 것으로 친다. 성채 중앙에 있으면 어느 성문도 맡지 않은 것으로 본다.
  - 25는 `SupportSquad.luau` 안 상수 `HUMAN_GATE_RADIUS`로 둔다.
- 순수 함수로 빼서 spec을 추가한다.
  - "사람 위치 (0,3,0), 성문 거리 60 → 맡은 성문 없음 → 적 수 north 6/south 4/east 3에서 봇 3명이 north·south·east"
  - "사람이 north 성문 10스터드 안 → 봇은 south·east·west 순"

## 마무리
- devlog에 "day10b" 절로 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다. push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] NpcBubble 스크립트 오류 없음
  - 가짜 isAI=true 대사 → 아래 대화창에 Bram 위·Mira 아래, 겹침 없음, 화면 안, "AI가 생성한 대사입니다" 보임
  - 9초 뒤 사라짐, 머리 위 "…" 보임
  - 긴 대사는 3줄에서 잘림
- [ ] 기본 대사(isAI=false)는 머리 위 말풍선으로 나옴
- [ ] 겹칠 때 체력바 y = 배너 아래 끝 + 8(±2)
- [ ] solo: 사람이 등불 옆에 있으면 적이 가장 많은 성문에 봇이 배정됨
- [ ] spec 모두 PASS
