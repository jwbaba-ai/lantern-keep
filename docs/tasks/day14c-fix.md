# Day 14c — 죽은 몸체 정리 + 플레이 편의 + 연출 + 지원대·NPC 외형 (기능 동결 전 마지막)

먼저 AGENTS.md와 `docs/devlog/2026-11-05.md` 끝부분(day14b)을 읽는다. 게임 규칙, 적 체력·피해, 직업 수치(`ClassCatalog`)는 바꾸지 않는다. **번호마다 커밋한다.** 위 번호부터 한다. 시간이 모자라면 끝난 번호까지만 push하고 devlog에 멈춘 번호를 적는다.

## 공통 규칙
- 고칠 수 있는 파일은 각 항목에 적은 파일, 새 파일 `src/shared/AutoTarget.luau`(사람 승인됨, 이 파일만), devlog, `docs/GAME_DESIGN.md`뿐이다.
- 두 `prompt.txt`, `schemas/`, 그 밖의 `src/shared/` 파일은 고치지 않는다.
- **외부 에셋 금지**(소리·이미지·메시·카탈로그 액세서리·ParticleEmitter 포함). Part, WeldConstraint, Highlight, Tween, 기본 UI, 색만 쓴다.
- 새 RemoteEvent를 만들지 않는다.
- **효과용 파트는 모두** `Anchored`(또는 몸체에 용접), `CanCollide=false`, `CanQuery=false`, `CanTouch=false`, `Massless`(용접일 때)로 만든다. 사격 판정(`Workspace:Raycast`)을 막으면 안 된다.
- 효과 코드가 실패해도 전투와 경기는 멈추면 안 된다(`pcall` 또는 nil 검사).
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] 처치된 몸체가 0.15초 동안 살아 있는 적처럼 동작
day14b 뒤로 처치된 적은 0.15초 뒤에 지워진다. 그동안 `Workspace.Enemies`를 직접 도는 코드가 그 몸체를 산 적처럼 다룬다. `EnemyFactory.damage`는 `active`를 보므로 괜찮다.
- 판단 기준: `(body:GetAttribute("Health") or 0) <= 0`이면 죽은 몸체다. 파일마다 `isAlive(body)` 지역 함수를 하나 둬도 된다.
- 아래 다섯 곳의 `body:IsA("BasePart")` 검사에 이 조건을 더한다.
  1. `src/server/Combat/EnemyCounter.server.luau` 바깥 루프: 죽은 적이 근접·궁수 피해를 주지 않는다.
  2. 같은 파일의 Shaman 치유 루프 `other`: 죽은 적을 치유하지 않는다.
  3. `src/server/Support/SupportSquad.luau` `nearestEnemy`
  4. 같은 파일 `chosenEnemyPart`에서 `list`를 만드는 곳
  5. 같은 파일 `busiestLiveLane`의 개수 세기
- `src/server/Combat/CombatService.luau` `enemiesInRadius`에도 같은 조건을 넣는다.

## 2. [높음] 공격 효과 파트가 사격을 막음 — `CombatService.luau` `flash`
- 지금: `flash` 파트는 `CanQuery` 기본값이 true라 0.2초 동안 남아서 다른 궁수의 레이캐스트를 막을 수 있다.
- 고칠 것: `CanQuery=false`, `CanTouch=false`. 3번 항목에서 새로 만드는 효과도 같은 규칙을 따른다.

