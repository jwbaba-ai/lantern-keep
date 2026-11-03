# Day 14d 수정 — 원통 방향, 장비 위치, 카메라 흔들림 해제 (아주 짧은 작업, 마지막 수정)

day14c 리뷰 결과다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/Combat/CombatService.luau`(효과 함수만), `src/server/World/Gear.luau`, `src/client/LanternBar.client.luau`, devlog.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] 원통이 막대로 보임 — Roblox Cylinder 규칙
- Roblox `Cylinder`는 **길이가 `Size.X`(파트의 X축 방향)이고 지름이 `min(Size.Y, Size.Z)`**다. 지금 `Size = (지름, 두께, 지름)`으로 쓴 곳은 모두 지름 0.2 안팎의 가는 막대가 된다.
- 납작한 원판은 `Size = (두께, 지름, 지름)`이고, 원판의 면이 바라보는 방향이 파트의 X축이다.
- 고칠 곳:
  - `CombatService.luau` `arcanistFx`의 `BlastRing`, `ringFx`: 바닥에 눕힌 원판이다. `Size = (0.2, d, d)`, `CFrame = CFrame.new(위치) * CFrame.Angles(0, 0, math.rad(90))`(X축이 위로). Tween은 `Size = (0.2, 끝 지름, 끝 지름)`이다. 위치를 올리는 Tween은 `Position` 대신 `CFrame`(같은 회전 + 높이)을 쓴다.
  - `Gear.luau` `Helm`, `HatBrim`: 머리 위에 눕힌 원판이다. `Size = (두께, 지름, 지름)`, `Offset`에 `* CFrame.Angles(0, 0, math.rad(90))`을 더한다.
  - `Gear.luau` `Shield`, `ShieldRim`: 왼손 바깥(손의 -X 쪽)을 보는 원판이다. `Size = (두께, 지름, 지름)`, **회전은 지운다**(X축이 이미 바깥을 본다). 테두리 지름 1.8은 방패 1.6보다 크고 두께는 얇게 둔다.
  - `Gear.luau` `Quiver`: 세운 통이다. `Size = (1.8, 0.6, 0.6)`, `Offset`에 `* CFrame.Angles(0, 0, math.rad(90))`을 더한다.

## 2. [중간] 장비 위치
- 몸의 **앞은 -Z, 뒤는 +Z**다(망토·두건은 맞게 +Z에 있다).
  - `Quiver`, `Fletch`: Z를 `-(tz / 2 + 0.3)`에서 `tz / 2 + 0.3`으로(등 뒤).
- 지팡이가 손 아래로 뻗어 땅에 박힌다. 손에서 **위로** 뻗게 한다.
  - cleric(`Staff` 길이 3.4): 중심 `CFrame.new(0, 1.0, 0)`, 끝 공 `CFrame.new(0, 2.9, 0)`.
  - arcanist(`Staff` 길이 3): 중심 `CFrame.new(0, 0.9, 0)`, 끝 공 `CFrame.new(0, 2.6, 0)`.
  - 검은 지금처럼 아래로 둔다.

## 3. [중간] 카메라 흔들림이 해제되지 않음 — `LanternBar.client.luau`
- `RunService:BindToRenderStep`은 연결 객체를 돌려주지 않는다(nil). 그래서 `shakeConn:Disconnect()`가 불리지 않고 흔들림 함수가 매 프레임 계속 돈다.
- 고칠 것: `shakeConn`을 지우고, `endShake`에서 `pcall(RunService.UnbindFromRenderStep, RunService, "LanternDamageShake")`로 해제한다. `shakeCamera`는 묶기 전에 `endShake()`를 먼저 부르는 지금 순서를 지킨다.

## 마무리
- devlog에 "day14d" 절로 한 줄씩 적고 커밋한 뒤 `git push`(원격: origin/main)한다.
