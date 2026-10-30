# Lantern Keep

A 1–4 player co-op castle defense game on Roblox. An **AI director** reads how your team played and designs the next wave. **NPC companions** remember your last match and bring it up when the next one starts.

Built for the Meta Global AI Developer Hackathon (indie developer track). Everything in this repository was made during the build period (see [docs/ORIGINS.md](docs/ORIGINS.md)).

- Play: https://www.roblox.com/games/83779357358291 <!-- TODO: confirm the experience is public before submission -->
- Demo video (3 min): TODO

## The game

You defend the **Lantern** at the center of a keep. Enemies come through four gates (north, south, east, west).

- **The run:**
  - Each match is one **Day**: 3 waves on Day 1, growing to 10 waves with a boss from Day 5.
  - If you win, the next Day starts. If you lose, you retry the same Day.
- **Classes:** guardian (tank), ranger (ranged), cleric (healing and revives), arcanist (area magic).
- **Enemies:** Grunt, Runner, Brute, Archer, Shaman, plus the boss "Shadow Warlord".
- **Support squad:** Short on players? Vote in the lobby for rule-based bots to fill the empty slots. They either spread out to hold separate gates or group up and heal each other.
  - The bots never call a model.
- **Phone-friendly UI:** A banner shows the director's plan, a lantern health bar sits top-right, and a dialog panel at the bottom shows AI lines.

Full design: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).

## How Meta models are used

All runtime AI calls go to Meta models. They happen only **between waves**, never during combat.

### 1. AI director — Muse Spark 1.3

When a wave ends, the server builds a match summary. It contains:
- lantern health and the gate where the most enemies broke through
- each player's class, damage dealt and deaths
- revives
- the previous wave's plan

During the 20-second intermission, the director turns this into the next wave as strict JSON. The plan has four parts:
- **Enemies:** which enemies come through which gate.
- **Tactic:** `focus_weak_lane`, `split_push`, `flank` or `siege`.
- **Event:** `fog`, `elite_spawn`, `reinforcement_delay` or `blood_moon`.
- **Note:** a short line from the director shown to players.

```
wave ends → MatchStats summary → Muse Spark (JSON schema, strict)
          → WaveValidator (enums, totals, day rules)
          → pass: play the AI wave  |  fail / timeout / bad JSON: play a fallback wave
```

The match never stops. Any timeout, HTTP error, invalid JSON or rule violation plays a predefined fallback wave instead.

- Schema (single source of truth): [schemas/wave_plan.schema.json](schemas/wave_plan.schema.json)
- Prompt (shared by the game and the PC test tools): [src/server/Director/prompt.txt](src/server/Director/prompt.txt)

### 2. NPC companions with memory — Muse Spark 1.3

Two companions stand by the Lantern:
- **Bram**, the veteran captain, remembers the battle (which gate fell, which wave was close).
- **Mira**, the apprentice healer, remembers people ("you revived me twice last time").

How memory works:
1. After each match, the game stores in-game events for the party in a DataStore (the 10 most recent events). The party key is built from sorted user IDs.
2. Muse Spark summarizes those events into greetings for the next match.
3. The lines are spoken when the next match starts.

Safety rules:
- **Filtered:** Every AI line passes `TextService` filtering before it is shown. If filtering or generation fails, a default line is used.
- **Disclosed:** AI lines are labeled on screen: "AI가 생성한 대사입니다" ("AI-generated line").
- **No personal data:** Only in-game events are stored. Players are referred to by party slot (P1, P2, …), not by name.

### 3. Art — Muse Image

NPC portraits, the boss portrait and the event banners were generated with Muse Image during development and uploaded as Roblox assets. Images are not generated at runtime.

The keep, walls, NPC bodies and enemies are built in code from Roblox primitive parts, materials and lighting. No Toolbox or third-party assets are used.

## Results

Measured with the PC tools in `tools/` against the same prompts and validators the game uses. Reports are in [docs/reports/](docs/reports/).

