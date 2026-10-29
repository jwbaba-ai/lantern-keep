# Day 8b 작업 지시 — "지원대: 혼자 와도 파티를 꾸린다"

먼저 AGENTS.md, docs/GAME_DESIGN.md, 가장 최근 `docs/devlog/` 파일(day8 결과)을 읽는다. **day8이 끝난 뒤에 시작한다.**

## 배경 (사람(Babazz) 설계, 2026-10-29)
- 로비에서 플레이어가 **지원대**를 요청하면, 서버가 규칙으로 움직이는 동료로 빈자리를 채운다.
- 유형은 둘이다.
  - **각개전투파**: 흩어져서 각자 성문을 맡는다.
  - **협력파**: 뭉쳐서 서로 치유한다.
- 지원대 유형에 따라 플레이 스타일이 달라지고, AI 디렉터가 다른 웨이브를 설계한다. 이것이 데모의 "두 팀이 서로 다른 판" 장면이 된다.
- 사람 없이 지원대만으로 실제 전투를 돌릴 수 있게 해서, Studio 자동 테스트에도 쓴다.

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다.
- 승인 범위(사람(Babazz) 승인됨 2026-10-29). 적힌 범위 밖으로는 고치지 않는다.
  - `src/shared/Config.luau`: 아래 `Support*` 키만 추가한다.
  - 두 `prompt.txt`: 아래 적은 문장 1개씩만 추가한다.
- `schemas/`와 생성 Luau 스키마 2개는 고치지 않는다.
- **지원대는 모델을 호출하지 않는다.** 규칙으로만 움직인다(전투 중 모델 호출 금지 규칙 유지).
- 지원대 이름표·안내 문구는 서버 코드에 적힌 고정 문구다. AI 고지는 붙이지 않는다.
- 환경 설정·패키지 설치 명령은 금지한다. 30초 넘게 멈추는 명령은 중단하고 보고한다.

## 0단계: day8 확인 결과 반영
day8 devlog의 체크리스트에 사람이 남긴 메모가 있으면 먼저 고치고 커밋한다.
- **[낮음] Bram 기본 셋째 대사가 새 시점과 맞지 않음** (사람 승인 2026-10-29): `Config.NpcDefaultLines.bram[3]`을 `"절반이 코앞이다. 버텨라."`에서 `"마지막 고비다. 버텨라."`로 바꾼다. 셋째 대사는 이제 마지막 웨이브 직전에 나온다. 다른 기본 대사는 그대로 둔다. 커밋은 1개만 한다.

## 1단계: 설정
`Config.luau` 새 키:
```lua
SupportMaxParty = 4, -- 사람 + 지원대 최대 인원
SupportRespawnSeconds = 10,
SupportRetargetSeconds = 5, -- 협력파가 목표 성문을 다시 고르는 간격
SupportHealBelowPct = 0.6, -- 협력파 cleric이 치유를 시작하는 체력 비율
SupportSquads = {
	solo = { label = "각개전투파", roles = { "guardian", "ranger", "arcanist", "ranger" } },
	coop = { label = "협력파", roles = { "guardian", "cleric", "ranger", "arcanist" } },
},
```
- 지원대 인원은 `SupportMaxParty - 사람 수`(0 이상)다. `roles` 앞에서부터 그 수만큼 쓴다. 혼자면 3명, 둘이면 2명, 넷이면 0명이다.

## 2단계: 다수결 투표 (`src/server/Support/SupportVote.luau`, 순수 함수)
- 선택지는 `solo`, `coop`, `none`(요청 안 함) 셋이다. 고르지 않은 사람은 표를 세지 않는다.
- `SupportVote.tally(votes, rng)` → `{ choice, counts, tie, reason }`
  - **가장 많은 표를 받은 선택지**가 결과다.
  - **동률**이면 동률인 선택지 중에서 `rng`(`Random`)로 하나를 뽑는다. `tie = true`로 두고, 동률이었던 선택지 목록을 함께 돌려준다.
  - 표가 하나도 없으면 `none`이다.
  - `none`이 이기면 지원대 없이 진행한다.
- `SupportVote.spec.luau` (PASS/FAIL 출력, 시드를 고정한 `Random.new(1)` 사용):
  - 2:1 → 다수 선택
  - 1:1 → `tie=true`, 결과가 동률 선택지 중 하나, 같은 시드면 같은 결과
  - 표 없음 → `none`
  - `none` 2표 : `coop` 1표 → `none`
  - 1인(투표 1표) → 그 표

