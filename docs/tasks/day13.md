# Day 13 작업 지시 — 휴대폰 3 Day 플레이에서 나온 문제와 화면 다듬기

먼저 AGENTS.md와 `docs/devlog/2026-11-05.md` 끝부분(day12b)을 읽는다. 사람(Babazz)이 day12b를 publish해 휴대폰으로 Day 3까지 플레이했다(2026-10-31). 게임 규칙·밸런스는 바꾸지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일은 각 항목에 적은 것과 devlog, `docs/GAME_DESIGN.md`뿐이다.
- `src/server/NpcMemory/prompt.txt`는 1번에 한해 사람이 수정을 승인했다(2026-10-31). 디렉터 `prompt.txt`, `schemas/`, `src/shared/`는 고치지 않는다.
- 외부 에셋 금지. Part·기본 재질·색만 쓴다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] NPC 대사에 뜻 모를 숫자 — `NpcMemory/prompt.txt`, `NpcSpeech.luau`, `NpcService.server.luau`, `NpcMemory.spec.luau`
- 실제 대사: "마지막까지 100 피해 힘내주세요!", "마지막 파도, 280 힘처럼 함께해요!", "남문와 함께 승리하자!".
- 원인: 입력 요약의 `damage` 값을 모델이 그대로 말한다. 프롬프트에 금지 규칙이 없고, 코드에도 숫자 검사가 없다.
- 프롬프트 Rules에 추가한다.
  - `Never say damage, revive or death counts as numbers. Describe them in words (e.g. "가장 강하게 싸운", "두 번 일으켜 준"). The only digits allowed in a line are Day numbers and wave numbers ("Day 2", "3웨이브").`
  - `Write natural Korean with correct particles, for example 남문과, 북문을. Every line must make sense when read alone.`
- 코드 안전망(저장된 옛 대사도 걸러야 한다): `NpcSpeech.hasStrayNumber(text)`를 추가한다.
  - `Day%s*%d+`, `%d+%s*웨이브`, `웨이브%s*%d+`, `P%d+`를 지운 뒤 숫자가 남으면 true다.
  - `resolveLine`에서 `hasStrayNumber(line)`이면 기본 대사와 `false`를 돌려준다.
- `NpcMemory.spec.luau`에 시험을 추가한다: 위 두 숫자 대사는 기본 대사, "Day 2 북문부터", "3웨이브 승리", "P1님"은 통과.

## 2. [높음] 색깔 성문이 다가오는 적을 가림 — `World/MapBuilder.server.luau`, `World/GateHighlight.luau`, `World/MapDecor.luau`(`buildGateFrames`)
- 사진: 나무판 성문이 완전히 막혀 있어 적이 바로 앞에 올 때까지 안 보이고, 이름표 일부만 벽 뒤로 삐져나온다.
- 고칠 것: 성문을 **색이 비치는 철창문**으로 만든다.
  - `Gates/<lane>` 파트의 이름·크기·위치·충돌은 그대로 두고 기본 `Transparency`를 0.8로 한다. 성문 색 구분은 남는다.
  - `GateHighlight`: `BASE_TRANSPARENCY = 0.8`을 두고 `stop`과 깜빡임의 꺼짐 값이 0 대신 이 값을 쓰게 한다. 켜짐 값은 첫 성문 0.1, 나머지 0.35로 해서 깜빡임이 지금보다 잘 보이게 한다.
  - `buildGateFrames`: 성문마다 세로 쇠창살 5개(굵기 0.6, 높이 12, 간격 고르게)와 위쪽 가로대 1개를 Decor에 추가한다. `Metal`, 어두운 회색, `CanCollide=false`, `CanQuery=false`, `CanTouch=false`다. 동·서문은 축을 돌린다.
  - 창살은 적·투사체 판정에 끼면 안 된다.

