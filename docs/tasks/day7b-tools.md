# Day 7b 작업 지시 — "PC 도구로 모델 출력과 밸런스를 숫자로 확인한다"

먼저 AGENTS.md와 가장 최근 `docs/devlog/` 파일을 읽는다. day7 다음, day8 전에 한다.
오늘은 **게임 코드를 고치지 않는다.** PC 도구와 보고서만 만든다. 결과 숫자는 README와 발표 자료에서 근거로 쓴다.

## 공통 규칙
- 쓸 수 있는 곳: `tools/`, `fixtures/`, `docs/reports/`(새 폴더), devlog. `src/`, `schemas/`, 두 `prompt.txt`는 **고치지 않는다.** 프롬프트 개선은 보고서에 "제안"으로만 적는다.
- API 키는 환경 변수 `MODEL_API_KEY`에서만 읽는다. 키 값을 화면·로그·보고서·커밋 어디에도 남기지 않는다. 변수가 없으면 모델 호출 단계는 건너뛰고 보고한다.
- 패키지 설치·환경 설정 명령은 금지한다. `openai`·`jsonschema`가 없으면 멈추고 보고한다. 밸런스 시뮬레이터는 표준 라이브러리만 쓴다.
- **크레딧 보호:**
  - 모든 모델 호출 도구에 `--max-calls N`(기본 5)과 `--dry-run`(호출 없이 계획만 출력)을 둔다.
  - 이번 작업 전체의 모델 호출은 **60회 이하**다.
  - 먼저 1회만 호출하고 토큰 수를 devlog에 적은 뒤 나머지를 진행한다.
- 30초 넘게 멈추는 명령은 중단하고 보고한다(모델 호출 1회 대기는 예외, 최대 30초).
- 각 단계가 끝날 때마다 커밋한다.

## 1단계: 디렉터 출력 대량 검증 (`tools/eval_director.py`)
- `test_director.py`와 같은 방식으로 호출한다. 같은 프롬프트, 스키마, 모델, effort를 쓴다. 공통 부분은 함수로 빼서 같이 써도 된다. 단, `test_director.py`의 사용법과 출력은 그대로 둔다.
- 사용법: `python tools/eval_director.py fixtures/match_summaries/*.json --runs 4 --max-calls 32`
- 호출 결과 1건마다 다음을 판정한다. 게임의 `WaveValidator.luau` 규칙을 Python으로 옮긴다.
  - `MinEnemies`·`MaxEnemies`·`BloodMoonMinWave`와 enum 목록은 `src/shared/Config.luau`에서 정규식으로 읽는다. 숫자를 코드에 다시 적지 않는다.
  - `muse`: 스키마 통과 + 검증 통과(보정 없음)
  - `muse_autofix`: 검증 통과, 자동 보정 있음(총합 보정, blood_moon → none)
  - `fallback_reject`: 검증 거부(구조·enum 오류)
  - `fallback_error`: HTTP 오류, 잘못된 JSON, 스키마 실패
  - `fallback_timeout`: 응답이 `RequestTimeoutSeconds`(Config)보다 늦음
- 결과를 `docs/reports/director_eval.md`에 쓴다.
  - 판정별 건수·비율 표
  - 거부·보정 사유 목록
  - 응답 시간 중앙값·최댓값(타임아웃 기준과 비교)
  - 평균 토큰 수
  - 실행 날짜와 모델
- **"경기를 깨뜨리는 출력"의 정의**를 보고서에 적는다. 대체 웨이브로 넘어간 경우는 경기가 계속되므로 깨진 것이 아니다. 깨진 것은 검증을 통과했는데 게임 규칙에 어긋나는 계획이다(그런 계획이 있으면 예시와 함께 적는다).
- 원본 응답은 `docs/reports/raw/director_<날짜>.jsonl`에 저장한다(키·헤더 제외).

## 2단계: NPC 출력 검증 (`tools/eval_npc.py`)
- `test_npc.py` 방식으로 `fixtures/npc_memory/*.json`을 각 3회 호출한다(9회).
- `MemoryStore`의 검증 규칙을 Python으로 옮긴다: 줄 수 각 3개, 각 줄 1~80자, `P` 토큰은 파티 인원 안에서만.
- 사건 언급률도 잰다. 입력 events에 있는 성문 이름이나 웨이브 번호가 대사에 한 번 이상 나오면 "언급함"으로 센다. 성공 기준 "NPC가 지난 판을 언급"의 근거다.
- 결과는 `docs/reports/npc_eval.md`에 쓴다.

