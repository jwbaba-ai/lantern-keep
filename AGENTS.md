# roblox-ai-director — 에이전트 공통 규칙

Meta Global AI Developer Hackathon (인디 개발자 트랙) 제출용 저장소입니다.
Muse Code(주력)는 이 파일을, Claude Code(리뷰)는 CLAUDE.md(→ 이 파일)를 읽습니다. 모든 에이전트는 이 규칙을 따릅니다.

## 프로젝트 목표
로블록스 협동 액션RPG 디펜스 게임에 메타 모델을 붙여 "살아 있는 세계"를 만든다.
1. **AI 디렉터** (Muse Spark 1.3): 웨이브 사이에 경기 요약을 받아 다음 웨이브(적 구성, 전술, 돌발 이벤트)를 JSON으로 설계한다.
2. **기억을 가진 NPC 동료** (Muse Spark 1.3): 파티별 기억을 경기 후 요약해 저장하고, 다음 판 대사에 반영한다.
3. **Muse Image**: 이벤트 배너와 NPC 초상화를 개발 중에 미리 생성해 에셋으로 업로드한다(런타임 생성 아님).

## 10일 결과물과 성공 기준
- 디렉터가 실시간으로 설계한 웨이브 3개 이상이 들어간 플레이 가능한 협동 데모
- 지속 기억을 가진 NPC 동료 2명
- 플레이 스타일이 다른 두 팀이 서로 다른 판을 겪는 짧은 영상
- 성공 기준: 경기를 깨뜨리는 디렉터 출력 0건 / 플레이테스터가 NPC가 지난 판을 언급한다는 걸 알아챔

## 절대 규칙
- **API 키를 코드, 로그, 커밋, 출력 어디에도 넣지 않는다.** 게임은 `HttpService:GetSecret("meta_api_key")`, PC 도구는 환경 변수 `MODEL_API_KEY`만 사용한다.
- **디렉터 호출이 실패하면 반드시 대체 웨이브로 진행한다.** 타임아웃, HTTP 오류, 잘못된 JSON, 검증 실패 모두 해당. 경기는 절대 멈추지 않는다.
- **AI가 만든 텍스트는 필터를 거친 뒤에만 표시한다.** `TextService:FilterStringAsync` → `GetNonChatStringForBroadcastAsync`. 실패하면 미리 정한 기본 대사를 쓴다.
- **AI 고지**: AI가 만든 대사가 나오는 화면에는 "AI가 생성한 대사입니다" 표시를 둔다.
- 모델 호출은 **웨이브 사이에만** 한다(웨이브 시작 시 다음 웨이브를 미리 요청). 전투 중 실시간 호출 금지.
- 개인 데이터를 저장하지 않는다. NPC 기억에는 게임 내 사건만 저장한다.

## 단일 기준(Source of truth)
- 웨이브 스키마 원본: `schemas/wave_plan.schema.json`
  - 수정하면 `python tools/gen_schema_luau.py`로 `src/shared/WaveSchema.luau`를 다시 생성한다. Luau 파일을 직접 고치지 않는다.
  - strict 모드 규칙: 모든 객체에 `additionalProperties: false`, 모든 속성을 `required`에 포함, 재귀 구조 금지.
- 디렉터 프롬프트 원본: `src/server/Director/prompt.txt` (게임과 PC 테스트 도구가 같은 파일을 쓴다)
- 게임 설정값(모델 이름, 타임아웃, 적 목록): `src/shared/Config.luau`

## 폴더와 담당 (파일당 작성자 1명)
| 폴더 | 내용 | 담당 |
|---|---|---|
| `schemas/`, `src/shared/` | 스키마, 설정 | 사람(Babazz) 승인 후 변경 |
| `src/server/Director/` | 디렉터 호출, 검증, 대체 웨이브 | **Muse Code** |
| `src/server/NpcMemory/` | 기억 저장, 요약, 대사 필터 | **Muse Code** |
| `tools/`, `fixtures/` | PC 테스트 도구, 샘플 데이터 | **Muse Code** |
| (리뷰 전용) | 코드 리뷰, 막혔을 때 두 번째 의견 | Claude Code — 파일을 직접 고치지 않고 제안만 |
| `docs/devlog/` | 날짜별 기록 | 작업한 에이전트가 끝날 때 한 줄 추가 |

## 해커톤 규칙 (참가자 가이드 기준, 위반 시 실격)
- **새 작업만 인정**: 이 저장소의 커밋은 빌드 기간(2026-10-27 00:00 ET = 한국 10/27 13:00) 이후에 만든 것만 넣는다.
- 외부(기존 게임 등)에서 가져온 코드·에셋은 `docs/ORIGINS.md`에 출처와 "기존/신규"를 반드시 기록한다. 기록 없는 외부 코드 추가 금지.
- **저장소는 공개된다.** 회사 자료, 비공개 게임 코드, 키, 개인정보를 넣지 않는다.
- 데모(3분 영상)는 해커톤 기간에 새로 만든 기능만 보여 준다.

## 게임 정보 (TODO: Babazz가 채움)
- 적 종류: TODO
- 레인/방어선 구조: TODO
- 직업(역할): TODO
- 현재 웨이브 생성 방식: TODO

## 작업 방식
- 작업 시작 전 이 파일과 `docs/devlog/`의 최근 기록을 읽는다.
- 큰 변경은 계획을 먼저 짧게 제시하고 승인받은 뒤 진행한다.
- 작업이 끝나면 `docs/devlog/YYYY-MM-DD.md`에 무엇을 했고 다음에 할 일이 무엇인지 남긴다.
- 커밋 메시지는 `feat(director): ...`, `fix(npc): ...`, `chore(tools): ...` 형식.
