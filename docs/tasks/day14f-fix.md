# Day 14f 수정 — 실제 서버에서 기억 요약 실패, Day 전환 때 투표 창이 번쩍임 (게시 후 발견)

사람이 publish한 실제 서버에서 1인 협력파로 3 Day를 플레이한 영상에서 찾은 문제다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/NpcMemory/NpcClient.luau`, `src/client/SupportVote.client.luau`, `src/client/WaveStartText.client.luau`, `src/client/NpcBubble.client.luau`, `tools/test_npc.py`, devlog.
- `schemas/`, 두 `prompt.txt`, `src/shared/`(`Config` 포함)는 고치지 않는다. 디렉터 호출 설정은 바꾸지 않는다.
- API 키를 코드·로그·출력 어디에도 넣지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] 기억 요약이 매번 실패 — `NpcClient.luau`
- 측정: 결과 화면에 "다음 판 대사: 기본 대사 (요약 실패)"가 Day마다 나온다. PC 도구(`tools/test_npc.py`, 게임과 같은 프롬프트·스키마)로 재면 지금 설정(`reasoning_effort=low`)은 **응답 17~25초, 출력 1,799~2,905토큰**이다. 게임은 `Config.RequestTimeoutSeconds=15`, `Config.MaxCompletionTokens=2000`을 그대로 써서 시간 초과나 출력 잘림으로 실패한다.
- `reasoning_effort=minimal`로 재면 9~16초, 752~1,419토큰이고 대사 품질은 그대로였다. (`none`은 모델이 지원하지 않는다.)
- 고칠 것: `NpcClient`에만 쓰는 지역 상수를 둔다. `Config`는 고치지 않는다.
  - `NPC_REASONING_EFFORT = "minimal"`
  - `NPC_MAX_COMPLETION_TOKENS = 4000`
  - `NPC_TIMEOUT_SECONDS = 40`
  - payload의 `reasoning_effort`, `max_completion_tokens`, `RequestAsync`의 `Timeout`에 이 값을 쓴다. 모델 이름·URL·Secret은 `Config` 그대로다.
- 실패 원인을 알 수 있게 `warn`에 HTTP 상태, `choices[1].finish_reason`(있으면), 걸린 초를 넣는다. 응답 본문·키·헤더는 넣지 않는다. 성공하면 `print("[Npc] summarize ok %.1fs")`를 한 줄 남긴다.
- 결과 화면은 이미 요약을 기다렸다가 `MatchRestartSeconds`를 보여 준다(`DirectorService`). 그 흐름은 바꾸지 않는다.
- `tools/test_npc.py`: 게임과 같게 `max_completion_tokens=4000`을 보내고, 기본 effort를 환경 변수 `NPC_EFFORT`(없으면 `minimal`)로 읽는다. 디렉터용 `DIRECTOR_EFFORT`는 쓰지 않는다.

## 2. [중간] Day가 넘어갈 때 투표 창이 잠깐 번쩍임 — `SupportVote.client.luau`
- 측정: Day 1 결과 화면 뒤 로비가 0.4초 만에 끝난다. 이전 판에 낸 표가 다음 로비에 그대로 남아 모두 투표한 것으로 보기 때문이다(의도한 동작이다). 그 0.4초 동안 투표 창이 떴다 사라진다.
- 고칠 것: `render()`의 로비 분기에서, `ReplicatedStorage:GetAttribute("MatchNumber")`가 2 이상이고 `support.votes`에 내 표(`entry.userId == player.UserId` 또는 `entry.name == player.DisplayName`)가 이미 있으면 창을 보이지 않는다(`frame.Visible = false`). 첫 판, 아직 투표하지 않은 사람(새로 들어온 사람 포함)에게는 지금처럼 보인다.
- 로비 뒤 집계 알림(6초)은 그대로 둔다.

## 3. [낮음] 웨이브 1 큰 글자와 NPC 대화창이 겹침 — `WaveStartText.client.luau`, `NpcBubble.client.luau`
- 측정: Day 2 웨이브 1 시작에 '웨이브 1 / 5' 큰 글자와 Bram·Mira 대화창 두 줄이 같은 때 떠서, 큰 글자 아래쪽과 'Day 2'가 대화창에 덮인다.
- 고칠 것:
  - `WaveStartText`: 글자를 띄울 때 `player:SetAttribute("WaveTextUntil", Workspace:GetServerTimeNow() + 2.1)`을 넣는다(0.2 + 1.5 + 0.4초).
  - `NpcBubble`: `showDialog`(대화창)를 띄우기 전에 이 값이 지금보다 뒤면 남은 시간 + 0.1초 뒤에 띄운다. 값이 없거나 숫자가 아니면 바로 띄운다. 말풍선 점(`showDot`)은 그대로다.
  - 투표 알림 때문에 미루는 지금 동작과 함께 쓴다(둘 중 늦은 쪽).

## 마무리
- devlog에 "day14f" 절로 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것
- Claude Code가 PC 도구로: `NPC_EFFORT` 없이 `python tools/test_npc.py fixtures/npc_memory/*.json` → 3개 OK, 모두 20초 안.
- Claude Code가 Studio MCP로(키가 없어 요약은 실패하는 게 정상):
  - [ ] spec 모두 PASS, 오류 0
  - [ ] 요약 실패 `warn`에 상태·걸린 초가 있고 키·본문이 없음
  - [ ] 두 번째 판 로비에서 이미 투표했으면 투표 창이 뜨지 않음, 첫 판은 그대로
  - [ ] 웨이브 1 큰 글자가 사라진 뒤 대화창이 뜸
- 사람이 publish 뒤 실제 서버에서: 결과 화면에 "요약 실패"가 아니고, 다음 Day에 NPC가 지난 판을 언급함.
