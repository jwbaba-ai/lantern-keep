"""Lantern Keep 3분 데모 영상 조립 (ffmpeg).
사용: python -I build_demo.py <repo_root> <out_mp4>
"""
import glob, os, subprocess, sys

ROOT = sys.argv[1]
OUT = sys.argv[2]
WORK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "demo_work")
os.makedirs(WORK, exist_ok=True)

SRC = glob.glob(os.path.join(ROOT, "vedios", "*2day*.mp4"))[0]
FONT = "C\\:/Windows/Fonts/arialbd.ttf"
FONT_R = "C\\:/Windows/Fonts/arial.ttf"
W, H = 1920, 1080
FPS = 30
BG = "0x0e1116"
GOLD = "0xffc83c"

def ff(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)

def textfile(name, text):
    p = os.path.join(WORK, name + ".txt")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return p.replace("\\", "/").replace(":", "\\:")

def dt(tf, size, y, color="white", font=FONT, box=False, x="(w-text_w)/2"):
    # 여러 줄은 줄마다 따로 그린다 (drawtext가 줄바꿈 자리에 빈 네모를 그리는 문제 회피).
    path = tf.replace("\\:", ":")
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    out = []
    for i, line in enumerate(lines):
        if line.strip() == "":
            continue
        lp = path[:-4] + f"_L{i}.txt"
        with open(lp, "w", encoding="utf-8", newline="\n") as f:
            f.write(line)
        ltf = lp.replace(":", "\\:")
        yy = f"({y})+{i * int(size * 1.45)}"
        s = f"drawtext=fontfile='{font}':textfile='{ltf}':fontsize={size}:fontcolor={color}:x={x}:y={yy}"
        if box:
            s += ":box=1:boxcolor=black@0.55:boxborderw=14"
        out.append(s)
    return ",".join(out)

ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-r", str(FPS),
       "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-ac", "2"]

segments = []

def clip(name, start, dur, subs, tag=None):
    """subs: [(t0, t1, text)] 구간 기준 시각. 영상은 1920x880, 위아래 100px 검은 띠, 자막은 아래 띠."""
    filters = [f"scale={W}:880", f"pad={W}:{H}:0:100:black"]
    if tag:
        filters.append(dt(textfile(name + "_tag", tag), 30, 34, color=GOLD))
    for i, (t0, t1, text) in enumerate(subs):
        tf = textfile(f"{name}_s{i}", text)
        filters.append(dt(tf, 34, "h-90+(90-text_h)/2-4") + f":enable='between(t,{t0},{t1})'")
    out = os.path.join(WORK, name + ".mp4")
    ff(["-ss", str(start), "-t", str(dur), "-i", SRC, "-vf", ",".join(filters),
        "-af", "volume=0.6"] + ENC + [out])
    segments.append(out)

def card(name, dur, draw, images=None):
    """draw: drawtext 필터 목록. images: [(path, x, y, w)]"""
    inputs = ["-f", "lavfi", "-i", f"color=c={BG}:s={W}x{H}:d={dur}:r={FPS}",
              "-f", "lavfi", "-i", f"anullsrc=r=44100:cl=stereo"]
    fc = []
    last = "[0:v]"
    for i, (path, x, y, w) in enumerate(images or []):
        inputs += ["-i", path]
        idx = i + 2
        fc.append(f"[{idx}:v]scale={w}:-1[im{i}]")
        fc.append(f"{last}[im{i}]overlay={x}:{y}[v{i}]")
        last = f"[v{i}]"
    chain = ",".join(draw + ["fade=t=in:st=0:d=0.4", f"fade=t=out:st={dur-0.4}:d=0.4"])
    fc.append(f"{last}{chain}[vout]")
    out = os.path.join(WORK, name + ".mp4")
    ff(inputs + ["-filter_complex", ";".join(fc), "-map", "[vout]", "-map", "1:a",
                 "-t", str(dur)] + ENC + [out])
    segments.append(out)

A = os.path.join(ROOT, "assets", "images")

# 1. 도입 전투
clip("01_hook", 18, 12, [(0.3, 11.8, "Lantern Keep - a 1-4 player co-op castle defense game on Roblox.")],
     tag="Live Roblox server, recorded on a phone")
