# 제출 양식 초안 (영어로 붙여 넣기)

양식 칸 이름은 행사 페이지에 맞춰 골라 쓴다. 칸이 없으면 건너뛴다.

## 실제 양식 칸 → 넣을 내용 (2026-11-04 확인)
| 양식 칸 | 넣을 내용 |
|---|---|
| Team Name* | Lantern Keep (또는 사람이 정한 이름) |
| Team Members | 본인 1명 (이미 들어 있음) |
| Track* | Indie Developer Track |
| Problem statement* | Build for Your World |
| Most Viral (X 링크) | X에 올렸으면 그 링크, 아니면 비움 |
| Project Description* | 아래 "Description" |
| Public GitHub Repository* | https://github.com/jwbaba-ai/lantern-keep |
| 3-Minute Demo Video* | https://youtu.be/Eo5MEwkh_OE |
| Describe your use of Meta products* | 아래 "Use of Meta products (form)" |
| Why are Meta's models important* | 아래 "Why Meta's models (form)" |
| 파트너 기술 피드백 | 파트너(Baseten·Modal·Fireworks)를 쓰지 않았으면 "We did not use partner inference; all calls went to the Meta Model API." |
| 만족도·추천·비교·선택 기준 설문 | **사람이 자기 의견으로 답한다** |
| 가장 큰 장애물 | 아래 "Biggest obstacle (form)" 참고, 사람이 고쳐 쓴다 |
| 자료 사용 동의 | **사람이 읽고 직접 동의한다** |

## Use of Meta products (form)
- Muse Spark 1.3 (Meta Model API) runs the AI director: once per intermission it reads a match summary and returns the next wave as strict JSON (enemies per gate, tactic, event, director note). A validator checks every field, and any failure plays a fallback wave.
- Muse Spark 1.3 also runs NPC memory: once per match end it turns the party's in-game events into memories and next-match lines for two companions, Bram and Mira. Lines are filtered and labeled as AI-generated.
- Muse Image made the companion portraits, the boss portrait and five event banners during development; they ship as Roblox assets.
- Muse Code implemented the game code and the PC evaluation tools from daily written specs; the specs, reviews and test logs are in the repository.

## Why Meta's models (form)
The whole point of Lantern Keep is a world that reacts to the people playing it, and that needs a model that can read a messy match summary and make a game-design decision in a few seconds. Muse Spark's strict JSON-schema output let the director's plans go straight into the game after a validator check, with zero match-breaking outputs in our tests (32/32 valid). The same model writes short, in-character companion lines from the party's history, so one model family covers both the planning and the storytelling. Muse Image gave a solo developer portraits and banners that match the game's look, and Muse Code let one person ship a full co-op game in ten days.

## Biggest obstacle (form)
Keeping model calls from ever blocking a live match. Every path (timeout, HTTP error, invalid JSON, rule break) needed a tested fallback. The hardest case appeared only on the live server: memory summaries took 17–25 s against a 15 s timeout, so every summary failed. Lowering reasoning effort for that call to minimal and giving it its own token and time budget brought it to 8–11 s.

## Links
- Repository: https://github.com/jwbaba-ai/lantern-keep
- Demo video: https://youtu.be/Eo5MEwkh_OE
- Playable game: https://www.roblox.com/games/83779357358291 (Roblox content rating: ages 16+)

## Track
Indie Developer

## Project name
Lantern Keep

## Tagline (one line)
A co-op Roblox defense game where an AI director designs every wave from how you played, and two companions remember your last match.

## Description
Lantern Keep is a 1–4 player co-op castle defense game on Roblox. You defend the Lantern at the center of a keep while enemies push through four gates. Each match is one Day; win and the next Day gets longer and harder, up to a boss.

Two Meta models make the world react to the people playing it:

- **AI director (Muse Spark 1.3).** After every wave, the server builds a match summary: lantern health, which gate broke, each player's class, damage and deaths, revives, and the previous plan. During the 20-second intermission, Muse Spark returns the next wave as strict JSON (enemies per gate, tactic, event, a short director note). A validator checks enums, totals and day rules. The first wave of each new Day is designed from how the previous Day ended.
- **NPC companions with memory (Muse Spark 1.3).** After each match, the party's in-game events are stored, and Muse Spark turns them into memories and lines for the next match. Bram, the veteran captain, remembers the battle; Mira, the apprentice healer, remembers the people.
- **Muse Image** made the NPC portraits, the boss portrait and the event banners during development.

The game never waits on the model: any timeout, HTTP error, invalid JSON or rule violation plays a prebuilt fallback wave, and NPCs fall back to default lines.

## How we used Meta AI
- **Muse Spark 1.3, director:** one call per intermission with a JSON-schema response format (strict mode, no recursion, every field required). Same prompt and schema are shared by the game and the PC test tools.
- **Muse Spark 1.3, memory:** one call per match end. The model sees party slots (P1, P2…) and in-game events only; names are filled in on the server after generation.
- **Muse Image:** portraits and banners generated during development and uploaded as Roblox assets. No runtime image generation.
- **Muse Code:** implemented the game code and the PC evaluation tools from daily written specs.

## Results
- Director outputs that pass schema + validator: 32 / 32 (PC eval, same prompt and validator as the game)
- Director outputs that would break a match: 0
- Director response time: median 4.3 s
- NPC memory lines that pass validation: 9 / 9; lines that mention the previous match: 8 / 9
- Different teams get different games: in a two-team simulation, the team that broke in the south faced 79 enemies at the south gate, while the team that scattered was hit with 45 at the east gate and 32 at the west gate.
- Verified on the live Roblox server: Day 2 opened with an AI wave aimed at the gate that broke on Day 1, and the companions greeted the player with AI lines from the saved memory.

## Safety and responsible AI
- Models are called only between waves, never during combat.
- Every AI line is filtered with `TextService:FilterStringAsync` before it is shown, and labeled on screen as AI-generated.
- Memory stores in-game events only. No personal data is sent to the model.
- API keys live in Roblox Secrets (game) and an environment variable (PC tools), never in code, logs or commits.

## How it was built
Solo indie project, made entirely during the build period.
- Babazz (human): game design, decisions, approvals, live playtests on a phone
- Muse Code: implemented the game code (`src/`) and PC tools (`tools/`)
- Claude Code: wrote daily task specs, reviewed every commit, and ran Roblox Studio checks through Studio MCP

Daily specs are in `docs/tasks/`, test logs in `docs/devlog/`, and the origin of every asset in `docs/ORIGINS.md`.

## Challenges
- Keeping a live match safe from model failures: every path (timeout, bad JSON, rule break) needed a tested fallback.
- Memory summaries first timed out on the live server (17–25 s responses against a 15 s limit). Lowering reasoning effort for the memory call and giving it its own timeout brought it to 8–11 s.
- Building everything from Roblox primitives with no Toolbox assets, while keeping it readable on a phone screen.

## What's next
- More companion personalities and longer memories across Days
- Director tuning per party size and play style, using the live match summaries
- Opening the game to younger players after Roblox's audience review

## Bonus categories to tick (if the form asks)
- Best Agentic Use-Case: AI director that plans each wave from live match data, with validation and fallbacks
- Best Creative Build: Muse Image portraits and banners