## 3단계: 로비 투표 화면과 알림
- RemoteEvent `Remotes/SupportVote`(인자: 문자열).
  - 서버는 `phase == "lobby"`일 때만 받는다.
  - 값은 세 선택지 중 하나만 받는다.
  - 0.5초 안의 연속 입력은 무시한다.
  - 플레이어가 나가면 그 표를 지운다.
- 이전 판에 낸 표는 다음 로비에 그대로 남는다(바꾸려면 다시 누른다). 처음 들어온 플레이어는 표가 없다.
- 상태는 `ReplicatedStorage`의 StringValue `SupportState`(JSON)로 알린다.
  - 내용: `{ votes = { { name = DisplayName, choice } }, counts, result, tie, tied }`
  - DisplayName은 화면 표시용이다. 저장하거나 모델에 보내지 않는다.
- 클라이언트 `src/client/SupportVote.client.luau`:
  - 로비 동안 배너 아래에 패널을 보여 준다. 버튼 3개: `각개전투파`, `협력파`, `지원대 없이`
  - 실시간으로 누가 무엇을 골랐는지 한 줄씩 보여 준다. 예: `Babazz · 협력파`, `Player2 · 각개전투파`
  - 현재 표 수를 보여 준다. 예: `협력파 1 · 각개전투파 1 · 없음 0`
  - day7의 `UiScale` 배율을 쓴다.
- 로비가 끝나는 순간 서버가 집계하고, 6초 동안 결과를 알린다.
  - 다수: `다수결로 협력파 지원대가 합류합니다 (협력파 2 · 각개전투파 1)`
  - 동률: `동률(협력파 1 · 각개전투파 1)이라 무작위로 각개전투파를 골랐습니다`
  - 없음: `지원대 없이 시작합니다`
  - 로그: `[Support] vote counts=... result=... tie=true|false bots=N`

## 4단계: 지원대 생성과 행동 (`src/server/Support/SupportSquad.luau`, `SupportService.server.luau`)
- **생성**
  - 투표 결과가 나오면 빈자리만큼 지원대를 등불 옆에 만든다.
  - 모델은 `Players:CreateHumanoidModelFromDescription(HumanoidDescription.new(), Enum.HumanoidRigType.R15)`로 만들고, `workspace.Support` 폴더에 둔다.
  - 직업 체력은 `ClassCatalog.MaxHealth`를 쓴다.
  - 이름표(BillboardGui): `지원대 · 협력파 · Cleric`
- **신원:** 각 지원대는 `{ UserId = -1, -2, ..., IsSupport = true, Name = "Support1", role }` 테이블을 가진다. `MatchStats`의 `recordDamage`·`recordDeath`·`recordRevive`에 이 테이블을 그대로 넘긴다. MatchStats는 `player.UserId`만 쓰므로 바꾸지 않아도 되는지 확인하고, 필요하면 최소한으로 고친다.
- **공격:** `CombatService`의 직업별 공격 함수가 `player` 대신 "공격자"(UserId·root·character를 가진 값)를 받도록 고친다. 플레이어 RemoteEvent 경로의 동작은 그대로 유지한다.
  - 지원대는 직업 `Cooldown`마다 사거리 안에서 가장 가까운 적을 노린다(ranger·arcanist는 그 적의 위치를 조준으로 쓴다).
  - 쿨다운 검사는 같은 `checkCooldown`/`markAttacked`를 음수 UserId로 쓴다.
- **각개전투파 (`solo`)**
  - 웨이브 시작 때 공격 성문을 적이 많은 순으로 정렬한다. 사람이 서 있는 성문(가장 가까운 성문)은 뒤로 미룬다.
  - 지원대마다 서로 다른 성문을 하나씩 맡는다. 성문 안쪽(성문과 등불 사이 1/3 지점)으로 `Humanoid:MoveTo`로 이동한다.
  - 맡은 성문에서 벗어나지 않는다. 치유하지 않는다(cleric이 없는 구성).
- **협력파 (`coop`)**
  - 다 함께 적이 가장 많은 성문으로 이동하고, `SupportRetargetSeconds`마다 살아 있는 적이 가장 많은 성문으로 다시 고른다.
  - 서로 10스터드 안에 머문다.
  - cleric은 반경 안에서 체력 비율이 가장 낮은 아군을 치유한다(사람과 지원대 모두, `SupportHealBelowPct` 이하일 때). 부활 기록 규칙은 기존과 같다.