# 2. 제목 카드
card("02_title", 7, [
    dt(textfile("02_t1", "LANTERN KEEP"), 96, 720, color=GOLD),
    dt(textfile("02_t2", "An AI director designs every wave.\nTwo companions remember how you played."), 40, 850),
], images=[(os.path.join(A, "thumbnail_16x9.png"), 560, 90, 800)])
# 3. 준비
clip("03_setup", 0, 8, [(0.2, 7.8, "Pick a class. Short on players? Vote for a support squad to fill the empty slots.")])
# 4. 첫 대사
clip("04_day1_lines", 8, 7, [(0.2, 6.8, "Day 1: the companions Bram and Mira know nothing about you yet - default lines.")])
# 5. 디렉터 ①
clip("05_director", 27, 18, [
    (0.2, 6.0, "Wave cleared. Between waves, Muse Spark 1.3 reads a summary of the last wave:"),
    (6.0, 11.5, "breached gates, damage, deaths and revives - and designs the next wave as strict JSON."),
    (11.5, 17.8, "The banner shows the AI wave: name, director's note, gate order. It is labeled as AI text."),
], tag="AI DIRECTOR  |  Muse Spark 1.3")
# 6. 두 팀 비교 카드
card("06_teams", 11, [
    dt(textfile("06_h", "Different teams get different games"), 60, 150, color=GOLD),
    dt(textfile("06_b",
        "Same waves, two simulated teams (PC eval tools, same prompt + validator):\n\n"
        "Team A broke at the south gate   ->   director sent 79 enemies to the south gate\n"
        "Team B scattered                 ->   45 at the east gate, 32 at the west gate\n\n"
        "Director outputs passing schema + validator: 32 / 32\n"
        "Director outputs that would break a match: 0"), 38, 330, font=FONT_R, x="200"),
])
# 7. 결과 화면 기억
clip("07_memory_saved", 120, 8, [(0.2, 7.8, "After the match, the party's in-game events are saved and summarized into memories.")],
     tag="NPC MEMORY  |  Muse Spark 1.3")
# 8. Day 2 시작: 디렉터 + NPC
clip("08_day2_open", 150, 11, [
    (0.0, 4.5, "Day 2. The director noticed the south gate broke - so the first wave opens at the south gate."),
    (4.5, 10.8, "Bram and Mira now remember: the day, the squad you voted for. Every AI line is labeled."),
])
# 9. 웨이브 중 대사
clip("09_wave_lines", 177, 5.5, [(0.2, 5.3, "Their lines between waves are generated from that memory too.")])
# 10. Muse Image
imgs = [(os.path.join(A, "portrait_bram.png"), 260, 220, 300),
        (os.path.join(A, "portrait_mira.png"), 620, 220, 300),
        (os.path.join(A, "portrait_warlord.png"), 980, 220, 300)]
bx = 140
for b in ["banner_director", "banner_fog", "banner_elite", "banner_reinforcement", "banner_blood_moon"]:
    imgs.append((os.path.join(A, b + ".png"), bx, 620, 300))
    bx += 340
card("10_image", 9, [
    dt(textfile("10_h", "Art made with Muse Image"), 56, 90, color=GOLD),
    dt(textfile("10_b", "Portraits and event banners were generated during development and uploaded as assets.\nNo runtime image generation. The keep and characters are built from Roblox primitives."), 32, 930, font=FONT_R),
], images=imgs)
# 11. 안전장치
card("11_safety", 12, [
    dt(textfile("11_h", "The match never stops"), 60, 150, color=GOLD),
    dt(textfile("11_b",
        "wave ends  ->  match summary  ->  Muse Spark (strict JSON schema)\n"
        "           ->  validator (enums, totals, day rules)\n"
        "           ->  pass: play the AI wave\n"
        "           ->  timeout / HTTP error / bad JSON / rule break: play a fallback wave\n\n"
        "- Models are called only between waves, never during combat\n"
        "- Every AI line is filtered by TextService and labeled on screen\n"
        "- Memory stores in-game events only; the model sees party slots, not names"), 36, 320, font=FONT_R, x="180"),
])
# 12. 만든 방법
card("12_built", 10, [
    dt(textfile("12_h", "Built solo during the hackathon"), 60, 170, color=GOLD),
    dt(textfile("12_b",
        "Babazz (human)  -  game design, decisions, live phone playtests\n"
        "Muse Code       -  implemented the game code and PC eval tools\n"
        "Claude Code     -  daily task specs, code review, Roblox Studio MCP tests\n\n"
        "Every line of code and every asset was made in the build window."), 38, 380, font=FONT_R, x="230"),
])
# 13. 끝
clip("13_end", 108, 9, [(0.2, 8.8, "Play Lantern Keep on Roblox  |  github.com/jwbaba-ai/lantern-keep")])

listfile = os.path.join(WORK, "list.txt")
with open(listfile, "w", encoding="utf-8") as f:
    for s in segments:
        f.write("file '" + s.replace("\\", "/") + "'\n")
ff(["-f", "concat", "-safe", "0", "-i", listfile, "-c", "copy", "-movflags", "+faststart", OUT])
print("done", OUT)
