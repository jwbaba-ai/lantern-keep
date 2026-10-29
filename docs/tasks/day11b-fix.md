# Day 11b 작업 지시 — day11 Studio 확인에서 나온 수정 (짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day11)" 표와 `docs/devlog/shots/day11/04_cylindermesh_probe.jpg`를 본다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/World/MapDecor.luau`, `src/server/Director/EventEffects.spec.luau`, `src/server/Enemies/EnemyFactory.luau`(3번의 이름표 두 줄만), devlog. 그 밖은 고치지 않는다.
- 게임 동작 이름·좌표·충돌 크기 규칙(day11.md 공통 규칙)은 그대로 지킨다. 외부 에셋 금지도 그대로다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- 참고: 이번 오류도 lune 하네스로는 잡히지 않는다(그림 모양 문제와 float32 정밀도 문제).

## 1. [높음] 장식 원기둥이 모두 잘못된 모양으로 그려짐 — `MapDecor.makeCylinder`
- Studio 측정: `CylinderMesh`는 **높이 = Size.Y, 지름 = min(Size.X, Size.Z)**로 그린다(세로 축이 Y).
  - 지금 `p.Size = Vector3.new(height, diameter, diameter)`라서 축이 바뀌었다.
  - Plaza는 바닥 원판이 아니라 지름 0.2·높이 110 막대(등불 위 흰 선)가 됐다.
  - LanternBase_1~3, LanternRing, TowerCap은 가는 막대가 됐다.
  - Tower는 지름 6·높이 6 짧은 원통이 공중(y 8~14)에 떠 있다.
  - DeadTree 줄기는 2×2 짧은 원통이 됐다.
- 고칠 것: `p.Size = Vector3.new(diameter, height, diameter)`로 바꾼다. 다른 원기둥 코드는 이미 (지름, 높이) 순서로 부르므로 이 한 줄이면 된다.
  - 바꾼 뒤 위치를 다시 확인한다: Tower(높이 22, y=11)는 바닥 0~22, TowerCap(y=22.5)은 탑 꼭대기에 얹힌다. LanternBase는 0~3 높이로 쌓인다.
  - 탑의 충돌 상자는 6×22×6이 된다. 성문 구멍(반폭 10)과 탑 위치(성문 중심에서 14, 반지름 3 → 11~17)가 겹치지 않으니 이동에는 영향이 없다. 그래도 Studio 확인 항목에 넣었다.
- 주석 "정사각형에만 쓴다"를 "Size = (지름, 높이, 지름). CylinderMesh 세로 축은 Y"로 바꾼다.

## 2. [중간] EventEffects.spec `fog_round_trip` FAIL — 허용 오차
- 원인: `Atmosphere.Density`는 float32라 0.65를 넣어도 0.64999998로 읽힌다. `close()`의 허용 오차 1e-9보다 크다. 게임 동작은 정상이다.
- 고칠 것: `EventEffects.spec.luau`의 `close()` 허용 오차를 `1e-4`로 넓힌다. 다른 검사는 바꾸지 않는다.

## 3. [낮음] 어두운 조명에서 적이 잘 안 보임 — 이름표 외곽선, 밝기 조금 올리기
- Studio 확인: 적 몸체는 어두운 성문 앞에서 대비가 낮고, fog 중에는 성채 바깥이 꽤 어둡다. 적 이름표는 흰 글자에 외곽선이 없다.
- 고칠 것:
  - `EnemyFactory.luau` 이름표 `label`에 `TextStrokeTransparency = 0`, `TextStrokeColor3 = Color3.new(0, 0, 0)`을 넣는다. 이름표 크기·위치·글자는 바꾸지 않는다.
  - `MapDecor`의 `Lighting.OutdoorAmbient`를 `(40,45,70)`에서 `(70,75,105)`로 올린다. `Ambient`는 그대로 둔다(blood_moon 빨강이 잘 보이게).
  - Atmosphere Density 0.3과 fog 0.65는 그대로 둔다.

## 마무리
- devlog에 "day11b" 절로 한 일과 바뀐 값을 적고 커밋한 뒤 `git push`(원격: origin/main)한다. push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS(EventEffects 5/5 포함)
- [ ] `[Map] decor ...` 로그 수가 day11과 같음(parts=113 lights=8 particles=1), 오류·경고 없음
- [ ] 원기둥 모양
  - Plaza: 바닥에 깔린 지름 110 얇은 원판
  - Tower: 바닥부터 높이 22 세로 기둥, TowerCap이 꼭대기에 얹힘
  - LanternBase: 12/9/6 지름 3단 받침대, LanternRing은 등불 위 작은 원판
  - DeadTree: 높이 10 세로 줄기
- [ ] 웨이브 1~3에서 적·solo 봇이 성문을 지나 등불까지 옴(멈춘 적 0, `[Support] unstuck` 없음)
- [ ] 적 이름표에 검은 외곽선, OutdoorAmbient (70,75,105), blood_moon 적용·복원 정상
- [ ] 스크린샷 2장(위에서 보기, 등불 받침대)

사람이 실제 서버에서 확인한다.
- [ ] 휴대폰에서 성채 모양(탑·받침대·광장)이 제대로 보이고, 적이 어두운 곳에서도 보임
