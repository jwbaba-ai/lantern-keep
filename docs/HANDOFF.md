# 인수인계: Meta 해커톤 진행 맥락 (Claude Code가 이어서 진행)

이 문서는 claude.ai 대화에서 진행하던 기획·관리 역할을 PC의 Claude Code가 이어받기 위한 요약이다.
작업을 시작할 때 AGENTS.md → 이 문서 → docs/GAME_DESIGN.md → 최근 docs/devlog/ 순서로 읽는다.

## 해커톤 기본 정보
- 행사: Meta Global AI Developer Hackathon, **인디 개발자 트랙**, 테마 "Build for Your World"
- 참가자 가이드(정식 규정): https://cerebralvalley.ai/e/meta-ai-developer-hackathon/details
- **제출 마감: 2026-11-04 21:00 ET = 한국 11/5(목) 11:00.** 목표는 11/4(수) 밤 제출
- 제출물: **공개 GitHub 저장소** + **3분 데모 영상**(심사 핵심 자료) + 실행 가능한 제품
- 심사(0~10점): 임팩트 30% / 메타 AI 도구 활용 25% / 데모 25% / 기술 깊이 20%
- 보너스상 후보: Best Agentic Use-Case, Best Creative Build(Muse Image), Most Viral(X 게시), Community Vote

## 반드시 지킬 규정
- **새 작업만 인정**: 해커톤 기간(10/27~)에 만든 것만 발표. 이 저장소는 그 기간에 새로 만든 게임이다. 기존 게임 코드 가져오기 금지.
- 데모 영상과 README에서 **무엇을 새로 만들었는지 명확히** 구분 (못 하면 즉시 실격)
- 저장소는 공개된다 → 키, 회사 자료, 개인정보 금지
- 근무 시간·회사 장비로 작업하지 않는다(지적재산권 귀속 위험). 개인 PC·개인 계정만.

## 결정된 사항
- 게임: **Lantern Keep**(등불 성채) — docs/GAME_DESIGN.md가 단일 기준
- AI: Muse Spark 1.3(디렉터, NPC 기억), Muse Image(배너·초상화를 개발 중 미리 생성해 에셋 업로드)
- 역할 분담: **Muse Code = 구현**, **Claude Code = 다음 날 지시 파일 작성, 코드 리뷰, Studio MCP로 테스트·보고**
- 일정은 GAME_DESIGN.md의 표. 11/1(일) 밤 범위 점검(불안하면 NPC 1명으로 축소)

## 진행 상황 (2026-10-28 오전 기준)
- GitHub 원격 저장소: **아직 없음** (이관 직후 생성)
- day1: 디렉터 PC 테스트 도구, 샘플 8개 — 완료
- day2: 맵 생성, 적 이동, 웨이브 검증, 대체 웨이브, 7웨이브 매치 흐름 — **코드 완료, Studio 미확인**
- day3 지시 파일 준비됨: docs/tasks/day3.md (직업·전투·실제 기록)

## 이관 직후 Claude Code가 할 일 (순서대로)
1. **커밋 이메일 점검**: `git config user.email`이 회사 이메일이면 사람에게 알리고, GitHub noreply 주소(`숫자+아이디@users.noreply.github.com`)로 바꿀지 확인받는다. 이미 회사 이메일로 된 커밋이 있으면 공개 전에 작성자 정보 정리 방법을 제안한다(사람 승인 후 실행).
2. **커밋되지 않은 변경 커밋**: `docs/HANDOFF.md`, `AGENTS.md`, `docs/tasks/day3.md` 등 → `chore: handoff to Claude Code`
3. **GitHub 비공개 저장소 생성 후 업로드**: 이름 `lantern-keep`, **Private**. 예: `gh repo create lantern-keep --private --source . --push` (gh가 없으면 웹에서 만들고 `git remote add origin ...` → `git push -u origin main`). 업로드 후 `.venv`, `.muse` 등 무시 폴더가 올라가지 않았는지 확인
4. **Studio MCP로 day2 테스트**: 사람이 `rojo serve` + Studio Rojo 플러그인 Connect를 해 둔 상태에서 Play → Output 확인 → day2 체크리스트 결과를 `docs/devlog/2026-10-28.md`에 기록하고 커밋·push. 오류는 원인 분석만 하고 `src/`는 고치지 않는다
5. 결과에 따라 day3 지시 파일을 보완하거나(day2 오류 수정 단계 추가) 그대로 둔다

## 매일 반복
- 밤: 그날 결과 확인(Studio MCP 테스트) → devlog 기록 → 다음 날 `docs/tasks/dayN.md` 작성 → 커밋·push
- 모든 지시 파일 마지막 단계에 **"커밋 후 `git push`"**를 넣는다 (PC 장애 대비 백업)

## 공개 전환 (11/3 화 목표)
- 공개 전 점검: 키·토큰 문자열, 회사 자료, 개인정보, 커밋 이메일 → 문제없으면 Public 전환
- README에 "해커톤 기간 신규 작업" 명시, `docs/ORIGINS.md` 최신화

## 지시 파일 작성 규칙 (docs/tasks/dayN.md)
- 맨 위에 그날의 한 줄 목표, 공통 규칙(단계마다 커밋, 금지 파일, 환경 설정 명령 금지, 30초 멈춤 시 보고)
- 단계별 산출물을 구체적으로, 끝에 "사람이 Studio에서 확인할 것" 체크리스트
- Muse Code 실행은 사람이 `muse --disable-sandbox` 후 `Read docs/tasks/dayN.md and follow it step by step` 한 줄

## 환경 메모 (겪은 문제와 해결)
- Muse Code는 **반드시 `muse --disable-sandbox`로 실행**. 샌드박스(기본 proxy-only 네트워크)에서 PC 인터넷이 끊기고 명령이 멈췄다.
- Muse Code 설정: 모델 `muse-spark-1.3`(contributor 아님), 추론 `medium`, 음성 입력·개인 규칙/스킬 가져오기 끔
- 파이썬은 저장소의 `.venv`만 사용(사람이 만듦). 에이전트가 환경 설정하지 않음
- 기본 PowerShell 창은 클릭하면 "선택" 모드로 입력이 멈춤 → Esc. Windows Terminal 권장. 한/영(오른쪽 Alt)+V는 음성 입력 단축키였음
- Studio: 체험은 개인 계정으로 비공개 게시됨. HTTP 허용은 명령 모음(`HttpService.HttpEnabled = true`)으로 켬. 보안 설정 창이 잠겨 있어 로컬 보안 비밀 대신 **크리에이터 허브 Secrets(`meta_api_key`, 도메인 api.meta.ai) + 팀 테스트**로 디렉터 호출 확인
- 크레딧: 150달러 중 약 148달러 남음(10/28). 디렉터 호출은 0.5센트 수준, Muse Code 작업 1회 약 1달러. 매일 Billing 확인
