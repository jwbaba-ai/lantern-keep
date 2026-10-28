-- Day 단계 규칙 (단일 기준: docs/tasks/day8.md 1단계).
-- 한 판은 Day 하나다. Day 1은 3웨이브, Day 2는 5, Day 3은 7,
-- Day 4는 9, Day 5 이상은 10웨이브. Day 6부터 적 체력·수가 늘어난다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DayRules = {}

-- Day의 웨이브 수. DayWaveCounts 범위를 넘으면 마지막 값을 쓴다.
function DayRules.waveCount(day)
	local counts = Config.DayWaveCounts
	local index = math.clamp(day or 1, 1, #counts)
	return counts[index]
end

-- 보스 웨이브인가. BossFromDay부터 마지막 웨이브에만 보스가 나온다.
function DayRules.isBossWave(day, wave)
	return (day or 0) >= Config.BossFromDay and wave == DayRules.waveCount(day)
end

-- Day 체력·수 배율. DayScaleFromDay 전날까지는 1이다.
function DayRules.scale(day)
	local fromDay = Config.DayScaleFromDay or 6
	if (day or 0) < fromDay then
		return { health = 1, count = 1 }
	end
	local offset = day - fromDay + 1
	local health = math.min(Config.DayHealthMax, 1 + Config.DayHealthStep * offset)
	local count = math.min(Config.DayCountMax, 1 + Config.DayCountStep * offset)
	return { health = health, count = count }
end

-- 계획 복사본의 적 count에 Day 수 배율을 곱한다 (올림).
-- 총합이 Config.MaxEnemies를 넘으면 비율을 유지하며 줄인다. 원본은 고치지 않는다.
function DayRules.scalePlan(plan, day)
	local mult = DayRules.scale(day).count
	local scaled = {
		wave_name = plan.wave_name,
		enemies = {},
		tactic = plan.tactic,
		event = plan.event,
		director_note = plan.director_note,
	}
	local total = 0
	for _, e in ipairs(plan.enemies) do
		local count = math.max(1, math.ceil(e.count * mult))
		table.insert(scaled.enemies, { type = e.type, count = count, lane = e.lane })
		total += count
	end
	if total > Config.MaxEnemies then
		local target = Config.MaxEnemies
		for _, e in ipairs(scaled.enemies) do
			e.count = math.max(1, math.floor(e.count * target / total))
		end
		local guard = 0
		while guard <= 1000 do
			local sum = 0
			for _, e in ipairs(scaled.enemies) do
				sum += e.count
			end
			local diff = target - sum
			if diff == 0 then
				break
			end
			guard += 1
			table.sort(scaled.enemies, function(a, b)
				return a.count > b.count
			end)
			if diff > 0 then
				scaled.enemies[1].count += 1
			else
				if scaled.enemies[1].count <= 1 then
					break -- 더 줄일 수 없으면 초과를 감수한다
				end
				scaled.enemies[1].count -= 1
			end
		end
	end
	return scaled
end

return DayRules
