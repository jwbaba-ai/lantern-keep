# Day 7 작업 지시 (2026-11-02) — "데모 녹화 전 다듬기"

먼저 AGENTS.md, 가장 최근 `docs/devlog/` 파일(day6 결과와 Claude Code 리뷰)을 읽는다.
오늘 목표는 **새 기능 없이, 데모 화면에서 눈에 띄는 어색함만 없애는 것**이다. 작은 수정만 하고 구조는 바꾸지 않는다.

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다.
- `schemas/`, 생성 Luau 스키마 2개, 두 `prompt.txt`, `src/shared/Config.luau`, `src/shared/AssetIds.luau`는 고치지 않는다(AssetIds는 사람이 ID를 채우는 중).
- 환경 설정·패키지 설치 명령은 금지한다. 30초 넘게 멈추는 명령은 중단하고 보고한다.

## 0단계: day6 확인 결과 반영
day6 devlog의 체크리스트에 사람이 남긴 메모가 있으면 먼저 고치고 커밋한다.

## 1단계: Claude Code 리뷰·테스트 수정 (항목마다 커밋)
1. **[높음] 로비 배너에 "곧 시작합니다" 대신 웨이브 1 이름이 나옴** — `src/server/Director/DirectorState.luau`
   - 원인: 로비 고정 문구까지 `filterOrFallback`에 넣는다. 로비 시작 시점에는 플레이어가 0명이라 필터가 실패하고, 웨이브 1 대체 문구로 바뀐다.
   - 고칠 것: `phase == "lobby"`이면 결과 화면처럼 고정 문구를 필터 없이 그대로 쓴다. 고정 문구는 서버 코드에 적힌 글자이고 AI가 만든 글이 아니다.
   - 확인: `DirectorState.spec`에 "플레이어 0명 + lobby → display_name이 `곧 시작합니다`" 1건 추가.
2. **[낮음] 결과 화면 중에도 웨이브 배너가 보임** — `src/client/WaveBanner.client.luau`: `phase == "result"`이면 배너 전체를 숨긴다.
3. **[낮음] 이벤트 그림이 없어도 그 자리가 남음** — `WaveBanner`의 이벤트 그림(`EventArt`)은 이미지가 없으면 `Visible=false`로 두어 배너 높이가 늘어나지 않게 한다. 말풍선·결과 화면의 초상화도 같은 규칙을 따르는지 확인한다.
4. **[낮음] 다음 판 시작 시 플레이어 체력이 그대로 이어짐** — `DirectorService`의 `resetForNextMatch`에서 살아 있는 플레이어의 체력을 직업 최대 체력으로 채운다.

## 2단계: 마무리
- `docs/devlog/2026-11-02.md`에 한 일과 사람이 확인할 체크리스트를 기록한 뒤 커밋한다.
- 커밋 후 `git push`한다(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 사람이 Studio에서 확인할 것 (devlog에 체크리스트로 복사)
- [ ] Play 직후 로비 배너가 "곧 시작합니다 · 시작까지 N초"
- [ ] 결과 화면이 떠 있을 때 웨이브 배너가 보이지 않음
- [ ] 이벤트 그림이 없을 때 배너에 빈 자리가 없음
- [ ] 2판째 시작 시 플레이어 체력이 가득 참
- [ ] 명령줄 `DirectorState.spec` 모두 PASS
