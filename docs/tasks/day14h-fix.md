# Day 14h 수정 — 대화창이 큰 글자와 겹침, 건너뛰기 버튼이 대화창 뒤에 가려짐 (아주 짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day14f~g)" 표 5번, 11번과 원인 분석을 본다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/client/WaveStartText.client.luau`, `src/client/NpcBubble.client.luau`, `src/client/SkipWait.client.luau`, devlog.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [중간] 웨이브 1 대화창이 큰 글자와 겹침
- 원인: 투표 알림 때문에 큰 글자를 미루면, 대사가 도착하는 순간에는 `WaveTextUntil`이 아직 없거나 지난 값이다. 그래서 대화창이 큰 글자보다 0.3초만 늦게 떠서 겹친다.
- 고칠 것 (둘 다 한다):
  - `WaveStartText`의 `deferShow`: 미룰 때(`delay > 0`) 바로 `player:SetAttribute("WaveTextUntil", 지금 서버 시각 + delay + 2.1)`을 넣는다. 미룬 뒤 실제로 보이면 `showLines`가 지금처럼 다시 넣는다. phase가 바뀌어 보이지 않게 되면 그대로 둔다(늦어도 2.1초 뒤 지난 값이 된다).
  - `NpcBubble`: 미룬 뒤 `showDialog`를 부르기 직전에 `WaveTextUntil`을 다시 읽고, 아직 뒤면 남은 시간 + 0.1초만큼 한 번 더 미룬다(한 번만).

## 2. [중간] 휴대폰에서 건너뛰기 버튼이 NPC 대화창 뒤에 가려짐 — `SkipWait.client.luau`
- 측정: 842×390 화면에서 버튼(x 555~632, y 178~202)이 대화창(y 110~212) 안에 들어가 가려진다. 점프 버튼은 x 747~817, 쿨다운 막대는 y 249~252다.
- 고칠 것:
  - 버튼 위치를 화면 아래쪽, 점프 버튼 왼쪽으로 옮긴다: `OFFSET_X = -115`, `OFFSET_Y = -12`(AnchorPoint (1, 1) 그대로).
  - `gui.DisplayOrder = 5`로 대화창보다 위에 그린다. 직업 선택 창(10)보다는 낮게 둔다.

## 마무리
- devlog에 "day14h" 절로 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] 오류 0, spec PASS, 스크립트 복제 0
- [ ] 투표 알림 뒤 웨이브 1: 큰 글자가 사라진 뒤 대화창이 뜸
- [ ] 842×390에서 건너뛰기 버튼이 대화창·점프 버튼·쿨다운 막대·결과 창·Tool 칸과 겹치지 않음(스크린샷)
