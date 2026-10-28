-- DayRules 검사 (단일 기준: docs/tasks/day8.md 1단계).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Director["DayRules.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DirectorFolder = script.Parent
local DayRules = require(DirectorFolder:WaitForChild("DayRules"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[DayRules.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

local function close(a, b)
	return math.abs(a - b) < 1e-9
end

-- 1. waveCount 1~7 → 3,5,7,9,10,10,10.
do
	local got = {}
	for day = 1, 7 do
		table.insert(got, DayRules.waveCount(day))
	end
	local want = { 3, 5, 7, 9, 10, 10, 10 }
	local ok = true
	for i = 1, 7 do
		if got[i] ~= want[i] then
			ok = false
		end
	end
	check("wave_count_1_to_7", ok)
end

-- 2. isBossWave: (5,10)·(6,10) true / (4,9)·(5,9) false.
do
	check(
		"is_boss_wave",
		DayRules.isBossWave(5, 10) == true
			and DayRules.isBossWave(6, 10) == true
			and DayRules.isBossWave(4, 9) == false
			and DayRules.isBossWave(5, 9) == false
	)
end

-- 3. scale(5) = 1/1, scale(6) = 1.15/1.10, scale(30)은 상한(2.5/1.6).
do
	local s5 = DayRules.scale(5)
	local s6 = DayRules.scale(6)
	local s30 = DayRules.scale(30)
	check(
		"scale_values",
		close(s5.health, 1) and close(s5.count, 1)
			and close(s6.health, 1.15) and close(s6.count, 1.10)
			and close(s30.health, Config.DayHealthMax)
			and close(s30.count, Config.DayCountMax)
	)
end

-- 4. scalePlan 총합 ≤ MaxEnemies (Day 30, 큰 계획).
do
	local big = {
		wave_name = "Big",
		enemies = {
			{ type = "Grunt", count = 10, lane = "north" },
			{ type = "Runner", count = 10, lane = "south" },
			{ type = "Brute", count = 10, lane = "east" },
		},
		tactic = "siege",
		event = "none",
		director_note = "Big.",
	}
	local scaled = DayRules.scalePlan(big, 30)
	local total = 0
	for _, e in ipairs(scaled.enemies) do
		total += e.count
	end
	local originalTotal = 0
	for _, e in ipairs(big.enemies) do
		originalTotal += e.count
	end
	check(
		"scale_plan_capped",
		total <= Config.MaxEnemies and originalTotal == 30
	)
end

return results
