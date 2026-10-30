# Day 11e 작업 지시 — 체력바 로딩 경고 (아주 짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day11d)" 표 1번 줄을 읽는다. 새 기능은 넣지 않는다.

## 공통 규칙
- 고칠 수 있는 파일: `src/client/LanternBar.client.luau`, devlog. 그 밖은 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.

## 1. [낮음] `Infinite yield possible on 'Workspace.Map:WaitForChild("Lantern")'` — `LanternBar.client.luau:91-92`
- Studio 확인: 로비 시작 때 1번 나온다. day11c부터 맵 장식과 NPC·적 외형이 늘어 서버가 맵을 늦게 마치기 때문으로 보인다. 그 뒤 체력바는 정상이다.
- 원인: 시간 제한 없는 `WaitForChild`가 5초를 넘기면 Roblox가 경고를 찍는다.
- 고칠 것: 등불을 찾을 때까지 **경고 없이** 기다린다.
  - `Workspace:WaitForChild("Map", 60)`, `map:WaitForChild("Lantern", 60)`처럼 시간 제한을 준다(시간 제한이 있으면 경고가 나오지 않는다).
  - 둘 중 하나라도 `nil`이면 루프로 다시 기다린다. 체력바 스크립트가 끝나 버리면 안 된다(경기 중 체력바가 없으면 안 됨).
  - 기다리는 동안 체력바는 지금처럼 가득 찬 상태로 보인다. 아래 `render()` 연결은 등불을 찾은 뒤에 한다.
- 서버 쪽 같은 대기(`DirectorService`, `NpcService`)는 경고가 나오지 않았으니 고치지 않는다.

## 마무리
- devlog에 "day11e" 절로 한 줄 적고 커밋한 뒤 `git push`(원격: origin/main)한다. push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] Play 두 번(로비 시작부터) 모두 `Infinite yield` 경고 없음, 오류 없음
- [ ] 체력바가 보이고 등불 피해에 맞춰 줄어듦, 배너와 겹칠 때 아래로 내려가는 동작 그대로
