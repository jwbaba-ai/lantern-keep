-- 파티 인원 보정 확인 (단일 기준: docs/tasks/day4.md 0-1.5).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Director["PartyScale.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다.
local DirectorFolder = script.Parent
local PartyScale = require(DirectorFolder:WaitForChild("PartyScale"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[PartyScale.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

local plan = {
	wave_name = "Scale Test",
	enemies = {
		{ type = "Grunt", count = 4, lane = "north" },
		{ type = "Brute", count = 1, lane = "south" },
		{ type = "Runner", count = 3, lane = "east" },
		{ type = "Archer", count = 3, lane = "west" },
	},
	tactic = "split_push",
	event = "none",
	director_note = "Party scale check.",
}
local originalTotal = 11 -- 4+1+3+3

-- 1인: 원래 합계의 약 절반, 각 항목 최소 1.
do
	local scaled, total = PartyScale.scalePlan(plan, 1)
	local allMinOne = true
	for _, e in ipairs(scaled.enemies) do
		if e.count < 1 then
			allMinOne = false
		end
	end
	-- 올림 합계는 ceil(원래 합계 * 0.5) 이상, 그 값 + 항목 수 이하.
	local lo = math.ceil(originalTotal * 0.5)
	local hi = lo + #plan.enemies
	check("solo_counts_halved", allMinOne and total >= lo and total <= hi)
end

-- 1인 체력 배율 0.6.
check("solo_health_scale", PartyScale.healthScale(1) == 0.6)

-- 4인: 원래와 같음.
do
	local scaled, total = PartyScale.scalePlan(plan, 4)
	local same = total == originalTotal
	for i, e in ipairs(scaled.enemies) do
		if e.count ~= plan.enemies[i].count then
			same = false
		end
	end
	check("fullparty_counts_same", same)
end

-- 4인 체력 배율 1.0.
check("fullparty_health_scale", PartyScale.healthScale(4) == 1.0)

return results
