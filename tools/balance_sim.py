"""밸런스 시뮬레이터 (모델 호출 없음, 표준 라이브러리만 사용).

수치는 Luau 파일에서 정규식으로 읽는다. 숫자를 코드에 다시 적지 않는다.
  - 적: EnemyCatalog.luau (Health, Speed, LanternDamage)
  - 직업: ClassCatalog.luau (피해, 쿨다운)
  - 파티 배율·등불 체력: Config.luau (PartyCountScale, PartyHealthScale, LanternMaxHealth)
  - 대체 웨이브: FallbackWaves.luau
  - 레인 길이: MapBuilder.server.luau (GATE_DISTANCE, SPAWN_DISTANCE)

Day 규칙은 docs/tasks/day8.md 값을 기본 인자로 둔다. day8이 Config에 키를
넣은 뒤에는 Config에서 읽도록 TODO 주석을 남긴다.
TODO(day8): DayWaveCounts, DayHealthStep, DayCountStep, BossFromDay 등이
  Config.luau에 들어가면 아래 argparse 기본값을 Config에서 읽게 바꾼다.

모델(단순하게):
  - 플레이어는 성문 하나씩 맡는다(인원이 적으면 적이 많은 성문 우선).
  - 직업 초당 피해 = 피해 / 쿨다운 × 효율. cleric은 근접 공격 피해(AttackDamage)를 쓴다.
  - 효율은 판마다 0.4~0.8에서 무작위로 정한다(--seed).
  - 적이 레인을 걷는 동안 처치되지 못하면 등불에 LanternDamage를 준다.

사용법:
  python tools/balance_sim.py --matches 300 --seed 7
  python tools/balance_sim.py --self-test
"""
import argparse
import math
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LANES = ("north", "south", "east", "west")
# 시뮬레이터 고정 직업 순서(DPS 순 아님, 파티 구성용). 1~4인은 앞부터 둔다.
PARTY_ORDER = ("guardian", "ranger", "arcanist", "cleric")


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def num_in(text, key):
    m = re.search(r"\b" + key + r"\s*=\s*([\d.]+)", text)
    if not m:
        raise ValueError("%s를 찾지 못함" % key)
    return float(m.group(1))


def numlist_in(text, key):
    m = re.search(r"\b" + key + r"\s*=\s*\{([^}]*)\}", text)
    if not m:
        raise ValueError("%s를 찾지 못함" % key)
    return [float(x) for x in re.findall(r"[\d.]+", m.group(1))]


def sectioned(src):
    """최상위 `name = { ... }` 블록을 이름별로 나눈다(중첩 한 단계까지)."""
    out = {}
    cur = None
    depth = 0
    for line in src.splitlines():
        m = re.match(r"^(\w+)\s*=\s*\{\s*$", line.strip())
        if m and depth == 0:
            cur = m.group(1)
            out[cur] = []
            depth = 1
            continue
        if cur is not None:
            out[cur].append(line)
            depth += line.count("{") - line.count("}")
            if depth <= 0:
                cur = None
                depth = 0
    return {k: "\n".join(v) for k, v in out.items()}


def load_enemies():
    secs = sectioned(load("src/shared/EnemyCatalog.luau"))
    enemies = {}
    for name, body in secs.items():
        enemies[name] = {
            "health": num_in(body, "Health"),
            "speed": num_in(body, "Speed"),
            "damage": num_in(body, "LanternDamage"),
        }
    return enemies


def load_classes():
    secs = sectioned(load("src/shared/ClassCatalog.luau"))
    classes = {}
    for name, body in secs.items():
        dmg_m = re.search(r"\bDamage\s*=\s*([\d.]+)", body)
        atk_m = re.search(r"\bAttackDamage\s*=\s*([\d.]+)", body)
        dmg = float((dmg_m or atk_m).group(1))
        classes[name] = {
            "dps": dmg / num_in(body, "Cooldown"),
        }
    return classes


def load_config():
    src = load("src/shared/Config.luau")
    return {
        "lantern": num_in(src, "LanternMaxHealth"),
        "count_scale": numlist_in(src, "PartyCountScale"),
        "health_scale": numlist_in(src, "PartyHealthScale"),
    }


def load_fallback_waves():
    """FallbackWaves.luau의 웨이브별 적 목록. wave_name 순서대로 1번부터."""
    src = load("src/shared/FallbackWaves.luau")
    names = [m.group(1) for m in re.finditer(r'wave_name\s*=\s*"([^"]+)"', src)]
    chunks = re.split(r'wave_name\s*=\s*"[^"]+"', src)[1:]
    waves = []
    for name, chunk in zip(names, chunks):
        entries = []
        for m in re.finditer(
                r'\{\s*type\s*=\s*"(\w+)"\s*,\s*count\s*=\s*(\d+)\s*,\s*lane\s*=\s*"(\w+)"\s*\}', chunk):
            entries.append({"type": m.group(1), "count": int(m.group(2)), "lane": m.group(3)})
        waves.append({"wave_name": name, "enemies": entries})
    return waves


