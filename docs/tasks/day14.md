# Day 14 작업 지시 — 게임 느낌 다듬기와 Day 첫 웨이브 설계 (기능 동결 전 마지막 기능)

먼저 AGENTS.md와 `docs/devlog/2026-11-05.md` 끝부분(day13c)을 읽는다. 게임 규칙·적 체력·피해 값은 바꾸지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일은 각 항목에 적은 것과 devlog, `docs/GAME_DESIGN.md`뿐이다.
- 두 `prompt.txt`, `schemas/`, `src/shared/`는 고치지 않는다.
- 외부 에셋 금지(소리·이미지 포함). Part·기본 UI·색만 쓴다.
- 새 RemoteEvent를 만들지 않는다. 클라이언트 효과는 이미 복제되는 값만 읽는다.
- 효과 코드가 실패해도 전투와 경기는 멈추면 안 된다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] Day 첫 웨이브도 디렉터가 설계 — `Director/DirectorService.server.luau`
- 지금: `runMatch`의 `currentPlan = FallbackWaves[1]` 때문에 모든 Day의 첫 웨이브가 "기본 웨이브"다. 마지막 웨이브 뒤에는 요약도 만들지 않는다.
- 고칠 것:
  - 파일 지역 변수 `firstWaveRequest = nil`을 둔다.
  - `runMatch`에서 웨이브 루프 안의 `playWave` 직후 `lastTracker = tracker`, `lastWavePlan = currentPlan`을 저장한다.
  - `publishResult` 첫 호출 **직후, `SupportSquad.clearMatch` 전에** 다음을 한다. 조건: `lastTracker`가 있고 플레이어가 1명 이상.
    - `nextDay`는 승리면 `day + 1`, 패배면 `day`다. `nextTotal = DayRules.waveCount(nextDay)`.
    - 대기 때와 같은 방식으로 roster를 만든다. 중복을 피해 `buildRoster()` 지역 함수로 뺀다.
    - 요약: `MatchStats.buildSummary(lastTracker, 0, lanternHealthPct(lantern), { tactic = lastWavePlan.tactic, event = lastWavePlan.event }, roster, nextDay, nextTotal, supportChoice)`. `wave = 0`은 "다음 Day가 아직 시작 전"이라는 뜻이다.
    - `local req = {}`를 `firstWaveRequest`에 넣고 `task.spawn`으로 `DirectorClient.requestNextWave(summary)`를 부른다. `WaveValidator.validate(requested, 1)`을 통과한 때만 `req.plan = clean`이다. 실패는 `warn`만 하고 끝낸다. 결과 화면을 기다리게 하지 않는다.
  - 다음 `runMatch`의 `local currentPlan = FallbackWaves[1]` 자리:
    - `firstWaveRequest`를 읽어 지역 변수에 담고 바로 `nil`로 지운다. 늦은 응답이 그다음 판에 쓰이면 안 된다.
    - `req.plan`이 있으면 `currentPlan = req.plan`, `currentSource = "muse"`. 아니면 지금처럼 대체 웨이브다.
- 첫 판(Day 1, 서버 시작 직후)은 요약이 없으니 대체 웨이브 그대로다.
- `fixtures/match_summaries/next_day_after_victory.json`, `next_day_after_defeat.json`을 추가한다. 위 요약 형식이고 `wave: 0`이다.
  - victory: day 2, total_waves 5, waves_left 5, lantern_health_pct 62, 플레이어 2명 + support 2명.
  - defeat: day 2, total_waves 5, waves_left 5, lantern_health_pct 0, breached_lane "east", 같은 구성.
  - `support_squad`와 `previous_wave`를 넣는다. 모델 호출은 하지 않는다.

