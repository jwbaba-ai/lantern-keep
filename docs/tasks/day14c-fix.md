# Day 14c 수정 — 처치된 몸체가 0.15초 동안 살아 있는 적처럼 동작 (아주 짧은 작업)

day14b에서 처치된 적을 0.15초 뒤에 지우게 됐다. 그동안 몸체가 `Workspace.Enemies`에 남아 있어서, 폴더를 직접 도는 코드가 죽은 적을 살아 있는 적처럼 다룬다. 피해 처리(`EnemyFactory.damage`)는 `active`를 보므로 문제없다. 새 기능은 넣지 않는다. 한 커밋으로 해도 된다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/Combat/EnemyCounter.server.luau`, `src/server/Support/SupportSquad.luau`, devlog.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 고칠 것: `Health`가 0 이하인 몸체 건너뛰기
판단 기준은 `(body:GetAttribute("Health") or 0) <= 0`이다. 아래 다섯 곳의 `body:IsA("BasePart")` 검사에 이 조건을 더한다.
1. `EnemyCounter.server.luau` 바깥 루프: 죽은 적이 근접·궁수 피해를 주지 않는다.
2. 같은 파일 Shaman 치유 루프의 `other`: 죽은 적을 치유하지 않는다. 죽은 Shaman은 1번 때문에 치유하지 않는다.
3. `SupportSquad.luau` `nearestEnemy`
4. 같은 파일 `chosenEnemyPart`의 `list` 만들기
5. 같은 파일 `busiestLiveLane`의 개수 세기

같은 판단을 여러 번 쓰므로 각 파일에 `isAlive(body)` 지역 함수를 하나씩 두어도 된다. 다른 동작은 바꾸지 않는다.

## 마무리
- devlog에 "day14c" 절로 한 줄 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로, day14b 확인과 함께)
- [ ] spec 모두 PASS, 오류·경고 없음
- [ ] 처치 직후 0.15초 동안 죽은 몸체가 플레이어를 때리지 않고, 지원대가 겨냥하지 않음
- [ ] day14b-fix.md 끝의 확인 항목 전부
