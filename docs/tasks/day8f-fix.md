# Day 8f 작업 지시 — 패배 웨이브 수 버그 (아주 짧은 작업)

먼저 AGENTS.md와 `docs/devlog/2026-11-04.md` 끝부분(day8e Studio 재측정)을 읽는다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/Director/DirectorService.server.luau`, `src/server/Support/SupportSquad.luau`, 관련 spec, devlog. 그 밖은 고치지 않는다.
- 환경 설정·패키지 설치 명령, Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.

## 1. [중간] 패배한 웨이브까지 "생존"으로 셈 — `DirectorService.server.luau:420` 근처
- Studio 측정: 웨이브 3 도중 등불이 꺼졌는데 결과 화면이 "3웨이브 중 3웨이브 생존"으로 나왔다.
- 원인: `playWave` 뒤에 등불 체력을 보기 전에 `wavesCompleted = wave`를 넣는다. 이 값은 결과 화면과 NPC 기억(`waves_completed`)에 함께 쓰여서, NPC가 틀린 사실을 기억하게 된다.
- 고칠 것: `playWave` 뒤 등불 체력이 0 이하이면 `wavesCompleted`를 올리지 않고 반복을 끝낸다. 그러면 웨이브 3에서 지면 2가 된다. 승리, 시간 초과, `debugFastMatch`(디버그 건너뛰기)는 지금처럼 그 웨이브를 완료로 센다.
- 확인: 순수 함수로 뺄 수 있으면 spec 1건을 추가한다. "웨이브 3 진행 후 등불 0 → 완료 2, 웨이브 3 진행 후 등불 > 0 → 완료 3".

## 2. [낮음] 판이 끝나도 `SupportDebug` 값이 남음 — `SupportSquad.luau`
- `clearMatch()`에서 `SupportDebug` 값을 `{ choice = "none", bots = {} }`로 덮어쓴다. 그래야 지원대가 없는 다음 판에 이전 판 기록이 나오지 않는다.

## 마무리
- devlog에 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] 웨이브 중간에 패배 → 결과 "3웨이브 중 2웨이브 생존", NPC 저장 기록 `waves_completed=2`
- [ ] 판이 끝난 뒤 `debugSupportReport()` → `bots=0`
