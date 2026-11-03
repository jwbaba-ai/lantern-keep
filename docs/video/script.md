# 3분 데모 영상 대본 (Lantern Keep)

- 길이: **3:00 이하**. 자막은 영어(심사용), 괄호 안 한국어는 편집할 때 참고용이다.
- 해커톤 기간에 새로 만든 것만 보여 준다. 이 게임은 전부 해커톤 기간에 만들었다.
- 심사 비중: 임팩트 30% / Meta AI 활용 25% / 데모 25% / 기술 깊이 20%. 그래서 **디렉터와 NPC 기억에 1분 30초**를 쓴다.
- 소스 영상 (저장소에 넣지 않는다):
  - **A** = `vedios/유저 1인 협력파 2day 진행.mp4` (3:05, 최신 빌드)
  - **B** = `vedios/유저1인 협력파 3day 진행.mp4` (7:49, 직전 빌드. 보조로만 쓴다)
- 화면 녹화가 더 필요한 것은 ★로 표시했다.

## 장면 목록

| 시간 | 장면 | 소스 (시작~끝) | 영어 자막 |
|---|---|---|---|
| 0:00–0:12 | **도입:** 지원대와 함께 성문 앞에서 싸우는 장면, 피해 숫자, 처치 폭발 | A 0:18–0:30 | Lantern Keep — a co-op castle defense game on Roblox. |
| 0:12–0:20 | 제목 카드: 썸네일 위에 한 줄 | `assets/images/thumbnail_16x9.png` | An AI director designs every wave. Two companions remember how you played. |
| 0:20–0:32 | **준비:** 직업 선택, 지원대 투표, 시작 | A 0:00–0:08 | Pick a class. Short on players? Vote for a support squad to fill the empty slots. |
| 0:32–0:45 | **첫 대사 (기억 없음):** 기본 대사(AI 표시 없음) | A 0:08–0:14 | On Day 1, the companions know nothing about you yet. |
| 0:45–1:05 | **AI 디렉터 ①:** 웨이브가 끝나면 "디렉터가 다음 웨이브를 설계하는 중" → 배너에 웨이브 이름·디렉터 한마디·성문 순서·AI 고지, 성문 깜빡임 | A 0:36–0:45 (웨이브 2 "Whispers in the Mist"), A 2:57–3:02 (설계 중) | Between waves, Muse Spark 1.3 reads a summary of the last wave — breached gates, damage, deaths, revives — and designs the next wave as strict JSON. |
| 1:05–1:20 | **AI 디렉터 ②:** 디렉터가 지난 판을 보고 설계했다는 증거. Day 2 배너 "Echoes at the Gates — The south breach drew eyes", 남문 4 먼저 | A 2:29–2:34 | It noticed the south gate broke last time. So Day 2 opens with four enemies at the south gate. |
| 1:20–1:35 | **두 팀 비교:** 같은 웨이브를 다르게 겪은 두 가상 팀 표 ★ | README "Results" 표 화면 녹화 (Team A 남문 79 / Team B 동 45·서 32) | Different teams get different games. A team that broke in the south faced 79 enemies there. A team that scattered was hit from east and west. |
| 1:35–1:50 | **NPC 기억 ①:** 결과 화면 "Bram과 Mira가 이번 판을 기억합니다", 초상화 | A 2:00–2:10 | After each match, the party's in-game events are saved, and Muse Spark turns them into memories. |
| 1:50–2:10 | **NPC 기억 ②:** Day 2 시작 AI 대사 "Day 2에서 만나니 반갑다 … 협력파여", 웨이브 중 대사 "1웨이브를 막아내자 동문과 남문을 보라", "AI가 생성한 대사입니다" | A 2:31–2:40, A 2:58–3:02 | Next match, Bram and Mira bring it up: the day, the squad you chose, the gates you held. Every line is labeled as AI-generated. |
| 2:10–2:22 | **Muse Image:** Bram·Mira·보스 초상화, 이벤트 배너 5장을 나란히 | `assets/images/portrait_*.png`, `banner_*.png` | Portraits and event banners were made with Muse Image during development — no runtime image generation. |
| 2:22–2:38 | **안전장치:** 흐름 그림 ★ + 짧은 장면(대체 웨이브 배너 "기본 웨이브") | README의 흐름 그림 화면 녹화, B 0:00–0:05 | The match never stops: timeouts, bad JSON or rule breaks fall back to a prebuilt wave. AI text is filtered, labeled, and models are only called between waves. |
| 2:38–2:50 | **만든 방법:** 역할 표 ★ | README "How it was built" 화면 녹화 | Built solo in the hackathon window: Muse Code wrote the game, Claude Code wrote daily specs, reviewed and tested in Studio. |
| 2:50–3:00 | **끝:** 등불 앞 전투 한 컷 + 링크 | A 1:48–1:57 + 글자 | Play on Roblox · github.com/jwbaba-ai/lantern-keep |

## 편집 메모
- 화면은 가로(16:9)로 맞춘다. 원본은 휴대폰 가로 녹화라 그대로 쓰면 된다.
- 한국어 UI 위에 영어 자막을 화면 아래쪽에 넣는다. 하단 대화창과 겹치는 장면(1:50–2:10)은 자막을 화면 위쪽으로 올린다.
- **쓰지 않을 장면:**
  - Day가 바뀔 때 큰 글자가 투표 알림과 겹치는 순간 (A 2:28 부근)
  - 휴대폰 제어 센터가 내려온 마지막 장면 (A 3:03~)
  - B의 "요약 실패" 결과 화면 (B 2:51, 고치기 전 빌드)
- 화면에 Roblox 사용자 이름(zzangbaba)이 나온다. 공개해도 괜찮은지 사람이 정한다. 가리려면 1:50–2:10 대사 줄만 흐리게 처리한다.
- 배경 음악을 쓰면 저작권 없는 음원만 쓰고 출처를 `docs/ORIGINS.md`에 적는다.
- 3:00을 넘으면 1:20–1:35(두 팀 비교)를 10초로 줄인다.

## ★ 추가로 녹화할 것 (PC 화면, 각 10초 안팎)
1. GitHub README의 **Results** 표 (두 팀 비교)
2. README의 **흐름 그림** (`wave ends → MatchStats summary → Muse Spark …`)
3. README의 **How it was built** 역할 표

녹화할 때 브라우저 탭, 알림, 환경 변수, Studio 비밀 설정이 화면에 나오지 않게 한다.
