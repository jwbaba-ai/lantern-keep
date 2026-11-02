# Day 14b 수정 — 처치 숫자와 큰 글자 겹침 (아주 짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day14)" 표 7, 12번을 본다. 새 기능은 넣지 않는다. 항목마다 커밋한다. 표 1번(Studio의 스크립트 복제)은 코드 문제가 아니라 Claude Code가 처리하므로 고치지 않는다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/Enemies/EnemyFactory.luau`, `src/client/WaveStartText.client.luau`, devlog.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] 마지막 타격에 숫자·반짝임이 없음 — `EnemyFactory.luau` `resolve`
- 측정: 처치된 적 85마리 중 클라이언트가 `Health` 0을 본 적이 없다. `SetAttribute("Health", 0)` 직후 같은 프레임에 `body:Destroy()`를 해서 변경이 복제되기 전에 사라진다.
- 고칠 것: `resolve`의 `body:Destroy()`를 다음처럼 나눈다.
  - `how == "killed"`이면 `body.CanQuery = false`로 두고 `task.delay(0.15, function() body:Destroy() end)`.
  - 그 밖(`arrived` 등)은 지금처럼 바로 `body:Destroy()`.
- `active[body] = nil`, `onResolved` 호출, 처치 집계 시점은 그대로 둔다. 이미 지워진 파트를 다시 `Destroy`해도 문제없다.

## 2. [중간] 웨이브 1 큰 글자가 투표 결과 창을 가림 — `WaveStartText.client.luau`
- 측정: 투표 결과 창(y 108~223)과 글자 틀(y 106~172)이 겹친다. 결과 창은 로비 뒤 6초 동안 보인다.
- 고칠 것: `NpcBubble.client.luau`가 대사를 미루는 것과 같은 방식으로, 결과 창이 떠 있으면 큰 글자를 미룬다. `NpcBubble.client.luau`와 `SupportVote.client.luau`는 고치지 않는다.
  - `show(data)` 부르기 전에 `ReplicatedStorage.SupportState`(JSON)를 `pcall`로 읽는다. `announce`가 비어 있지 않고 `announce_until`이 `Workspace:GetServerTimeNow()`보다 뒤면, 남은 시간 + 0.2초 뒤에 부른다.
  - 읽기 실패, 값 없음, 숫자 아님은 바로 보여 준다.
  - 미룬 사이에 phase가 `wave`가 아니게 되면 보여 주지 않는다. 판이 빨리 끝난 경우 결과 화면에 뜨면 안 된다.

## 마무리
- devlog에 "day14b" 절로 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS, 오류·경고 없음. Studio에 `HitFx`, `WaveStartText`가 하나씩만 있음
- [ ] 처치 타격에 반짝임과 노란 숫자가 나옴. 숫자가 타격당 1개
- [ ] 처치 집계, 웨이브 종료 시점, 지원대 목표 선택이 그대로. 처치된 적이 0.15초 뒤 사라지고 사격을 막지 않음
- [ ] 등불 도착 적은 바로 사라짐, 숫자 없음
- [ ] 웨이브 1 큰 글자가 투표 창이 닫힌 뒤 나오고, 지원대 없는 판에서는 바로 나옴
- [ ] 끊김: 범위 마법 다수 타격 중 프레임 시간(day14에서 못 잰 항목)
- [ ] 웨이브 1~3 회귀: 멈춘 적 0, 시간 초과 없음
