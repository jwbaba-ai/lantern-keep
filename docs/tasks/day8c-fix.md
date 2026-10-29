# Day 8c 작업 지시 — 지원대 버그 수정 (짧은 작업)

먼저 AGENTS.md와 `docs/devlog/2026-11-04.md` 끝부분(day8b Claude Code 리뷰·Studio 결과)을 읽는다.
새 기능은 넣지 않는다. 아래 3건만 고치고, 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/Support/SupportSquad.luau`, `src/server/Director/DirectorService.server.luau`, `src/server/Director/MatchStats.luau`와 각 spec. 그 밖은 고치지 않는다.
- `src/shared/`, `schemas/`, 두 `prompt.txt`는 고치지 않는다.
- 환경 설정·패키지 설치 명령은 금지한다. 30초 넘게 멈추는 명령은 중단하고 보고한다.

## 1. [높음] 지원대를 만들면 경기가 로비에서 멈춤 — `SupportSquad.luau:232`
- Studio 재현: 투표 결과가 solo나 coop이면 `attempt to index nil with 'new'` 오류가 난다. 오류가 `finalizeLobby` → `spawnMatch` → `buildModel`로 올라가 DirectorService의 판 루프가 멈추고, 배너가 "곧 시작합니다"에 고정된다.
- 원인: Roblox에는 `HumanoidDescription` 전역이 없다.
- 고칠 것: `Instance.new("HumanoidDescription")`을 쓴다.
- 메모: day8b에서 lune 하네스로 spec을 돌렸지만, 하네스가 Roblox 전역을 흉내 내서 이 오류를 잡지 못했다. Roblox 전용 API는 Studio에서만 확인된다는 점을 devlog에 적는다.

## 2. [높음] 지원대 오류가 경기를 멈추지 않게 — `DirectorService.server.luau`
- 절대 규칙("경기는 절대 멈추지 않는다")에 맞춘다. `SupportSquad.finalizeLobby()` 호출을 `pcall`로 감싼다.
- 실패하면 다음 순서로 처리한다.
  1. `warn("[Support] spawn failed: ...")`를 남긴다.
  2. 이미 만든 지원대를 `SupportSquad.clearMatch()`로 지운다(이것도 `pcall`).
  3. `supportChoice = "none"`으로 두고 경기를 계속한다.
- `SupportSquad.clearMatch()` 호출(결과 화면)도 `pcall`로 감싼다.
- 지원대 리스폰처럼 웨이브 중에 도는 지원대 코드는 `task.spawn` 안에서 오류가 나도 웨이브 루프에 영향이 없는지 확인한다. 영향이 있으면 같은 방식으로 감싼다.

## 3. [중간] 디렉터 요약에서 지원대 표시가 빠짐 — `MatchStats.buildSummary`
- 원인: `tracker.roles`(이번 웨이브에 피해를 준 사람·지원대)를 먼저 `addPlayer(..., false)`로 넣는다. 그 뒤 roster의 지원대 항목(`support=true`)은 이미 본 userId라 건너뛴다. 그래서 피해를 준 지원대는 `support` 표시 없이 요약에 들어간다.
- 고칠 것: 이미 들어간 userId여도 roster 항목이 `support=true`이면 그 항목에 `support = true`를 붙인다. 또는 roster를 먼저 넣는다.
- 확인: `MatchStats` 관련 spec(없으면 `SupportSquad.spec`)에 1건을 추가한다. "지원대(UserId 음수)가 피해를 준 tracker + roster의 support=true → 요약 players의 그 항목에 `support == true`".

## 마무리
- `docs/devlog/2026-11-04.md` 끝에 한 일을 짧게 적고 커밋한다.
- 커밋 후 `git push`(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] `debugSupport("coop")` → 지원대가 생기고 웨이브 1이 시작된다(배너가 로비에 멈추지 않음)
- [ ] 웨이브 1 뒤 `[MatchStats]` JSON에 `support_squad="coop"`, 지원대 항목마다 `"support":true`
- [ ] `debugSupport("solo")` → 지원대가 서로 다른 성문을 맡는다
- [ ] (임시로 오류를 일으키는 방법이 있으면) 지원대 생성 실패 시 `[Support] spawn failed` 경고 후 지원대 없이 경기가 계속된다
- [ ] 판이 끝나면 `workspace.Support`가 비고, NPC 기억 저장 로그에 오류가 없다
