# Day 14e 수정 — 조준 외곽선이 안 나옴, 검·NPC 발이 바닥에 묻힘 (마지막 수정)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day14b~d)" 표 3, 19, 20번을 본다. 새 기능은 넣지 않는다. 항목마다 커밋한다. 이 수정이 끝나면 기능 동결이다.

## 공통 규칙
- 고칠 수 있는 파일: `src/client/TargetMarker.client.luau`, `src/server/World/Gear.luau`, `src/server/NpcMemory/NpcService.server.luau`, devlog.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] 조준 외곽선 — `TargetMarker.client.luau` 26줄
- `Enum.DepthMode.Occluded`는 없는 Enum이라 스크립트가 거기서 멈춘다.
- `Enum.HighlightDepthMode.Occluded`로 바꾼다. 이 한 줄만 고친다(Studio에서 이 값으로 외곽선이 그려지는 것을 확인했다).

## 2. [낮음] 검이 바닥을 뚫음 — `Gear.luau` guardian `Sword`
- 지금 길이 2.4가 손에서 아래로 뻗어 끝이 바닥 아래로 내려간다.
- `Sword` 크기를 `Vector3.new(0.22, 1.6, 0.22)`로, `Offset`을 `CFrame.new(0, -(hy / 2 + 0.75), 0)`으로 바꾼다. `SwordGuard`는 그대로 둔다.

## 3. [낮음] NPC 발이 바닥 아래 0.61 — `NpcService.server.luau`
- 지금은 발 높이를 투명 몸체 파트 바닥(`body.Position.Y - body.Size.Y / 2`)에 맞추는데, 이 값이 실제 바닥면보다 낮다.
- 고칠 것: `groundY`를 몸체 위치 위 5스터드에서 아래로 20스터드 `Workspace:Raycast`해서 정한다. 이때 `Npcs` 폴더는 제외한다(`RaycastParams` Exclude). 맞은 곳이 있으면 그 `Position.Y`를 쓰고, 없으면 지금 값을 쓴다.
- 사람 모델 BasePart의 `CanCollide=false`도 `PivotTo` **뒤에** 한 번 더 넣는다(지금 일부가 true로 남는다).

## 마무리
- devlog에 "day14e" 절로 한 줄씩 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] 오류 0, spec 모두 PASS
- [ ] 직업 Tool을 들면 노란 외곽선이 실제로 맞는 적에 그려지고, 대상이 바뀌면 옮겨 가고, Tool을 내리면 사라짐
- [ ] 검 끝·Bram·Mira 발이 바닥면 위에 있음, NPC 몸 부위 CanCollide false
