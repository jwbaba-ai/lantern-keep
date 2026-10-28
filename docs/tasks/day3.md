# Day 3 작업 지시 (2026-10-29) — "플레이어가 직업을 골라 싸우고, 실제 전투 기록이 디렉터에게 간다"

먼저 AGENTS.md, docs/GAME_DESIGN.md, docs/devlog/2026-10-28.md를 읽는다.

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다.
- `schemas/`, `src/shared/WaveSchema.luau`, `src/server/Director/prompt.txt`는 고치지 않는다.
- `src/shared/Config.luau`는 **이번 작업에 필요한 새 키 추가만** 허용한다(기존 값 변경 금지). 추가한 키는 devlog에 적는다.
- 환경 설정·패키지 설치 명령 금지. 30초 넘게 멈추는 명령은 중단하고 보고한다.
- 모든 클라이언트→서버 요청은 서버에서 검증한다(쿨다운, 사거리, 직업 일치). 데미지 계산은 서버에서만.
- 클라이언트 코드는 `src/client/`에 둔다. `default.project.json`에 `StarterPlayer > StarterPlayerScripts > Client` → `src/client` 매핑을 추가한다(이 파일은 이 매핑 추가만 허용). 클라이언트 실행 스크립트 이름은 `*.client.luau`.

## 0단계: 어제 Studio 확인 결과 반영
`docs/devlog/2026-10-28.md`의 체크리스트에 사람이 남긴 메모가 있으면 먼저 그 문제부터 고치고 커밋한다. 메모가 없으면 넘어간다.

## 1단계: 직업 데이터 (`src/shared/ClassCatalog.luau`)
| 직업 | 기본 공격 | 수치 (시작값) |
|---|---|---|
| guardian | 근접 휘두르기: 앞쪽 반경 8 안의 적 | 피해 35, 쿨다운 0.8초, 최대 체력 200 |
| ranger | 조준 사격: 마우스 방향 레이캐스트 | 피해 25, 사거리 120, 쿨다운 0.6초, 최대 체력 100 |
| arcanist | 범위 폭발: 마우스 위치 반경 10 | 피해 20, 사거리 80, 쿨다운 1.5초, 최대 체력 90 |
| cleric | 치유: 반경 15 안의 아군 회복 / 근접 공격 | 회복 30, 쿨다운 2초, 공격 피해 10, 최대 체력 120 |

## 2단계: 직업 선택
- 접속 시 화면 가운데 버튼 4개(직업 이름 + 한 줄 설명) → RemoteEvent `ChooseClass`
- 서버가 직업을 저장(플레이어 어트리뷰트 `Class`), 최대 체력 적용, 해당 Tool 지급
- 선택 안 하면 10초 후 guardian으로 자동 지정

## 3단계: 전투 (`src/server/Combat/`)
- 각 직업 Tool의 Activated → RemoteEvent `Attack`(조준 위치 포함) → 서버 `CombatService`가 검증 후 판정
- 적 피해는 적 파트의 `Health` 어트리뷰트를 깎고, 0이 되면 EnemyFactory의 처치(killed) 경로로 정리
- 처치·피해는 공격한 플레이어에게 기록 (MatchStats로 전달)
- 간단한 시각 효과: 공격 방향 짧은 Beam 또는 반짝이는 파트 0.2초

## 4단계: 적의 반격 (최소한)
- Grunt·Brute·Runner: 반경 5 안의 플레이어에게 초당 피해 (Grunt 8, Brute 15, Runner 5)
- Archer: 반경 40 안 가장 가까운 플레이어에게 2초마다 8 피해
- Shaman: 반경 15 안 적을 3초마다 체력 20 회복
- 플레이어가 쓰러지면 deaths +1, 기본 리스폰 사용

## 5단계: 테스트 처치 타이머 정리
- 플레이어가 1명 이상 있으면 테스트 처치 타이머를 끈다.
- 플레이어가 없을 때(자동 테스트)만 기존 타이머를 쓴다. Config에 `AutoKillWhenNoPlayers = true` 추가.

## 6단계: MatchStats 실제 기록
- 요약의 `players` 배열에 `{ role, damage, deaths }`를 실제 값으로 채운다
- `revives`: cleric 치유로 체력 25% 이하의 아군을 살린 횟수
- fixtures와 같은 필드 구조를 유지한다 (`wave`, `lantern_health_pct`, `breached_lane`, `revives`, `players`, `previous_wave`)
- `breached_lane`: 그 웨이브에서 등불에 가장 많이 도달한 레인 (없으면 null)

## 7단계: 마무리
- `docs/devlog/2026-10-29.md`에 한 일, 추가한 Config 키, 사람이 확인할 체크리스트, 다음 할 일 기록 후 커밋
- 커밋 후 `git push` (원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다

## 사람이 Studio에서 확인할 것 (devlog에 체크리스트로 복사)
- [ ] Play → 직업 선택 화면 → 고른 직업의 무기를 받음
- [ ] 4개 직업 모두 공격이 적에게 들어가고 적이 쓰러짐
- [ ] 적에게 맞아 체력이 줄고, 쓰러지면 리스폰됨
- [ ] Output의 경기 요약에 내 직업·피해량·사망 수가 찍히고, 디렉터가 그걸 반영해 다음 웨이브를 짬 (팀 테스트에서 `source=muse`)