## 3. [높음] 공격하면 사거리 안의 적을 자동 조준
### 3-1. 새 파일 `src/shared/AutoTarget.luau` (순수 함수, 서버·클라이언트 공용)
- `AutoTarget.pick(classKey, rootPos, aim, candidates)` → 고른 후보 하나 또는 nil.
  - `candidates`: `{ { pos = Vector3, ref = any }, ... }`(살아 있는 적만 넣는다). `ClassCatalog`를 읽는다.
  - **ranger**: `rootPos`에서 `Range` 안의 후보만 본다. 조준 방향(`aim - rootPos`, 수평)과 이루는 각이 25° 안인 후보가 있으면 각이 가장 작은 후보다. 없으면 가장 가까운 후보다.
  - **arcanist**: `rootPos`에서 `Range` 안의 후보 중 `aim`에 가장 가까운 후보다.
  - **guardian**: `rootPos`에서 `Radius + 2` 안의 가장 가까운 후보다.
  - **cleric**: 언제나 nil(지금처럼 반경 판정).
  - 사거리 안에 후보가 없으면 nil. 길이 0인 방향은 nil 처리 없이 "가장 가까운 후보" 규칙으로 넘긴다.
### 3-2. 서버 적용 — `CombatService.luau`
- **플레이어 경로(`attackEvent.OnServerEvent`)에서만** 쓴다. 지원대는 지금 목표 선택을 그대로 쓴다.
- 살아 있는 적으로 후보를 만들고 `AutoTarget.pick`을 부른다. 고르면:
  - ranger·arcanist: `aim = 고른 적 위치`.
  - guardian: 고른 적 쪽 수평 방향을 `facing`으로 쓴다. `guardianAttack`이 선택 인자 `facingOverride`를 받게 하고, 없으면 지금처럼 `LookVector`를 쓴다.
- 고르지 못하면 지금 동작 그대로다. 쿨다운·피해·사거리 값은 바꾸지 않는다.
### 3-3. spec — `CombatService.spec.luau`에 추가
- ranger: 조준 방향 20°의 먼 적이 40°의 가까운 적보다 먼저 골라짐 / 25° 안이 없으면 가장 가까운 적 / 사거리 밖만 있으면 nil.
- arcanist: aim에 가장 가까운 적, 사거리 밖은 제외. guardian: `Radius + 2` 밖은 nil. cleric: nil.

## 4. [중간] 플레이 편의 — `src/client/Combat.client.luau`, 새 파일 `src/client/TargetMarker.client.luau`
- **누르고 있으면 연속 공격:** 직업 Tool의 `Activated`에서 반복을 시작하고 `Deactivated`·Tool 해제·캐릭터 사망 때 멈춘다. 간격은 `ClassCatalog[직업].Cooldown + 0.05`초다. 쿨다운 검사는 서버가 그대로 맡는다.
- **쿨다운 막대:** 화면 아래 가운데(핫바 바로 위)에 가로 120×6 픽셀 막대를 둔다. 공격을 보낼 때마다 0에서 꽉 찰 때까지 쿨다운 동안 채운다. `Active=false`, `UiScale`을 다른 창과 같게 쓴다. Tool을 들고 있을 때만 보인다.
- **조준 대상 표시(`TargetMarker`):** 직업 Tool을 들고 있을 때 0.1초마다 `AutoTarget.pick`(aim은 `mouse.Hit.Position`)으로 고른 적 하나에 클라이언트 전용 `Highlight`(외곽선 노란색, `FillTransparency=1`, `DepthMode=Occluded`)를 붙인다. 대상이 바뀌면 옮기고, 없거나 Tool을 내리면 지운다. 하나만 만든다. 클라이언트에서 살아 있는 적만 후보로 쓴다(`Health > 0`).
- **자동 장착:** `src/server/Combat/ClassService.server.luau`에서 직업이 정해진 뒤와 리스폰 때 직업 Tool을 `Humanoid:EquipTool`로 들게 한다. 이미 그렇게 되어 있으면 건너뛰고 devlog에 적는다.