def load_lane_walk():
    """적 이동 거리 = (스폰→성문) + (성문→등불 앞). MapBuilder 상수에서 계산한다."""
    src = load("src/server/World/MapBuilder.server.luau")
    gate = num_in(src, "GATE_DISTANCE")
    spawn = num_in(src, "SPAWN_DISTANCE")
    return (spawn - gate) + (gate - 6)


def day_scale(day, args):
    """Day 5까지는 1. 그 뒤로 체력·수가 단계적으로 는다(day8.md 규칙)."""
    if day <= 5:
        return 1.0, 1.0
    h = min(args.day_health_max, 1 + args.health_step * (day - 5))
    c = min(args.day_count_max, 1 + args.count_step * (day - 5))
    return h, c


def build_wave(wave_idx, day, party_n, args, data):
    """대체 웨이브 + 파티 배율 + Day 배율 + (Day 5~ 마지막 웨이브 보스)을 적용한 적 목록."""
    base = data["waves"][min(wave_idx, len(data["waves"])) - 1]
    c_scale = data["cfg"]["count_scale"][min(party_n, len(data["cfg"]["count_scale"])) - 1]
    h_scale = data["cfg"]["health_scale"][min(party_n, len(data["cfg"]["health_scale"])) - 1]
    day_h, day_c = day_scale(day, args)
    lanes = {lane: [] for lane in LANES}
    for e in base["enemies"]:
        st = data["enemies"][e["type"]]
        n = max(1, math.ceil(e["count"] * c_scale * day_c))
        hp = st["health"] * h_scale * day_h
        for _ in range(n):
            lanes[e["lane"]].append({"hp": hp, "speed": st["speed"], "damage": st["damage"]})
    if day >= args.boss_from_day and wave_idx == args.day_waves[min(day, len(args.day_waves)) - 1]:
        brute = data["enemies"]["Brute"]
        busy = max(LANES, key=lambda lane: sum(x["hp"] for x in lanes[lane]))
        lanes[busy].append({"hp": brute["health"] * args.boss_hp_mult * h_scale * day_h,
                            "speed": brute["speed"], "damage": brute["damage"]})
    return lanes


def resolve_lane(enemies, dps, walk):
    """수비수 1명이 도착 순서대로 처치한다. 막지 못한 적은 등불 피해를 돌려준다."""
    if dps <= 0:
        return sum(e["damage"] for e in enemies)
    leak = 0.0
    clock = 0.0
    for e in sorted(enemies, key=lambda x: (walk / x["speed"], -x["hp"])):
        clock += e["hp"] / dps
        if clock > walk / e["speed"]:
            leak += e["damage"]
    return leak


def play_match(day, party_n, efficiency, args, data):
    """Day 1판(웨이브 수만큼)을 돌린다. (생존 여부, 남은 체력)을 돌려준다."""
    dps_list = sorted([data["classes"][c]["dps"] for c in PARTY_ORDER[:party_n]], reverse=True)
    waves = args.day_waves[min(day, len(args.day_waves)) - 1]
    health = data["cfg"]["lantern"]
    for wave_idx in range(1, waves + 1):
        lanes = build_wave(wave_idx, day, party_n, args, data)
        busy = sorted(LANES, key=lambda lane: (-len(lanes[lane]), lane))
        for idx, lane in enumerate(busy):
            if idx < len(dps_list):
                leak = resolve_lane(lanes[lane], dps_list[idx] * efficiency, data["walk"])
            else:
                # 수비수가 없는 성문은 적이 모두 등불까지 닿는다.
                leak = sum(e["damage"] for e in lanes[lane])
            health -= leak
            if health <= 0:
                return False, 0.0
    return True, health


def target_band(day):
    if day <= 2:
        return (85, 100)
    if day <= 4:
        return (60, 85)
    if day == 5:
        return (40, 70)
    return (0, 40)