## 3단계: 두 팀 비교 (데모 근거)
- `fixtures/match_summaries/team_a_*.json`, `team_b_*.json`을 각 3개(웨이브 1~3 요약) 만든다. 형식은 기존 fixture와 같게 한다.
  - A팀 "북문 수비대": 4인이 북문에 몰려 있다. 남문이 반복해서 뚫리고, cleric이 부활을 많이 한다.
  - B팀 "흩어진 사냥꾼": 2인 ranger와 arcanist가 성문마다 흩어진다. 피해량은 높지만 사망이 많고, 등불 체력이 낮다.
- `tools/eval_director.py --compare team_a team_b --runs 3` 같은 방식으로 비교한다(18회).
- 결과를 `docs/reports/team_compare.md`에 쓴다.
  - 팀별 성문별 적 수 합계
  - 전술·이벤트 분포
  - 디렉터 메모 예시 2개씩
  - "두 팀의 다음 웨이브가 어떻게 달랐는가"를 3줄로 요약
- 영상에서 보여 줄 만한 차이 장면을 1개 추천한다.

## 4단계: 밸런스 시뮬레이터 (`tools/balance_sim.py`, 모델 호출 없음)
- 수치는 Luau 파일에서 정규식으로 읽는다. 숫자를 다시 적지 않는다.
  - 적: `EnemyCatalog.luau`(Health, Speed, LanternDamage)
  - 직업: `ClassCatalog.luau`
  - 파티 배율·등불 체력: `Config.luau`
  - 대체 웨이브: `FallbackWaves.luau`
  - 레인 길이: `MapBuilder.server.luau`의 거리 상수
- Day 규칙은 `docs/tasks/day8.md` 값을 기본 인자로 둔다(`--day-waves 3,5,7,9,10`, `--health-step 0.15`, `--count-step 0.10`, 보스 체력 Brute×8 등). day8이 Config에 키를 넣은 뒤에는 Config에서 읽도록 TODO 주석을 남긴다.
- 모델(단순하게):
  - 플레이어는 성문 하나씩 맡는다(인원이 적으면 적이 많은 성문 우선).
  - 직업 초당 피해 = 피해 / 쿨다운 × 효율.
  - 효율은 판마다 0.4~0.8에서 무작위로 정한다(`--seed`).
  - 적이 레인을 걷는 동안 처치되지 못하면 등불에 `LanternDamage`를 준다.
- 출력: Day 1~8 × 파티 1~4인마다 300판을 돌려 **등불이 살아남는 비율**과 평균 남은 체력을 표로 낸다. `docs/reports/balance_sim.md`에 쓴다.
- 목표 구간을 보고서에 적고, 벗어난 칸을 표시한다.
  - Day 1~2: 승률 85% 이상
  - Day 3~4: 60~85%
  - Day 5: 40~70%
  - Day 6 이상: 점점 내려간다
- 벗어난 칸에 대한 조정 제안(어느 값을 얼마나)을 적는다. **적용은 하지 않는다**(사람이 승인한 뒤 day8에 반영한다).
- 시뮬레이터의 가정과 한계(이동 경로, 조준 실력, 원거리 적 무시 등)를 보고서 맨 위에 적는다.
- `tools/balance_sim.py --self-test`: Day 1 / 4인 / 효율 1.0이면 승률 100%, 효율 0이면 0%인지 PASS/FAIL로 확인한다.

## 5단계: 마무리
- devlog에 다음을 기록하고 커밋한다.
  - 각 보고서의 핵심 숫자 3줄씩
  - 전체 모델 호출 수와 총 토큰
  - 프롬프트 개선 제안이 있으면 그 요약
- 커밋 후 `git push`(원격: origin/main). push가 실패하면 오류 메시지를 devlog에 적고 보고한다.

## 사람이 확인할 것 (devlog에 체크리스트로 복사)
- [ ] 실행 전 터미널에 `MODEL_API_KEY`를 설정했다(키는 대화창에 붙여 넣지 않는다)
- [ ] `docs/reports/director_eval.md`: "깨뜨리는 출력" 0건인지
- [ ] `docs/reports/npc_eval.md`: 검증 통과율, 사건 언급률
- [ ] `docs/reports/team_compare.md`: 두 팀의 다음 웨이브가 눈에 띄게 다른지
- [ ] `docs/reports/balance_sim.md`: 조정 제안 중 day8에 넣을 것 고르기
- [ ] `python tools/balance_sim.py --self-test` 모두 PASS
