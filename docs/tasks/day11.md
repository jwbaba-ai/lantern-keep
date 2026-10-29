# Day 11 작업 지시 — 맵 꾸미기 (Studio 기본 기능만)

먼저 AGENTS.md와 `docs/devlog/` 최근 기록(day10 결과)을 읽는다. day10 커밋·push가 끝난 뒤에 시작한다.

목표: 데모 영상에서 "회색 블록 시험 맵"이 아니라 **밤의 성채를 등불 하나가 지키는 장면**으로 보이게 한다. 게임 규칙·좌표·밸런스는 바꾸지 않는다. 항목마다 커밋한다.

## 공통 규칙
- **외부 에셋 금지**: Toolbox 모델, 남이 만든 메시·텍스처·사운드의 `rbxassetid`를 새로 넣지 않는다.
  - 쓸 수 있는 것: Part·WedgePart·CylinderMesh 같은 기본 도형, `Enum.Material`, Terrain, Lighting·Atmosphere, PointLight·SpotLight, ParticleEmitter·Fire(기본 텍스처).
  - 해커톤 규칙과 `docs/ORIGINS.md` 때문이다.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 게임 동작에 쓰는 이름과 좌표는 **그대로** 둔다: `Map/Lantern`, `Map/Gates/<lane>`, `Map/Spawns/<lane>`, `Map/Lanes/<lane>/1..3`, `GATE_DISTANCE=60`, `SPAWN_DISTANCE=210`.
  - `GateHighlight`는 성문 파트의 `Transparency`를 바꿔 깜빡이므로 성문은 계속 파트 하나여야 한다.
- 장식은 **새 폴더 `workspace.Map.Decor`** 아래에만 만든다.
  - 맵이 이미 저장된 place에서도 돌아야 한다. `MapBuilder`는 `workspace.Map`이 있으면 새로 만들지 않기 때문이다.
  - `Decor`가 이미 있으면 다시 만들지 않는다(멱등).
- 휴대폰 성능: 장식 파트 합계 **400개 이하**, ParticleEmitter 합계 **8개 이하**, 장식 광원 **12개 이하**.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.

## 1. 새 모듈 `src/server/World/MapDecor.luau` + `MapBuilder` 끝에서 호출
- `MapBuilder.server.luau`의 `map:SetAttribute("Ready", true)` **바로 앞**에서 `MapDecor.build(map)`를 `pcall`로 부른다.
  - 실패하면 `warn("[Map] decor failed: ...")`만 남기고 Ready는 그대로 켠다. 맵 장식 때문에 경기가 멈추면 안 된다.
- 끝나면 `print("[Map] decor parts=N lights=N particles=N")`를 남긴다.

## 2. 바닥과 성벽
- **바닥**: `workspace.Baseplate`가 있으면 Material `Cobblestone`, 색 어두운 회갈색으로 바꾼다.
  - 크기·위치·충돌은 그대로 둔다.
  - 성채 안쪽(반지름 55)에는 `Slate` 원판(Cylinder 파트, 높이 0.2, CanCollide=false)을 깔아 광장처럼 보이게 한다.
- **성벽**: 반지름 60의 사각 성벽으로, 네 성문 자리는 비워 둔다.
  - 재질 `Brick` 또는 `Slate`, 높이 14, 두께 4.
  - 성문 양옆에 탑(높이 22 원기둥 또는 사각 기둥)을 하나씩 세우고, 꼭대기에 흉벽(톱니 모양 작은 블록)을 올린다.
  - 성벽은 `CanCollide=true`다.
  - **성문 구멍은 성문 파트 폭(16)보다 4 이상 넓게** 비워서 적·플레이어·지원대 이동을 막지 않는다.
- **성문**: 기존 성문 파트의 재질을 `WoodPlanks`로 바꾼다. 방향 색(파랑·빨강·노랑·초록)은 유지한다.
  - 문틀(나무 기둥 2개 + 위 가로대)은 `Decor`에 따로 만든다.