## 3. [높음] 첫 화면에 창 3개가 겹치고 글자 순서가 뒤집힘 — `client/ClassPicker.client.luau`, `client/SupportVote.client.luau`, `client/ResultScreen.client.luau`, `client/WaveBanner.client.luau`
- 사진: 직업 선택 위에 배너와 투표 창이 겹쳐 글자를 읽을 수 없고, 제목 "Choose your class"가 창 맨 아래에 있다. 투표 창 제목과 결과 창 "Day 1 승리!"도 맨 아래다.
- 원인: `UIListLayout`의 기본 `SortOrder`가 `Name`이라 `LayoutOrder`가 무시된다.
- 고칠 것:
  - 네 파일의 `UIListLayout`에 `SortOrder = Enum.SortOrder.LayoutOrder`를 넣는다. 결과 창은 "Day N 승리!"가 맨 위에 오게, 배너는 웨이브 이름이 맨 위에 오게 `LayoutOrder`를 맞춘다. 고친 뒤 글자가 창 밖으로 나가지 않는지 확인한다.
  - `ClassPicker`: `gui.DisplayOrder = 10`으로 맨 위에 둔다. 글자를 한국어로 짧게 한다(파일 안 지역 표, `ClassCatalog`는 고치지 않는다). 제목 "직업을 고르세요", 버튼 "수호자 · 앞에서 막는 탱커", "궁수 · 멀리서 쏘는 원거리", "비전술사 · 범위 마법", "사제 · 치유와 부활".
  - `SupportVote`: 로비 투표 패널은 **직업을 고른 뒤에만** 보인다(`hasClass`가 false면 `frame.Visible = false`). 직업 전 배치 코드는 지운다.
  - `ResultScreen.client.luau:118` 문구를 `"다음은 Day %d (%d웨이브)"`로 바꾼다. "웨이브 5"가 5번째 웨이브처럼 읽힌다.

## 4. [중간] 지원대가 까만 실루엣이고 이름표가 겹침 — `Support/SupportSquad.luau` `buildModel`
- 사진: 지원대가 온통 검은색이라 적처럼 보이고, 함께 다니면 이름표가 "지원지원대"처럼 겹친다.
- 고칠 것:
  - 빈 `HumanoidDescription`에 색을 넣는다. 머리·팔·다리는 살색 (234,200,160), 몸통과 다리는 역할 색이다: guardian (70,110,170), ranger (60,140,80), cleric (235,235,225), arcanist (120,80,170). 파일 안 지역 표로 둔다.
  - 이름표 높이를 봇 번호에 따라 나눈다: `offset` Y = 4 + (번호 - 1) * 1.3. 번호는 봇 이름 끝 숫자에서 읽고, 못 읽으면 1이다.
  - 이름표 글자는 그대로 둔다.

## 5. [중간] NPC가 카메라를 가림 — `NpcMemory/NpcService.server.luau`
- 사진: 플레이어가 등불에서 태어날 때 Mira·Bram 몸이 화면 한쪽을 크게 막는다.
- 고칠 것: `offset`을 Bram `(18, 0, 14)`, Mira `(-18, 0, 14)`로 옮긴다. 다른 값은 그대로 둔다.

## 마무리
- `docs/GAME_DESIGN.md`에 성문 모양, 지원대 색, 대사 숫자 규칙을 짧게 적는다.
- devlog에 "day13" 절로 한 일과 바뀐 값을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS(새 숫자 시험 포함), 오류·경고 없음
- [ ] 저장된 옛 대사를 가정한 "100 피해" 대사가 기본 대사로 바뀌고 고지 줄이 없음. Day·웨이브 숫자 대사는 그대로 나옴
- [ ] 실제 모델 대사 표본에 Day·웨이브 외 숫자가 없음
- [ ] 성채 안에서 성문 너머로 오는 적이 사진에 보임. 깜빡임이 보이고 웨이브 시작 때 0.8로 돌아옴. 창살이 사격·범위 피해·지원대 공격을 막지 않음
- [ ] 첫 화면: 직업 창만 읽히고, 고른 뒤 투표 창이 위에서 아래 순서로 보임. 결과 창·배너 순서와 넘침 없음
- [ ] 지원대 색이 역할별로 보임, 이름표가 겹치지 않음, 적과 구분됨
- [ ] 기본 카메라에서 NPC가 화면을 크게 막지 않고, 대화창 "…" 표시가 그대로 나옴
- [ ] 웨이브 1~3 회귀: 멈춘 적 0, 시간 초과 없음
- [ ] 스크린샷을 `docs/devlog/shots/day13/`에

사람이 실제 서버에서 확인한다(publish 후 휴대폰).
- [ ] 첫 화면이 읽힘, 성문 너머 적이 보임, 대사가 자연스러움
