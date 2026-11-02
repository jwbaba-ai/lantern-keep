# Day 13b 수정 — Studio 확인 FAIL 2건 (아주 짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day13)" 표 5-5, 7-2를 본다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/World/MapBuilder.server.luau`, `src/server/World/Labels.luau`, `src/server/Support/SupportSquad.luau`(`buildModel` 이름표 부분만), devlog, `docs/GAME_DESIGN.md`.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] 궁수가 성문 너머 적을 못 맞힘 — `MapBuilder.server.luau`
- 측정: 성문 밖 적에게 쏜 5발이 모두 `Gates/north`에서 끝나고 피해 0이다. 지원대 궁수도 같다.
- 원인: `CombatService.luau:124`의 `Workspace:Raycast`는 `CanCollide`를 보지 않는데 성문 파트가 `CanQuery=true`다.
- 고칠 것: 성문 파트를 `CanQuery = false`로 한다. 두 곳 모두 넣는다.
  - `buildMap`의 `makePart` 값
  - 저장된 맵을 맞추는 아래쪽 루프의 `gate.Transparency = 0.8` 옆
- 코드에서 레이캐스트는 위 한 곳뿐이고, 성문 위치는 `gate.Position`으로만 읽으므로 다른 곳은 고치지 않는다.

## 2. [낮음] 같은 자리 지원대 이름표가 멀면 겹침 — `Labels.luau`, `SupportSquad.luau`
- 측정: 이름표는 픽셀 고정(높이 24)이고 간격은 1.3스터드라 약 15스터드부터 겹친다.
- 고칠 것:
  - `Labels.attach`에 선택 값 `opts.size`(UDim2)를 더한다. 없으면 지금처럼 `UDim2.new(0, 140, 0, 24)`다. NPC·적 이름표는 바뀌지 않는다.
  - `SupportSquad.buildModel`의 이름표에 `size = UDim2.fromScale(5, 1.1)`을 넣고 `maxDistance`를 50에서 40으로 줄인다. 높이가 스터드 단위라 거리와 상관없이 1.3 간격 안에 들어간다.
  - 이름표 글자와 `offset`은 그대로 둔다.

## 마무리
- `docs/GAME_DESIGN.md`에 "성문은 사격을 막지 않음"과 지원대 이름표 크기를 짧게 적는다.
- devlog에 "day13b" 절로 한 일과 바뀐 값을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS, 오류·경고 없음
- [ ] 성문 밖 적을 궁수·지원대 궁수가 맞혀 체력이 준다
- [ ] 성문 깜빡임, 성문 글자, 지원대 시작 위치와 이동이 그대로다
- [ ] 같은 자리 지원대 이름표가 12·35스터드에서 겹치지 않고, 5스터드 거리에서 화면을 크게 막지 않는다. NPC·적 이름표 크기는 그대로다
- [ ] 웨이브 1~3 회귀: 멈춘 적 0, 시간 초과 없음
- [ ] 스크린샷을 `docs/devlog/shots/day13b/`에
