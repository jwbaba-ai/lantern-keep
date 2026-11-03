"""Lantern Keep 데모 영상 2차본 조립: Edge-TTS 영어 내레이션 + 디렉터 JSON 장면.
사용: python -I docs/video/build_demo_v2.py <repo_root> <out_mp4>
필요: ffmpeg, edge-tts (pip). 내레이션 문장만 Edge-TTS(Microsoft) 서버로 보낸다.
"""
import asyncio, glob, os, subprocess, sys

import edge_tts

ROOT = sys.argv[1]
OUT = sys.argv[2]
WORK = os.path.join(os.path.dirname(os.path.abspath(OUT)), "demo_v2_work")
os.makedirs(WORK, exist_ok=True)

SRC = glob.glob(os.path.join(ROOT, "vedios", "*2day*.mp4"))[0]
IMG = os.path.join(ROOT, "assets", "images")
VOICE = "en-US-AndrewNeural"
RATE = "+4%"
FONT_B = "C\\:/Windows/Fonts/arialbd.ttf"
FONT_R = "C\\:/Windows/Fonts/arial.ttf"
FONT_M = "C\\:/Windows/Fonts/consola.ttf"
W, H, FPS = 1920, 1080, 30
BG = "0x0e1116"
GOLD = "0xffc83c"
ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-r", str(FPS),
       "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-ac", "2"]
LEAD = 0.3  # 장면 시작 뒤 내레이션까지
TAIL = 0.7  # 내레이션 끝 뒤 여유

def ff(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)

def duration(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                        "-of", "csv=p=0", path], capture_output=True, text=True, check=True)
    return float(r.stdout.strip())

_n = [0]
def tf(text):
    _n[0] += 1
    p = os.path.join(WORK, f"t{_n[0]:03d}.txt")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return p.replace("\\", "/").replace(":", "\\:")

def dt(text, size, y, color="white", font=FONT_B, x="(w-text_w)/2", enable=None):
    """여러 줄은 줄마다 따로 그린다."""
    out = []
    for i, line in enumerate(text.split("\n")):
        if not line.strip():
            continue
        s = (f"drawtext=fontfile='{font}':textfile='{tf(line)}':fontsize={size}:fontcolor={color}"
             f":x={x}:y=({y})+{i * int(size * 1.45)}")
        if enable:
            s += f":enable='{enable}'"
        out.append(s)
    return out

def subtitle_filters(narration, start, total_dur):
    """문장마다 자막. 시간은 글자 수 비율로 나눈다. 아래 검은 띠(100px)에 넣는다."""
    sentences = [s.strip() for s in narration.replace("! ", "!|").replace(". ", ".|").replace("? ", "?|").split("|") if s.strip()]
    chars = sum(len(s) for s in sentences)
    t = start
    out = []
    for s in sentences:
        d = total_dur * len(s) / chars
        # 화면 폭을 넘지 않게 70자보다 길면 가운데에 가까운 띄어쓰기에서 두 줄로 나눈다.
        if len(s) > 70:
            mid = len(s) // 2
            cut = min((i for i, c in enumerate(s) if c == " "), key=lambda i: abs(i - mid))
            text, y = s[:cut] + "\n" + s[cut + 1:], "h-96"
        else:
            text, y = s, "h-80"
        out += dt(text, 32, y, enable=f"between(t,{t:.2f},{t + d:.2f})")
        t += d
    return out

async def tts(text, path):
    await edge_tts.Communicate(text, VOICE, rate=RATE).save(path)

segments = []

