# Day 11d 작업 지시 — day11c Studio 확인에서 나온 수정 (짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day11c)" 표와 `docs/devlog/shots/day11c/01_lantern_npcs.jpg`를 본다. 새 기능은 넣지 않는다. 항목마다 커밋한다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/Enemies/EnemyFactory.luau`(이동 부분만), `src/server/World/MapDecor.luau`, devlog. 그 밖은 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.

## 1. [높음] 적이 성채 밖 첫 구간에서 뒤로 걸음 — `EnemyFactory.spawn` 이동 트윈
- Studio 측정: CFrame 트윈은 회전도 구간 전체에 걸쳐 천천히 보간한다.
  - 첫 구간(스폰 → 성문 150스터드)은 약 15초다. 그동안 north 적은 진행 반대(t=0)에서 옆(t=7)을 거쳐 성문에서야 앞을 본다.
  - 영상 녹화 장면(성문 밖 적 무리)에서 그대로 보인다.
- 고칠 것: 각 구간을 시작할 때 **먼저 방향을 즉시 맞추고**, 트윈은 위치만 옮긴다.
  - 구간 시작: `body.CFrame = Figures.faceFlatCFrame(body.Position, body.CFrame.LookVector, waypoints[i])`
  - 트윈 목표: `{ CFrame = CFrame.new(waypoints[i]) * body.CFrame.Rotation }` (방금 맞춘 회전 유지)
  - `Position` 트윈으로 되돌리지 않는다(용접 장식이 따라오지 않는다).
  - 속도·경로·도착 판정·`resolved`/Parent 확인은 그대로 둔다.

## 2. [중간] 등불 아래 흰 사각판 — place에 저장된 `Workspace.SpawnLocation`
- Studio 확인: place에 저장된 `SpawnLocation`(12×1×12, 밝은 회색 Plastic)이 `LanternBase_1`과 같은 자리에 겹쳐 하얗게 보인다(01번 사진).
- 고칠 것: `MapDecor`에서 `applyBaseplate`처럼 처리한다. place를 손으로 고치지 않아도 되게 한다.
  - `workspace:FindFirstChildOfClass("SpawnLocation")`이 있으면 `Transparency = 1`로 하고, 자식 `Decal`도 `Transparency = 1`로 한다.
  - 위치·크기·충돌·`Enabled` 등 스폰 동작에 쓰는 속성은 그대로 둔다. 플레이어가 지금처럼 그 자리에서 태어나야 한다.
  - 장식 파트 수(`parts=`)에는 세지 않는다(Decor 폴더 밖이다).

## 마무리
- devlog에 "day11d" 절로 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다. push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS, 오류·경고 없음
- [ ] 웨이브 1~3에서 north·south·east(있으면 west) 적이 **모든 구간**에서 진행 방향을 바라봄(1초 표본의 LookVector·진행 방향 내적 0.9 이상, 구간이 바뀐 직후 1초 제외)
- [ ] 장식이 몸체를 따라옴, 멈춘 적 0, 시간 초과 없음, 도착 시간이 day11c와 비슷함
- [ ] 등불 아래 흰 사각판이 안 보임, 플레이어가 그 자리에서 태어남
- [ ] 스크린샷 2장(북문 밖 적 무리, 등불 받침대)을 `docs/devlog/shots/day11d/`에
