# Day 14g — 대기 건너뛰기 투표 (테스트·플레이 시간 줄이기)

**day14f가 끝난 뒤에 한다.** 먼저 AGENTS.md와 devlog 끝부분(day14f)을 읽는다. 게임 규칙·수치는 바꾸지 않는다. 항목마다 커밋한다.

## 무엇을 만드나
웨이브 사이 대기(20초)와 결과 화면(15초)에서 사람 플레이어가 "건너뛰기"를 누르고, 인원에 맞는 동의 수가 모이면 남은 대기를 바로 끝낸다.

## 공통 규칙
- 고칠 수 있는 파일: 새 파일 `src/server/Director/SkipVote.luau`, `src/server/Director/SkipVote.spec.luau`, `src/client/SkipWait.client.luau`, 그리고 `src/server/Director/DirectorService.server.luau`(대기 루프 두 곳과 원격 이벤트 연결만), devlog, `docs/GAME_DESIGN.md`.
- **새 RemoteEvent `Remotes.SkipWait` 하나만 허용한다**(사람 승인됨). 그 밖의 RemoteEvent는 만들지 않는다.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 외부 에셋 금지. 기본 UI만 쓴다.
- 건너뛰기 코드가 실패해도 경기는 멈추면 안 된다. 실패하면 지금처럼 정해진 시간만큼 기다린다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. 동의 규칙 — `SkipVote.luau` (순수 함수) + spec
- `SkipVote.needed(playerCount)`: 사람 플레이어 수에 따른 필요한 동의 수.
  - 0명 → 0 (건너뛰기 없음), 1명 → 1, 2명 → 2, 3명 → 2, 4명 → 3. 일반식은 `n <= 2`면 `n`, 아니면 `math.ceil(n * 2 / 3)`.
- `SkipVote.passed(voteCount, playerCount)`: `playerCount >= 1`이고 `voteCount >= needed(playerCount)`이면 true.
- 지원대 봇은 플레이어 수와 표에 넣지 않는다.
- spec: 위 5가지 인원의 needed, 1명 1표 통과, 2명 1표 불통과, 3명 2표 통과, 4명 2표 불통과, 0명 불통과.

## 2. 서버 연결 — `DirectorService.server.luau`
- `Remotes.SkipWait`(RemoteEvent)를 만든다(없을 때만). 클라이언트가 인자 없이 보내면 그 플레이어의 표를 켜고 끈다(토글).
- 표는 서버 지역 테이블 `skipVotes[userId] = true`에 둔다. 지금 접속해 있는 플레이어의 표만 센다(나간 사람 표는 세지 않는다).
- 복제: `ReplicatedStorage`의 어트리뷰트 `SkipOpen`(bool), `SkipVotes`(number), `SkipNeeded`(number)로 알린다. 표가 바뀌거나 사람이 들고 날 때 갱신한다.
- **건너뛰기가 열리는 곳 두 곳만:**
  - **웨이브 사이 대기:** 디렉터 응답(또는 대체 웨이브)이 확정되고 다음 웨이브 정보를 publish한 **뒤**의 `restLeft` 루프. 열린 뒤 **최소 3초**는 기다린다(배너·성문 미리보기를 볼 시간). 그 뒤 `SkipVote.passed`면 루프를 빠져나간다. 디렉터 요청 자체는 기다린다(건너뛰기 때문에 대체 웨이브가 되면 안 된다).
  - **결과 화면:** 기억 요약·저장이 끝나고 두 번째 `publishResult` 뒤의 `task.wait(restartSeconds)`를 0.25초 단위 루프로 바꾼다. 최소 3초 뒤 `passed`면 빠져나간다.
- 열 때 표를 모두 비우고 `SkipOpen=true`, 루프를 나가면(건너뛰기든 시간 끝이든) 표를 비우고 `SkipOpen=false`로 둔다. 웨이브 중·로비에서는 열지 않는다(로비는 지금처럼 모두 투표하면 바로 끝난다).
- 건너뛰면 `print("[Director] skip wait phase=%s votes=%d/%d")`를 남긴다.
- `debugFastMatch` 동작은 그대로 둔다.

## 3. 클라이언트 버튼 — `SkipWait.client.luau`
- `SkipOpen`이 true일 때만 버튼을 보인다. 위치는 화면 오른쪽 아래, 휴대폰 점프 버튼 왼쪽 위(점프 버튼을 가리지 않게). 크기 140×44, `UiScale`을 다른 창과 같게 쓴다.
- 글자: `건너뛰기 %d/%d`(`SkipVotes`/`SkipNeeded`). 내가 눌렀으면 배경을 초록으로, 글자를 `취소 %d/%d`로 바꾼다. 누르면 `SkipWait:FireServer()`.
- 내 표 여부는 클라이언트가 누른 상태로 기억하고, `SkipOpen`이 false가 되면 지운다.
- 결과 화면·배너·쿨다운 막대·NPC 대화창과 겹치지 않는지 휴대폰 크기에서 확인할 수 있게 위치 값을 devlog에 적는다.

## 마무리
- `docs/GAME_DESIGN.md`에 건너뛰기 규칙(인원별 동의 수, 최소 3초, 열리는 곳)을 짧게 적는다.
- devlog에 "day14g" 절로 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS(SkipVote 포함), 오류 0
- [ ] 1인: 웨이브 사이에서 누르면 3초 뒤(이미 3초 지났으면 바로) 다음 웨이브 시작. 결과 화면도 같음
- [ ] 다시 누르면 취소되고 시간대로 진행. 디렉터 요청 중에는 버튼이 안 보임
- [ ] 웨이브 중·로비에서는 버튼이 안 보임. 건너뛴 뒤 다음 웨이브·다음 판이 정상(멈춘 적 0)
- [ ] 휴대폰 크기에서 버튼이 다른 UI와 겹치지 않음(스크린샷)