- **길**: 각 성문에서 스폰 패드까지 폭 10의 흙길(`Ground` 또는 `Sand` 재질 얇은 파트, CanCollide=false)을 깐다.
- **바깥**: 성 밖 길 양옆에 바위(`Rock`)와 죽은 나무(원기둥 줄기 + 가지)를 띄엄띄엄 둔다.
  - 길 위(웨이포인트 직선 양옆 6 이내)에는 두지 않는다.
  - Terrain은 쓰지 않는다. 휴대폰 메모리를 아끼고, 적 이동과 충돌을 예측할 수 있게 하기 위해서다.

## 3. 등불과 조명
- **등불**: 기존 `Lantern` 파트는 그대로 둔다(체력 속성·위치·크기·Neon).
  - `Decor`에 받침대(돌 원기둥 3단)와 꼭대기 장식(금속 고리 + 위쪽에 `Fire` 하나)을 붙인다.
  - 기존 `PointLight` 밝기·범위는 바꾸지 않는다.
  - 등불 체력이 낮아지면 `Fire.Size`가 작아진다(Health 속성 변화에 연결, 최소 2).
- **분위기**: `Lighting` 값은 서버에서 한 번 정한다.
  - `ClockTime = 19.5`(해 질 녘), `Brightness = 1.5`, `Ambient`·`OutdoorAmbient`는 어두운 남색.
  - `Atmosphere`를 하나 만든다: Density 0.3, 색 어두운 보라 계열.
  - **휴대폰 화면에서 적·플레이어가 잘 보이는 밝기여야 한다.** 너무 어두우면 밝기를 올린다.
- **성벽 횃불**: 탑마다 `Fire` 또는 `PointLight`(주황, 범위 18) 하나씩, 합계 8개 이하로 둔다.

## 4. 이벤트 효과와 충돌 확인 — `src/server/Director/EventEffects.luau`
- `Atmosphere`가 있으면 Roblox는 `Lighting.FogStart/FogEnd`를 무시한다. 그대로 두면 `fog` 이벤트가 화면에서 사라진다.
- 고칠 것: `fog` 이벤트 동안 `Atmosphere.Density`를 0.3에서 0.65로 올리고, 끝나면 되돌린다(기존 save/restore 방식과 같게).
  - `Atmosphere`가 없으면 지금처럼 Fog 값을 쓴다.
- `blood_moon`(Ambient 빨강)도 새 어두운 Ambient 위에서 보이는지 확인한다. 약하면 `OutdoorAmbient`도 같이 바꾸고 되돌린다.
- spec(순수 함수로 뺄 수 있으면): "Atmosphere 있음 + fog → Density 0.65, 종료 → 0.3".

## 5. 기록
- `docs/ORIGINS.md`에 "맵 장식(MapDecor): 기본 도형·재질·조명만 사용, 신규"를 한 줄 추가한다.
- `docs/GAME_DESIGN.md` 맵 절에 성벽·길·조명 설명을 짧게 추가한다.
- `docs/devlog/2026-11-05.md` 끝에 "day11" 절로 한 일과 파트·광원·파티클 수를 적는다.
- 커밋한 뒤 `git push`(원격: origin/main)한다. push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것
Claude Code가 Studio MCP로 확인한다.
- [ ] spec 모두 PASS
- [ ] `[Map] decor ...` 로그: 파트 400 이하, 광원 12 이하, 파티클 8 이하. 오류·경고 없음
- [ ] 웨이브 1~3 정상 진행
  - 네 성문 모두 적이 성벽에 막히지 않고 등불까지 옴(`arrived`/`killed` 정상, 시간 초과 없음)
  - solo 지원대도 각 성문 목표 지점에 도착
- [ ] 성문 깜빡임(GateHighlight)이 보임
- [ ] fog 이벤트 때 Atmosphere.Density가 0.65였다가 돌아감
- [ ] 스크린샷 3장(성채 위에서 보기, 성문 앞, 휴대폰 세로 410×890)을 devlog에 첨부 경로로 기록

사람이 실제 서버에서 확인한다.
- [ ] 휴대폰에서 끊김 없이 플레이되고, 적·플레이어가 잘 보임