def build(name, narration, kind, **kw):
    voice = os.path.join(WORK, name + "_voice.mp3")
    if not os.path.exists(voice):
        asyncio.run(tts(narration, voice))
    vdur = duration(voice)
    dur = max(kw.get("min_dur", 0), LEAD + vdur + TAIL)
    out = os.path.join(WORK, name + ".mp4")
    subs = subtitle_filters(narration, LEAD, vdur)
    delay = int(LEAD * 1000)
    if kind == "clip":
        vf = [f"scale={W}:880", f"pad={W}:{H}:0:100:black"]
        if kw.get("tag"):
            vf += dt(kw["tag"], 30, 34, color=GOLD)
        vf += subs
        fc = (f"[0:v]{','.join(vf)}[v];"
              f"[0:a]volume=0.22[g];[1:a]adelay={delay}|{delay},volume=1.0[n];"
              f"[g][n]amix=inputs=2:duration=first:normalize=0[a]")
        ff(["-ss", str(kw["start"]), "-t", f"{dur:.2f}", "-i", SRC, "-i", voice,
            "-filter_complex", fc, "-map", "[v]", "-map", "[a]"] + ENC + [out])
    else:
        inputs = ["-f", "lavfi", "-i", f"color=c={BG}:s={W}x{H}:d={dur:.2f}:r={FPS}",
                  "-f", "lavfi", "-t", f"{dur:.2f}", "-i", "anullsrc=r=44100:cl=stereo", "-i", voice]
        fc = []
        last = "[0:v]"
        for i, (path, x, y, w) in enumerate(kw.get("images", [])):
            inputs += ["-i", path]
            fc.append(f"[{i + 3}:v]scale={w}:-1[im{i}]")
            fc.append(f"{last}[im{i}]overlay={x}:{y}[v{i}]")
            last = f"[v{i}]"
        vf = kw.get("draw", []) + subs + ["fade=t=in:st=0:d=0.4", f"fade=t=out:st={dur - 0.4:.2f}:d=0.4"]
        fc.append(f"{last}{','.join(vf)}[v]")
        fc.append(f"[1:a][2:a]amix=inputs=2:duration=first:normalize=0,adelay={delay}|{delay}[a]")
        ff(inputs + ["-filter_complex", ";".join(fc), "-map", "[v]", "-map", "[a]",
                     "-t", f"{dur:.2f}"] + ENC + [out])
    segments.append(out)
    print(f"{name}: {dur:.1f}s (voice {vdur:.1f}s)")

# ---- 장면 ----
build("01_hook", "This is Lantern Keep, a co-op castle defense game on Roblox, recorded live on a phone.",
      "clip", start=18, min_dur=8, tag="Live Roblox server, recorded on a phone")

build("02_title", "An AI director designs every wave, and two companions remember how you played.",
      "card", min_dur=6,
      draw=dt("LANTERN KEEP", 96, 720, color=GOLD)
           + dt("An AI director designs every wave.\nTwo companions remember how you played.", 40, 850),
      images=[(os.path.join(IMG, "thumbnail_16x9.png"), 560, 90, 800)])

build("03_setup", "Pick a class. If your team is short on players, vote for a support squad to fill the empty slots.",
      "clip", start=0)

build("04_day1", "On Day 1, the companions, Bram and Mira, don't know you yet. So they use default lines.",
      "clip", start=8)

build("05_director",
      "When a wave ends, the server sends Muse Spark 1.3 a summary of the fight: which gate broke, damage, deaths and revives. "
      "During the twenty second break, it designs the next wave. The banner shows the result, labeled as AI text.",
      "clip", start=27, min_dur=18, tag="AI DIRECTOR  |  Muse Spark 1.3")

json_in = ("INPUT  (match summary)\n\n"
           "day 1 · wave 2 of 3\n"
           "lantern_health_pct: 78\n"
           "breached_lane: \"south\"\n"
           "revives: 3\n"
           "players: guardian, guardian,\n"
           "         ranger, cleric\n"
           "previous_wave: focus_weak_lane")
json_out = ("OUTPUT  (Muse Spark, strict JSON schema)\n\n"
            "{\n"
            "  \"wave_name\": \"Embers at Southgate\",\n"
            "  \"tactic\": \"focus_weak_lane\",\n"
            "  \"event\": \"reinforcement_delay\",\n"
            "  \"enemies\": [\n"
            "    { \"type\": \"Grunt\",  \"lane\": \"south\", \"count\": 6 },\n"
            "    { \"type\": \"Archer\", \"lane\": \"south\", \"count\": 2 },\n"
            "    { \"type\": \"Runner\", \"lane\": \"east\",  \"count\": 3 },\n"
            "    { \"type\": \"Runner\", \"lane\": \"west\",  \"count\": 2 }\n"
            "  ],\n"
            "  \"director_note\": \"The south gate groans again...\"\n"
            "}")