## 2. [높음] 타격 반짝임과 피해 숫자 — 새 파일 `client/HitFx.client.luau`
- 적의 `Health` 어트리뷰트는 이미 복제된다. 서버 코드는 고치지 않는다.
- `Workspace.Enemies`(늦게 생겨도 기다림)의 자식 BasePart마다 이전 체력을 기억하고 `GetAttributeChangedSignal("Health")`을 듣는다. `ChildRemoved`에서 기억을 지운다. 체력이 늘면(Shaman 치유) 이전 값만 고치고 효과는 없다.
- 체력이 줄면:
  - **반짝임:** 몸체와 자손 BasePart의 `Color`를 흰색으로 0.1초 바꿨다 되돌린다. 원래 색은 적마다 처음 한 번만 저장한다. 연속으로 맞아도 흰색이 원래 색으로 저장되면 안 된다.
  - **숫자:** 맞은 위치 위에 클라이언트 전용 투명 파트(Anchored, CanCollide·CanQuery·CanTouch false)와 BillboardGui(100×36 픽셀, AlwaysOnTop)를 만든다. 글자는 줄어든 체력이다. 흰색 GothamBold, 검정 외곽선, 체력이 0이면 노란색이다. 위치를 약간 흩뜨리고(x·z ±1), 0.6초 동안 3스터드 올라가며 사라진다.
  - 소수는 반올림한다. 화면의 숫자는 동시에 20개까지만 두고, 넘으면 새 숫자를 만들지 않는다.
  - 보이는 거리는 80스터드 안, 그 밖은 숫자를 만들지 않는다.

## 3. [중간] 웨이브 시작 큰 글자 — 새 파일 `client/WaveStartText.client.luau`
- `ReplicatedStorage.DirectorState`(JSON)를 읽어 `phase`가 다른 값에서 `wave`로 바뀔 때 화면에 띄운다.
- 첫 줄 큰 글자 `웨이브 %d / %d`(`displayWave`, `totalWaves`), 작은 글자 `Day %d`. `boss`가 true면 첫 줄을 빨간 `보스 웨이브`로 한다.
- 위치 화면 가운데 위쪽(세로 32%), `Active=false`, 입력을 막지 않는다. `UiScale`을 다른 창과 같게 쓴다. 0.2초 나타남, 1.5초 유지, 0.4초 사라짐.
- **AI가 만든 웨이브 이름·한마디는 쓰지 않는다.** 숫자만 쓰므로 필터·고지가 필요 없다.

## 4. [중간] 등불이 맞을 때 경고 — `client/LanternBar.client.luau`
- 등불 `Health`가 줄면 화면 전체 붉은 프레임(별도 ScreenGui, `IgnoreGuiInset=true`, `Active=false`)이 투명도 0.75에서 1로 0.4초 동안 사라진다. 진행 중에 또 맞으면 다시 시작한다.
- 판 초기화로 체력이 늘 때는 나오지 않는다. 위쪽의 기존 깜빡임은 그대로 둔다.

## 마무리
- `docs/GAME_DESIGN.md`에 "Day 첫 웨이브는 지난 판 요약(wave=0)으로 설계, 실패하면 대체 웨이브"와 효과 3가지를 짧게 적는다.
- `README.md`의 "How Meta models are used" 디렉터 절에 "The first wave of each later Day is designed from how the previous Day ended."를 한 줄 넣는다(고칠 수 있는 파일에 포함).
- devlog에 "day14" 절로 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code)
- [ ] spec 모두 PASS, 오류·경고 없음
- [ ] PC 도구: 새 fixture 2개로 `tools/test_director.py` 실행, 스키마 통과, 첫 웨이브 적 수가 과하지 않음(키는 환경 변수만 쓰고 출력하지 않는다)
- [ ] Studio(키 없음): Day 2 첫 웨이브가 호출 실패 후 대체 웨이브로 멈춤 없이 진행. 가짜 요청 결과를 넣으면 source=muse로 적용. 늦은 응답이 다음 판에 안 쓰임
- [ ] 결과 화면이 요청 때문에 늦어지지 않음. 승리·패배 다음 Day 번호가 맞음
- [ ] 반짝임 뒤 적 색이 원래대로(연타 포함), 숫자 값이 실제 체력 감소와 같음, 처치 숫자 노란색(안 보이면 기록), 범위 마법 다수 타격에서 20개 제한, 끊김 없음
- [ ] 웨이브 시작 글자가 넘치지 않고 배너·체력바와 겹치지 않음, 터치를 막지 않음. 보스 웨이브 문구
- [ ] 붉은 프레임이 등불 피해에만 나옴
- [ ] 웨이브 1~3 회귀: 멈춘 적 0, 시간 초과 없음
- [ ] 스크린샷을 `docs/devlog/shots/day14/`에

사람이 실제 서버에서 확인한다(publish 후 휴대폰).
- [ ] Day 2 첫 웨이브 배너가 "기본 웨이브"가 아니고 AI 고지가 나옴
- [ ] 타격감, 큰 글자, 난이도
