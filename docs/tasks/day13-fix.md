# Day 13 수정 — 숫자가 든 이름의 AI 대사가 버려짐 (아주 짧은 작업)

새 기능은 넣지 않는다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/NpcMemory/NpcService.server.luau`, `src/server/NpcMemory/NpcSpeech.luau`, `src/server/NpcMemory/NpcMemory.spec.luau`, devlog.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] `NpcService.server.luau` `say`의 숫자 검사 지우기
- 원인: `resolveLine`이 이름을 넣은 **뒤의** 글자를 `say`에서 `hasStrayNumber`로 다시 검사한다. 이름이 `player7`인 플레이어는 "P1님" 대사가 "player7님"이 되어 숫자 때문에 기본 대사로 바뀐다.
- 고칠 것: `say`의 "숫자 안전망" 주석과 `if` 3줄을 지운다. 이름을 넣기 전 원문은 `resolveLine`이 이미 검사한다.

## 2. [낮음] `NpcSpeech.luau` 주석 자리
- `hasStrayNumber`가 `resolveLine` 설명 주석과 함수 사이에 끼어 있다. 함수를 그 설명 주석 위로 옮긴다. 동작은 바꾸지 않는다.

## 3. spec 추가 — `NpcMemory.spec.luau`
- `resolveLine("P1님 함께해요!", "기본 대사", okFilter, { P1 = "player7" }, 1)`이 `"player7님 함께해요!"`, `true`를 돌려주는지 확인한다.

## 마무리
- devlog의 day13 절에 한 줄 적고 커밋한 뒤 `git push`(원격: origin/main)한다.