## 5. [중간] 공격·처치 연출을 게임답게 — `CombatService.luau`, `src/client/HitFx.client.luau`, `src/client/WaveStartText.client.luau`, `src/client/LanternBar.client.luau`
- 서버 효과(모두에게 보임). `flash` 옆에 직업별 함수로 둔다. 피해 판정 시점과 값은 바꾸지 않는다(효과는 보여 주기만 한다).
  - **ranger:** 빛 기둥 대신 화살(노란 Neon 0.2×0.2×2)이 시작점에서 맞은 곳까지 날아간다. 시간은 거리/240초(최소 0.05초). 맞은 곳에 작은 노란 공이 0.15초 커지며 사라진다.
  - **arcanist:** 조준점 위 12스터드에서 보라 공(지름 1.5)이 0.15초 동안 떨어진 뒤, 보라 반투명 공이 지름 1에서 `Radius*2`까지 0.35초 동안 커지며 투명해진다. 바닥에 얇은 보라 고리(Cylinder)가 같이 퍼진다.
  - **guardian:** 바라보는 방향 ±40°에 주황 Neon 조각 3개를 부채꼴로 0.2초 보이고 사라지게 한다.
  - **cleric:** 치유받은 아군 발밑에 초록 고리가 3스터드 올라가며 0.5초 동안 사라진다. 근접 공격은 흰 고리가 `MeleeRadius`까지 0.2초 퍼진다.
  - 동시에 남아 있는 서버 효과 파트는 80개까지만 둔다. 넘으면 효과를 만들지 않는다. 지원대 공격도 같은 효과를 쓴다.
- 클라이언트 효과:
  - **처치 폭발(`HitFx`):** 적 체력이 0이 되면 그 적 색의 작은 조각 6개(0.4 정육면체)가 사방으로 튀며 0.4초 동안 사라진다. 몸체는 클라이언트에서만 0.15초 동안 크기를 줄인다. 피해 숫자 20개 제한과 별도로 조각은 동시에 60개까지만 둔다.
  - **웨이브 클리어 글자(`WaveStartText`):** phase가 `wave`에서 `intermission`으로 바뀌면 같은 자리에 금색 `웨이브 클리어!`를 같은 타이밍으로 보인다. `result`로 바뀔 때는 보이지 않는다(결과 화면이 따로 있다).
  - **등불 피해 흔들림(`LanternBar`):** 붉은 프레임과 함께 카메라를 0.2초 동안 0.3스터드 안으로 흔든다. 흔들림이 끝나면 카메라 위치를 건드리지 않는다(`Camera.CFrame`을 덮어쓰지 말고 `RenderStep`에서 오프셋만 더했다 뺀다). 진행 중에 또 맞으면 다시 시작한다.

## 6. [중간] 지원대·NPC 외형 상향 — 새 파일 `src/server/World/Gear.luau`, `SupportSquad.luau` `buildModel`, `src/server/NpcMemory/NpcService.server.luau`
- `Gear.luau`: R15 모델에 직업 장비를 붙이는 함수 `Gear.equip(model, kind)`. `Figures.attach(part, opts)`로 해당 신체 부위(`Head`, `UpperTorso`, `LeftHand`, `RightHand`)에 용접한다. 부위가 없으면 그 장비만 건너뛴다. `kind`별 장비(각 5~8개, Part만):
  - **guardian**: 금속 투구(머리 위 반구 + 앞 가리개), 어깨 보호대 2, 왼손 둥근 방패(Cylinder, 파란 테두리), 오른손 검.
  - **ranger**: 초록 두건(머리 뒤), 등의 화살통(Cylinder + 깃 3개), 왼손 활(가는 블록 3개로 휜 모양).
  - **cleric**: 흰 로브 자락(몸통 아래 앞뒤 판), 오른손 지팡이 + 끝 초록 Neon 공.
  - **arcanist**: 보라 고깔모자(Cylinder 챙 + 좁아지는 블록 2단), 오른손 지팡이 + 끝 보라 Neon 공.
  - **bram**: guardian 장비 + 등의 진홍 망토 + 회색 수염(머리 앞 아래 블록).
  - **mira**: cleric 장비 + 등의 초록 망토 + 머리 위 작은 화관(Neon 연두 공 3개).