build("06_json",
      "Under the hood, the director returns strict JSON: enemies per gate, a tactic, an event and a short note. "
      "Here the south gate fell, so the next wave leans on the south. A validator checks every field before the wave is played.",
      "card",
      draw=dt("Under the hood: one director call", 52, 70, color=GOLD)
           + dt(json_in, 30, 190, font=FONT_M, x="110")
           + dt(json_out, 30, 190, font=FONT_M, x="760")
           + dt("WaveValidator: enums, totals, day rules  ->  PASS  ->  played in game", 34, 880, color="0x78dc78"),
      )

build("07_teams",
      "Because it reads how you play, different teams get different games. "
      "A team that broke in the south faced seventy nine enemies there. A team that scattered was hit from the east and the west.",
      "card",
      draw=dt("Different teams get different games", 60, 150, color=GOLD)
           + dt("Same waves, two simulated teams (PC eval tools, same prompt + validator):\n\n"
                "Team A broke at the south gate   ->   79 enemies sent to the south gate\n"
                "Team B scattered                 ->   45 at the east gate, 32 at the west gate\n\n"
                "Director outputs passing schema + validator: 32 / 32\n"
                "Director outputs that would break a match: 0", 38, 330, font=FONT_R, x="200"))

build("08_memory", "After each match, the party's in-game events are saved, and Muse Spark turns them into memories.",
      "clip", start=120, tag="NPC MEMORY  |  Muse Spark 1.3")

build("09_day2",
      "On Day 2, the director remembers the south breach and opens at the south gate. "
      "And Bram and Mira greet you with lines written from that memory: the day, and the squad you chose.",
      "clip", start=150)

build("10_wavelines", "Their lines between waves come from the same memory.", "clip", start=177)

imgs = [(os.path.join(IMG, f"portrait_{n}.png"), x, 220, 300) for n, x in (("bram", 260), ("mira", 620), ("warlord", 980))]
for i, b in enumerate(["director", "fog", "elite", "reinforcement", "blood_moon"]):
    imgs.append((os.path.join(IMG, f"banner_{b}.png"), 140 + i * 340, 620, 300))
build("11_image",
      "The portraits and event banners were made with Muse Image during development. The keep and characters are built from Roblox parts.",
      "card",
      draw=dt("Art made with Muse Image", 56, 90, color=GOLD),
      images=imgs)

build("12_safety",
      "The match never stops. If the model times out or returns anything invalid, a fallback wave plays instead. "
      "Models are called only between waves, and every AI line is filtered and labeled.",
      "card",
      draw=dt("The match never stops", 60, 150, color=GOLD)
           + dt("wave ends  ->  match summary  ->  Muse Spark (strict JSON schema)\n"
                "           ->  validator (enums, totals, day rules)\n"
                "           ->  pass: play the AI wave\n"
                "           ->  timeout / HTTP error / bad JSON / rule break: play a fallback wave\n\n"
                "- Models are called only between waves, never during combat\n"
                "- Every AI line is filtered by TextService and labeled on screen\n"
                "- Memory stores in-game events only; the model sees party slots, not names",
                36, 320, font=FONT_R, x="180"))

build("13_built",
      "I built it solo during the hackathon, with Muse Code writing the game, and Claude Code writing specs, reviewing and testing in Studio.",
      "card",
      draw=dt("Built solo during the hackathon", 60, 170, color=GOLD)
           + dt("Babazz (human)  -  game design, decisions, live phone playtests\n"
                "Muse Code       -  implemented the game code and PC eval tools\n"
                "Claude Code     -  daily task specs, code review, Roblox Studio MCP tests\n\n"
                "Every line of code and every asset was made in the build window.", 38, 380, font=FONT_R, x="230"))

build("14_end", "Lantern Keep is playable on Roblox now. Thanks for watching.", "clip", start=108, min_dur=7,
      tag="Play on Roblox  |  github.com/jwbaba-ai/lantern-keep")

listfile = os.path.join(WORK, "list.txt")
with open(listfile, "w", encoding="utf-8") as f:
    for s in segments:
        f.write("file '" + s.replace("\\", "/") + "'\n")
ff(["-f", "concat", "-safe", "0", "-i", listfile, "-c", "copy", "-movflags", "+faststart", OUT])
print("done", OUT, f"{duration(OUT):.1f}s")
