# Day 8d 작업 지시 — 각개전투파 이동 수정 (짧은 작업)

먼저 AGENTS.md와 `docs/devlog/2026-11-04.md` 끝부분(day8c Studio 재측정)을 읽는다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/Support/SupportSquad.luau`, `SupportSquad.spec.luau`, devlog. 그 밖은 고치지 않는다.
- 환경 설정·패키지 설치 명령은 금지한다. 30초 넘게 멈추는 명령은 중단하고 보고한다.
- lune 하네스로 spec을 돌려도 되지만, Roblox 전용 동작(이동, `MoveTo`, `CFrame`)은 Studio에서만 확인된다는 점을 잊지 않는다. 확인은 Claude Code가 Studio MCP로 한다.

## 1. [높음] 각개전투파 원거리 지원대가 맡은 성문으로 가지 않음
- Studio 측정(사람 1명, solo, 웨이브 1·2): guardian은 남문 안쪽으로 갔다. ranger와 arcanist는 두 웨이브 내내 처음 생긴 등불 옆(±1, 7)에 머물렀다. 그 자리에서 공격은 했다(피해 220/305).
- 원인 추정:
  - `tickBot`이 사거리(ranger 120, arcanist 80) 안에 적이 있으면 0.25초마다 `root.CFrame`을 다시 쓴다. 이것이 `Humanoid:MoveTo` 이동을 끊는다.
  - solo는 웨이브 시작 때 `MoveTo`를 한 번만 부른다. `MoveTo`는 약 8초가 지나면 스스로 끝나므로 이동이 회복되지 않는다.
- 고칠 것:
  - 목표 지점(맡은 성문 안쪽 1/3 지점)에서 4스터드보다 멀면 **이동 중**이다. 이동 중에는 `root.CFrame`을 쓰지 않고 공격만 한다(방향 돌리기 없음). 공격 조준은 대상 위치를 그대로 쓰므로 몸 방향이 필요 없다. guardian은 앞쪽 판정이 있으니 도착한 뒤에만 몸을 돌린다.
  - 이동 중이면 `SupportRetargetSeconds`(5초)마다 `MoveTo`를 다시 부른다. solo와 coop 모두 같은 규칙이다.
  - 도착한 뒤에만 몸 방향을 대상 쪽으로 돌린다. 돌릴 때는 위치를 바꾸지 않는 방식(`CFrame.lookAt(root.Position, 대상의 수평 위치)`)을 쓴다.
- 확인 spec(순수 함수로 뺄 수 있으면): "목표까지 거리 > 4 → 이동 중(방향 돌리기 안 함)", "≤ 4 → 도착".

## 2. [낮음] 지원대 이름표의 직업 이름이 영어로 나옴
- 지금은 `지원대 · 협력파 · Guardian`처럼 나온다. 화면 문구가 모두 한국어이므로 고정 표로 바꾼다.
  - guardian → 수호자
  - ranger → 궁수
  - cleric → 사제
  - arcanist → 비전술사
- `ClassCatalog`(src/shared)는 고치지 않는다. `SupportSquad.luau` 안에 표를 둔다.

## 3. [낮음] MCP에서 `debugSupportReport()`가 다른 모듈 사본을 읽음
- Studio 명령줄·MCP에서 `require`하면 게임이 쓰는 SupportSquad와 다른 사본이 실행된다. 그래서 `choice=none bots=0`만 나온다.
- 고칠 것: 지원대 상태(유형, 지원대별 역할·맡은 성문·위치·피해·사망)를 `ReplicatedStorage`의 StringValue `SupportDebug`(JSON)에 웨이브 중 1초마다 써 둔다. `debugSupportReport()`는 그 값을 읽어 출력한다. 화면 표시용이 아니라 테스트용이다.

## 마무리
- devlog에 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] solo: 웨이브 시작 후 15초 안에 지원대 3명이 각각 서로 다른 성문 안쪽(목표 지점 6스터드 이내)에 도착
- [ ] coop: 기존처럼 한 성문 근처에 함께 있음(서로 10스터드 이내)
- [ ] 이름표 `지원대 · 각개전투파 · 궁수` 등 한국어
- [ ] `SupportDebug` 값으로 맡은 성문과 위치를 읽을 수 있음