def run(args):
    data = {
        "enemies": load_enemies(),
        "classes": load_classes(),
        "cfg": load_config(),
        "waves": load_fallback_waves(),
        "walk": load_lane_walk(),
    }
    rng = random.Random(args.seed)
    days = range(1, args.max_day + 1)
    table = {}
    for day in days:
        for party_n in range(1, 5):
            wins = 0
            left_sum = 0.0
            for _ in range(args.matches):
                eff = args.efficiency if args.efficiency else rng.uniform(0.4, 0.8)
                ok, left = play_match(day, party_n, eff, args, data)
                wins += 1 if ok else 0
                left_sum += left
            table[(day, party_n)] = (100.0 * wins / args.matches, left_sum / args.matches)

    lines = []
    lines.append("# 밸런스 시뮬레이션")
    lines.append("")
    lines.append("## 가정과 한계 (먼저 읽는다)")
    lines.append("")
    lines.append("- 대체 웨이브(FallbackWaves)만 쓴다. 디렉터가 만드는 어려운 웨이브는 이보다 세다.")
    lines.append("- 플레이어는 성문 하나씩 맡고, 인원이 적으면 적이 많은 성문부터 맡는다. 협동·이동·부활은 없다.")
    lines.append("- 적은 스폰 지점에서 등불까지 쉬지 않고 걷는다(중간 교전·발묶기 없음). 이동 거리는 MapBuilder 상수에서 계산했다.")
    lines.append("- 수비수는 도착 순서대로 한 마리씩 처치한다. 원거리 적의 반격, Shaman 치유, 직업 상성은 무시한다.")
    lines.append("- cleric은 근접 공격 피해로만 계산한다(치유·부활 없음). 효율은 판마다 0.4~0.8에서 무작위다.")
    lines.append("- 웨이브 8~10 대체 웨이브가 아직 없어 7웨이브 구성을 그대로 쓴다. 보스는 Brute 수치에 체력만 %s배로 둔다."
                 % args.boss_hp_mult)
    lines.append("")
    lines.append("- 설정: Day별 웨이브 %s, Day %d부터 마지막 웨이브 보스, Day 6~ 체력 +%d%%·수 +%d%%/Day, seed %d, %d판씩"
                 % (list(args.day_waves), args.boss_from_day,
                    round(args.health_step * 100), round(args.count_step * 100),
                    args.seed, args.matches))
    lines.append("")
    lines.append("## 등불 생존율 (평균 남은 체력)")
    lines.append("")
    lines.append("| Day | 1인 | 2인 | 3인 | 4인 | 목표 |")
    lines.append("|---|---|---|---|---|---|")
    for day in days:
        lo, hi = target_band(day)
        if day <= 2:
            goal = "85% 이상"
        elif day <= 4:
            goal = "60~85%"
        elif day == 5:
            goal = "40~70%"
        else:
            goal = "점점 하락"
        cells = []
        for party_n in range(1, 5):
            pct, left = table[(day, party_n)]
            mark = "" if lo <= pct <= hi else " ※"
            cells.append("%.0f%% (%.0f)%s" % (pct, left, mark))
        lines.append("| %d | %s | %s |" % (day, " | ".join(cells), goal))
    lines.append("")
    lines.append("※ = 목표 구간 밖. 아래 조정 제안을 day8 반영 후보로 고른다(적용은 하지 않는다).")
    lines.append("")
    out = os.path.join(ROOT, "docs", "reports", "balance_sim.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("보고서: %s" % os.path.relpath(out, ROOT).replace(os.sep, "/"))
    for day in days:
        row = "Day %d:" % day
        for party_n in range(1, 5):
            pct, left = table[(day, party_n)]
            row += " %d인 %.0f%%(%.0f)" % (party_n, pct, left)
        print(row)
    return table


def self_test(args):
    data = {
        "enemies": load_enemies(),
        "classes": load_classes(),
        "cfg": load_config(),
        "waves": load_fallback_waves(),
        "walk": load_lane_walk(),
    }
    results = []
    for eff, want in ((1.0, 100.0), (0.0, 0.0)):
        wins = sum(1 for _ in range(20) if play_match(1, 4, eff, args, data)[0])
        pct = 100.0 * wins / 20
        ok = pct == want
        results.append(ok)
        print("%s: Day 1 / 4인 / 효율 %.1f → 승률 %.0f%% (기대 %.0f%%)"
              % ("PASS" if ok else "FAIL", eff, pct, want))
    return all(results)


def main(argv):
    ap = argparse.ArgumentParser(description="밸런스 시뮬레이터 (모델 호출 없음)")
    ap.add_argument("--matches", type=int, default=300)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--max-day", type=int, default=8)
    ap.add_argument("--day-waves", type=int, nargs="+", default=[3, 5, 7, 9, 10])
    ap.add_argument("--health-step", type=float, default=0.15)
    ap.add_argument("--count-step", type=float, default=0.10)
    ap.add_argument("--day-health-max", type=float, default=2.5)
    ap.add_argument("--day-count-max", type=float, default=1.6)
    ap.add_argument("--boss-from-day", type=int, default=5)
    ap.add_argument("--boss-hp-mult", type=float, default=8.0)
    ap.add_argument("--efficiency", type=float, default=0.0,
                    help="0이면 판마다 0.4~0.8 무작위, 아니면 고정 효율")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)
    if args.self_test:
        sys.exit(0 if self_test(args) else 1)
    run(args)


if __name__ == "__main__":
    main(sys.argv[1:])
