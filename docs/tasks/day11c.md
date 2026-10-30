# Day 11c 작업 지시 — 영상에 보이는 외형 다듬기 (Studio 기본 기능만)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day11b)" 표와 `docs/devlog/shots/day11b/02_lantern_pedestal.jpg`를 본다.
목표: 데모 영상에서 동료 NPC와 적이 "흰 블록·갈색 블록"이 아니라 캐릭터로 보이게 한다. 게임 규칙·밸런스·판정은 바꾸지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/World/MapDecor.luau`, `src/server/NpcMemory/NpcService.server.luau`(NPC 몸체 만드는 부분만), `src/server/Enemies/EnemyFactory.luau`, 필요하면 새 모듈 `src/server/World/Figures.luau`, `docs/ORIGINS.md`, `docs/GAME_DESIGN.md`, devlog. 그 밖은 고치지 않는다.
- **외부 에셋 금지**: Part·WedgePart·기본 Mesh·`Enum.Material`·색만 쓴다. `rbxassetid`를 새로 넣지 않는다.
- 판정에 쓰는 파트는 **지금 그대로 하나**다. 새로 붙이는 장식 파트는 판정에 끼면 안 된다.
  - 적: `workspace.Enemies`의 직계 자식은 지금처럼 몸체 파트 하나다. `EnemyCounter`·`CombatService`가 직계 자식 BasePart를 적으로 센다. 장식은 **몸체의 자식**으로 넣는다.
  - NPC: `Map/Npcs/Bram`, `Map/Npcs/Mira` 파트 이름·위치 기준은 그대로다. `NpcBubble`이 이 파트를 `Adornee`로 쓴다. 장식은 그 파트의 자식으로 넣는다.
- 모든 장식 파트: `Anchored=false`, `CanCollide=false`, `CanQuery=false`, `CanTouch=false`, `Massless=true`, `WeldConstraint`로 몸체에 붙인다.
- 성능: 적 1마리당 장식 **3개 이하**, NPC 1명당 **8개 이하**. ParticleEmitter·광원은 새로 넣지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.

## 1. [높음] 광장 바닥이 등불 빛에 하얗게 날아감 — `MapDecor.buildPlaza`
- Studio 사진: 등불 가까이에서 `Plaza`(Slate, Medium stone grey)가 거의 흰색으로 보인다.
- 고칠 것: `Plaza` 색을 `Color3.fromRGB(78, 74, 70)`(어두운 회갈색)로 바꾼다. 재질·크기·위치는 그대로 둔다.
  - 받침대(`LanternBase_*`, Dark stone grey)와 구분되는지 사진으로 확인한다. 구분이 안 되면 받침대는 그대로 두고 Plaza 색만 조정한다.

## 2. [높음] 동료 NPC가 흰 블록 — `NpcService` 몸체 생성부
- 지금: 2×5×2 파트 하나(Bram Medium stone grey, Mira White).
- 고칠 것: 기존 몸체 파트는 **투명하지 않은 몸통**으로 남기고, 자식 장식을 붙여 사람 모양으로 만든다.
  - 공통: 머리(1.6 크기 공 또는 블록, 살색 계열), 다리 2개, 팔 2개.
  - **Bram**(노장 대장): 몸통 `Dark stone grey` Metal 갑옷, 어깨 보호대 2개, 오른손에 검(얇은 긴 파트).
  - **Mira**(견습 치유사): 몸통 흰색 SmoothPlastic 로브, 초록 띠 또는 망토, 왼손에 지팡이(가는 원기둥 + 끝에 초록 작은 공).
  - 두 NPC는 등불을 바라보게 돌린다(`CFrame.lookAt`, 수평만).
- 이름표 겹침 줄이기: `offset`을 Bram `(12, 0, 8)`, Mira `(-12, 0, 8)`로 넓히고, 이름표 크기를 200×40에서 **160×32**로 줄인다. 글자 외곽선(`TextStrokeTransparency = 0`)을 넣는다.
- 몸체 파트가 이미 있으면 다시 만들지 않는 지금의 방식은 그대로 둔다.

## 3. [중간] 적이 색만 다른 블록 — `EnemyFactory.spawn`
- 고칠 것: 몸체 파트 위에 종류별 실루엣을 붙인다(몸체 크기 기준 비율로. 정예 `sizeMult`일 때도 맞게).
  - 공통: 머리 블록 1개 + 빛나는 눈 1개(얇은 `Neon` 가로 막대, 빨강).
  - Brute: 공통 대신 머리 + 넓은 어깨 블록 1개 + 눈.
  - Archer: 머리 + 눈 + 등에 활(얇은 휘어진 대신 세로 막대 1개면 된다).
  - Shaman: 머리 + 눈 + 머리 위 뿔 또는 깃 장식 1개(보라).
  - Runner·Grunt: 머리 + 눈(+ Runner는 앞으로 기운 머리).
- **이동 방식 바꾸기**: 지금 트윈은 `{ Position = ... }`다. `Position`을 바꾸면 용접한 장식이 따라오지 않는다.
  - `{ CFrame = CFrame.lookAt(목표, 목표 + 수평 진행 방향) }`으로 바꾼다. 진행 방향은 (목표 − 현재)의 Y를 0으로 한 값이다. 길이가 0이면 지금 방향을 유지한다.
  - 적이 진행 방향을 바라보게 되므로 눈이 앞쪽(-Z 면)에 오게 붙인다.
  - 이동 속도·경로·도착 판정은 바꾸지 않는다.
- 몸체의 `Health`·`EnemyType`·`Lane` 속성, 이름표, 크기, 색은 그대로 둔다.

## 4. 기록
- `docs/ORIGINS.md`의 MapDecor 줄에 "NPC·적 외형(기본 파트), 신규"를 덧붙인다.
- `docs/GAME_DESIGN.md` 적·NPC 절에 외형 한 줄씩 추가한다.
- devlog에 "day11c" 절로 한 일과 파트 수(NPC 1명당, 적 종류별)를 적고 커밋한 뒤 `git push`(원격: origin/main)한다. push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS
- [ ] `Map/Npcs/Bram`·`Mira`가 사람 모양으로 보이고 등불을 바라봄. 장식 파트 수 8개 이하. 기본 대사 말풍선·AI 대화창 "…" 표시가 그대로 나옴
- [ ] 기본 카메라에서 Bram·Mira 이름표가 서로·등불 빛기둥과 겹치지 않음
- [ ] 웨이브 1~3
  - 적 5종 모두 머리·눈이 몸체를 따라 움직이고 진행 방향을 바라봄(장식이 출발점에 남지 않음)
  - `workspace.Enemies` 직계 자식 수 = 살아 있는 적 수, 적 카운터 정상
  - ranger 사격·arcanist 범위 피해·지원대 공격이 지금처럼 적에게 맞음(`CanQuery=false` 장식에 막히지 않음)
  - 멈춘 적 0, 시간 초과 없음, 오류·경고 없음
- [ ] 광장 바닥이 등불 옆에서 흰색으로 날아가지 않음
- [ ] 스크린샷 3장(등불과 NPC 둘, 성문 앞 적 무리, 위에서 보기)을 `docs/devlog/shots/day11c/`에

사람이 실제 서버에서 확인한다.
- [ ] 휴대폰에서 끊김 없음, NPC·적이 캐릭터로 보임
