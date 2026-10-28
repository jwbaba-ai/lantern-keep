# Day 2 작업 지시 (2026-10-28) — "적이 걸어와 등불을 깎고, 디렉터가 웨이브를 짠다"

먼저 AGENTS.md와 docs/GAME_DESIGN.md를 읽는다. 오늘 목표는 **전투 없이도 7웨이브가 자동으로 돌아가는 뼈대**다.

## 공통 규칙
- 각 단계가 끝날 때마다 커밋한다 (끊겨도 이어서 할 수 있게).
- `schemas/`, `src/shared/Config.luau`, `src/shared/WaveSchema.luau`는 고치지 않는다 (오늘 사람이 승인해 갱신 완료).
- 환경 설정·패키지 설치 명령은 실행하지 않는다. 30초 넘게 멈추는 명령은 중단하고 보고한다.
- 로블록스 코드는 Luau, 서버 코드는 `src/server/`, 공용 모듈은 `src/shared/`. Rojo 매핑은 `default.project.json` (src/server → ServerScriptService.Server).
- 스크립트 파일 이름 규칙: 실행 스크립트 `*.server.luau`, 모듈 `*.luau`.

## 0단계: 오늘 사람이 바꾼 파일 커밋
`git add -A` 후 커밋: `feat: lantern keep game data (schema, prompt, fixtures, design doc)`

## 1단계: 디렉터 회귀 테스트
`.venv\Scripts\python.exe tools/test_director.py` 를 fixtures 8개에 각각 실행하고 결과 표를 devlog에 남긴다. 새 적(Runner, Brute, Shaman)과 blood_moon이 상황에 맞게 쓰이는지 한 문장으로 평가한다.

## 2단계: 공용 데이터 모듈 (`src/shared/`)
- `EnemyCatalog.luau`: GAME_DESIGN.md의 적 표(체력, 속도, 등불 피해)와 색상
- `FallbackWaves.luau`: 웨이브 1~7 고정 웨이브 (스키마와 같은 형태). 웨이브 1은 항상 이것을 쓴다.

## 3단계: 웨이브 검증 (`src/server/Director/WaveValidator.luau`)
- `validate(plan, waveNumber) -> (ok: boolean, cleanPlan, errors: {string})`
- 확인: 필드 존재, enum 값이 Config 목록에 있는지, count는 정수 1 이상, 총합 MinEnemies~MaxEnemies(벗어나면 비율 유지하며 보정), blood_moon은 BloodMoonMinWave 이상에서만(아니면 none으로 교체)
- 같은 폴더에 `WaveValidator.spec.luau` 형태로 예시 입력 5개와 기대 결과를 주석/테이블로 남긴다 (Studio 실행 테스트는 사람이 함)

## 4단계: 맵 생성 (`src/server/World/MapBuilder.server.luau`)
- 서버 시작 시 `workspace.Map`이 없으면 GAME_DESIGN.md의 그레이박스를 코드로 생성
- 등불(Health 속성), 성문 4개, 스폰 지점 4개, 레인별 웨이포인트(`workspace.Map.Lanes.<lane>`에 순서대로 이름 붙인 파트)
- 생성 완료 시 `workspace.Map:SetAttribute("Ready", true)`

## 5단계: 적 이동 (`src/server/Enemies/`)
- `EnemyFactory.luau`: 타입별 단순한 적 모델(색 구분된 파트 + Health 속성 + 이름 표시 BillboardGui)
- 레인 웨이포인트를 따라 이동(TweenService 또는 단순 이동), 등불에 닿으면 등불 Health를 등불 피해만큼 깎고 제거
- 아직 플레이어 공격은 없다. 대신 테스트용으로 적은 생성 후 일정 시간(체력 비례)이 지나면 "처치"된 것으로 처리해 웨이브가 끝나게 한다 (3일차에 실제 전투로 교체)

## 6단계: 매치 흐름 (`src/server/Director/DirectorService.server.luau` + `MatchStats.luau`)
- 웨이브 1~TotalWaves 반복: 웨이브 진행 → 종료 → MatchStats 요약 생성(fixtures와 같은 필드 구조, 플레이어 정보는 아직 빈 배열) → 대기 시작과 동시에 `DirectorClient.requestNextWave(summary)` → `WaveValidator` 통과 시 적용, 아니면 `FallbackWaves`
- 이벤트는 오늘 Output 로그만 (효과는 4일차)
- 모든 결정을 Output에 `[Director] wave=3 source=muse|fallback tactic=... event=... note=...` 형식으로 기록
- 결과를 `ReplicatedStorage`의 `DirectorState`(StringValue, JSON)에 저장 (4일차 UI용)
- 등불 Health 0이면 패배, 7웨이브 완료면 승리를 Output에 기록

## 7단계: 마무리
- `docs/devlog/2026-10-28.md`에 한 일, 테스트 결과, 사람이 Studio에서 확인할 체크리스트, 다음 할 일 기록 후 커밋

## 사람이 Studio에서 확인할 것 (devlog에 체크리스트로 복사)
- [ ] `rojo serve` → Studio Rojo 플러그인 Connect → ServerScriptService.Server, ReplicatedStorage.Shared 생성 확인
- [ ] Play → 맵 자동 생성, 적이 4개 성문으로 걸어와 등불 체력 감소
- [ ] Output에 `[Director] ... source=muse` 줄이 웨이브 2부터 찍힘 (Local Secrets 설정 필요)
- [ ] Local Secrets를 지우고 Play → `source=fallback`으로 끝까지 진행 (경기가 멈추지 않음)