| Check | Result |
|---|---|
| Director outputs that pass schema + validator | **32 / 32** (no fallbacks needed) |
| Director outputs that would break a match | **0** |
| Director response time | median 4.3 s, max 5.9 s (game timeout 15 s) |
| NPC lines that pass validation | **9 / 9** |
| NPC lines that mention the previous match (gate or wave) | **8 / 9** |

Different play styles get different matches. Two simulated teams went through the same waves ([team_compare.md](docs/reports/team_compare.md)):

| Team | What the director sent next |
|---|---|
| Team A broke at the south gate | 79 enemies at the south gate |
| Team B scattered | 45 at the east gate and 32 at the west gate |

The director notes also named each team's weak spot:
- Team A: "The horde smells blood at the south gate…"
- Team B: "East fell once, so the pack runs for it again…"

## How it was built

This was a solo indie project with AI coding agents. The roles were kept separate:

| Who | Role |
|---|---|
| Babazz (human) | Game design, decisions, approvals, live playtests on phone, asset uploads |
| Muse Code | Implemented the game code in `src/` and the PC tools in `tools/` |
| Claude Code | Wrote daily task directives ([docs/tasks/](docs/tasks/)), reviewed commits, ran Roblox Studio MCP checks and logged results in [docs/devlog/](docs/devlog/) |

Runtime AI in the game uses Meta models only. The work rules for all agents are in [AGENTS.md](AGENTS.md).

## Repository layout

| Path | Contents |
|---|---|
| `src/server/Director/` | Director client, validator, fallback waves, event effects |
| `src/server/NpcMemory/` | Memory storage, summarization, text filtering |
| `src/server/Support/` | Support squad bots |
| `src/server/Enemies/`, `src/server/Combat/` | Enemy spawning and movement, combat |
| `src/server/World/` | Map and decoration built from primitives |
| `src/client/` | UI: class picker, wave banner, lantern bar, NPC dialog, results |
| `src/shared/` | Config, catalogs, generated schemas |
| `schemas/` | JSON schemas (source of truth) |
| `tools/`, `fixtures/` | PC test and eval tools with sample data |
| `docs/` | Design, task directives, devlog, reports, origins |

## Running it

1. Install [Rokit](https://github.com/rojo-rbx/rokit) (it pins Rojo 7.7.1 in `rokit.toml`) and run `rojo serve`. Connect from the Rojo plugin in Roblox Studio.
2. In Experience Settings → Security, turn on **Allow HTTP Requests** and **Enable Studio Access to API Services**.
3. Add a secret named `meta_api_key` (domain `api.meta.ai`) in the Creator Dashboard. For Studio, add it as a local secret.
   - Without a key, the game still runs: the director uses fallback waves, and the NPCs use default lines.
4. PC tools (Python), with your key in the `MODEL_API_KEY` environment variable:
   - `python tools/test_director.py fixtures/match_summaries/*.json`
   - `python tools/eval_director.py fixtures/match_summaries/*.json --dry-run`
   - `python tools/eval_npc.py fixtures/npc_memory/*.json --dry-run`
5. If you edit a schema, regenerate the Luau files: `python tools/gen_schema_luau.py`.

API keys are never stored in code, logs or commits.

---

## 한국어 요약

**Lantern Keep(등불 성채)**은 1~4인 협동 성채 디펜스 게임입니다.
- **AI 디렉터:** Muse Spark 1.3이 웨이브 사이에 팀의 플레이 요약을 읽고 다음 웨이브를 JSON으로 설계합니다. 실패하면 대체 웨이브로 진행해서 경기가 멈추지 않습니다.
- **NPC 동료:** Bram과 Mira가 지난 판 사건을 기억해 다음 판 인사에서 언급합니다. 모든 AI 대사는 필터를 거치고 "AI가 생성한 대사입니다"로 표시합니다.
- **그림:** 초상화와 배너는 개발 중에 Muse Image로 만들었습니다.
- **역할:** 구현은 Muse Code, 지시·리뷰·Studio 테스트는 Claude Code, 기획·결정·실서버 테스트는 사람(Babazz)이 맡았습니다.