- `SupportSquad.buildModel`: `HumanoidDescription` 색은 그대로 두고, 모델을 만든 뒤 **`CollisionGroup` 루프 전에** `Gear.equip(model, bot.role)`을 부른다. 이름표 높이는 그대로다(모자가 이름표에 닿으면 devlog에 적는다).
- NPC(`NpcService.server.luau`):
  - `Npcs/Bram`, `Npcs/Mira` 파트는 이름·위치·크기·`Anchored`를 그대로 두고 `Transparency=1`, `CanQuery=false`로 둔다(말풍선과 이름표가 이 파트를 쓴다). 기존 `buildCommon`·`buildBram`·`buildMira` 장식은 만들지 않는다.
  - 저장된 place에 예전 장식이 있을 수 있으니, 시작할 때 이미 있는 `Bram`·`Mira`의 자식 중 이름표(`Labels`가 만든 것) 말고 BasePart·Model은 지운다.
  - 같은 자리에 `Players:CreateHumanoidModelFromDescription`(R15)으로 사람 모델을 만들어 그 파트의 자식으로 둔다. 피부·옷 색은 Bram 회색 갑옷 / Mira 흰 로브. 모든 BasePart `Anchored=true`, `CanCollide=false`, `CanQuery=false`, `CanTouch=false`. Humanoid 이름 표시는 끈다. 등불을 바라보게 `PivotTo`하고 발이 지면에 닿게 높이를 맞춘다.
  - `Gear.equip(model, "bram"|"mira")`. 숨쉬기처럼 모델 전체를 2초 주기로 0.1스터드 위아래로 움직여도 된다(선택).
- 적 외형은 바꾸지 않는다.

## 마무리
- `docs/GAME_DESIGN.md`에 자동 조준 규칙(3-1), 편의 기능, 연출, 외형을 짧게 적는다.
- devlog에 "day14c" 절로 번호마다 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로, day14b 확인과 함께)
- [ ] spec 모두 PASS(새 AutoTarget 경우 포함), 오류·경고 없음. Studio에 `HitFx`, `WaveStartText`, `TargetMarker`가 하나씩
- [ ] 처치 직후 0.15초 동안 죽은 몸체가 때리지 않고, 지원대가 겨냥하지 않고, Shaman이 치유하지 않음
- [ ] 효과 파트가 사격을 막지 않음(궁수 둘이 같은 적을 연달아 쏴도 둘 다 피해)
- [ ] 자동 조준: 엉뚱한 곳을 눌러도 사거리 안 적을 맞힘, 사거리 밖만 있으면 지금처럼. 노란 외곽선이 실제로 맞는 적과 같음
- [ ] 누르고 있으면 쿨다운마다 공격, 떼면 멈춤. 쿨다운 막대가 맞게 참. 리스폰 뒤 Tool 자동 장착
- [ ] 직업별 효과·처치 폭발·웨이브 클리어 글자·흔들림이 보이고, 결과 화면에는 클리어 글자가 없음
- [ ] 끊김: 범위 마법 다수 타격 + 지원대 3명 공격 중 프레임 시간, 효과 파트 개수 상한 지킴
- [ ] 지원대 4직업·Bram·Mira 외형 스크린샷을 `docs/devlog/shots/day14c/`에. NPC 몸이 사격·이동을 막지 않음, 말풍선 위치 그대로
- [ ] day14b-fix.md 끝의 확인 항목 전부, 웨이브 1~3 회귀: 멈춘 적 0, 시간 초과 없음

사람이 실제 서버에서 확인한다(publish 후 휴대폰).
- [ ] 터치로 공격할 때 자동 조준·연속 공격이 편한지, 외곽선·막대가 화면을 가리지 않는지
- [ ] 연출이 과하거나 끊기지 않는지, 지원대·NPC가 보기 좋은지