- **쓰러짐:** `SupportRespawnSeconds` 뒤 등불 옆에서 다시 나온다. 사망은 기록한다.
- **판 끝:** 결과 화면에서 지원대를 모두 지우고, 다음 로비 투표 결과로 다시 만든다.

## 5단계: 기록·밸런스 연동
- **파티 인원:** 사람 + 지원대 수(최대 `SupportMaxParty`)를 쓴다. `DirectorService`의 `#Players:GetPlayers()`와 `EnemyFactory`의 파티 배율 계산을 공용 함수 `SupportSquad.partySize()` 하나로 바꾼다.
- **자동 처치 타이머(`AutoKillWhenNoPlayers`):** 사람이 0명이어도 지원대가 있으면 끈다(실제 전투로 진행).
- **디렉터 요약(`MatchStats.buildSummary`)**
  - roster에 지원대를 `{ role, support = true }`로 넣는다.
  - 요약 맨 위에 `support_squad = "solo"|"coop"|"none"`을 더한다.
- **NPC 기억**
  - 파티 키와 P1~P4 슬롯은 **사람만**(지금의 `startIds`) 쓴다. 지원대가 바뀌어도 같은 파티로 기억이 이어진다.
  - 경기 기록 결과에 `support_squad`를 더한다. 지원대 개별 기록은 저장하지 않는다.
  - `partySize` 검증(P 토큰 범위)도 사람 수 기준 그대로다.
- **프롬프트** (각 1문장만 추가)
  - `src/server/Director/prompt.txt`: "Roster entries with support=true are rule-based allies the team called in (support_squad: solo = spread out one per gate, coop = grouped with a healer). Treat them as part of the team."
  - `src/server/NpcMemory/prompt.txt`: "If support_squad is solo or coop, you may mention it by its Korean name (각개전투파 / 협력파)."

## 6단계: 테스트 수단
- `SupportSquad.spec.luau`:
  - 사람 0~4명일 때 지원대 수 4,3,2,1,0
  - 역할 순서가 Config와 같은지
  - `partySize` 상한 4
- `NpcDebug.debugSupport(choice)`: 명령줄에서 호출하면 다음 로비의 투표 결과를 `choice`로 정한다(투표 무시, 로그에 `forced` 표시). 사람이 0명이면 지원대 4명만으로 실제 전투를 진행한다.
- `NpcDebug.debugSupportReport()`: 지원대별 역할·맡은 성문·피해·사망을 한 줄씩 출력한다.

## 7단계: 마무리
- `docs/GAME_DESIGN.md`에 "지원대" 절을 추가한다: 투표 규칙, 두 유형, 기록 규칙.
- devlog에 한 일, 추가한 Config 키, 사람이 확인할 체크리스트를 기록한 뒤 커밋한다.
- 커밋 후 `git push`(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (devlog에 체크리스트로 복사)
Claude Code가 Studio MCP로 확인:
- [ ] 명령줄 `SupportVote.spec`, `SupportSquad.spec`, 기존 spec 모두 PASS
- [ ] Play(사람 0명) + `debugSupport("coop")`
  - 지원대 4명이 실제 전투로 Day 1을 끝까지 진행한다(자동 처치 타이머 꺼짐)
  - Output에 `[Support] ... bots=4`가 찍힌다
  - `debugSupportReport()`에서 4명이 같은 성문 근처에 있다
- [ ] 같은 방법으로 `debugSupport("solo")` → 지원대가 서로 다른 성문을 맡는다
- [ ] 두 실행의 `[MatchStats]` 요약에 `support_squad`가 서로 다르게 찍힌다

사람이 확인:
- [ ] 로비 투표 패널이 보이고, 누가 무엇을 골랐는지 실시간으로 나온다
- [ ] 결과 알림이 6초 동안 보이고, 동률이면 "무작위로 골랐습니다"가 나온다(Studio 다중 클라이언트 2명으로 1:1 시험)
- [ ] 실제 서버에서 혼자 협력파로 한 판, 각개전투파로 한 판을 해 보면 디렉터의 웨이브 2 이후 구성이 달라진다(데모 녹화 후보)
- [ ] 다음 판에 Bram이나 Mira가 지난 판의 지원대 유형을 언급한다
