-- 디렉터가 만든 웨이브 계획을 검증·보정하는 모듈.
-- validate(plan, waveNumber) -> ok, cleanPlan, errors
--   ok=true  : 적용해도 된다. errors가 비어 있지 않으면 자동 보정했다는 뜻(경고).
--   ok=false : 구조·enum이 망가져 쓸 수 없다. cleanPlan은 nil, 호출한 쪽이 대체 웨이브를 쓴다.
-- 자동 보정(통과): 총합이 MinEnemies~MaxEnemies 밖이면 비율 유지하며 맞춤,
--   blood_moon이 BloodMoonMinWave보다 이른 웨이브면 event를 none으로 교체.
-- Config 값은 src/shared/Config.luau 단일 기준을 따른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local WaveValidator = {}

local function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

local function isPositiveInteger(n)
	return type(n) == "number" and n >= 1 and math.floor(n) == n
end

-- 총합을 target에 맞춘다. 비율 유지 + 최소 1마리 보장 후 나머지를 큰 항목부터 분배.
local function scaleCounts(entries, target)
	local total = 0
	for _, e in ipairs(entries) do
		total += e.count
	end
	if total == target then
		return
	end
	for _, e in ipairs(entries) do
		e.count = math.max(1, math.floor(e.count * target / total))
	end
	local guard = 0
	while true do
		local sum = 0
		for _, e in ipairs(entries) do
			sum += e.count
		end
		local diff = target - sum
		if diff == 0 or guard > 1000 then
			break
		end
		guard += 1
		table.sort(entries, function(a, b)
			return a.count > b.count
		end)
		if diff > 0 then
			entries[1].count += 1
		else
			if entries[1].count <= 1 then
				break -- 더 줄일 수 없으면 초과를 감수한다
			end
			entries[1].count -= 1
		end
	end
end

function WaveValidator.validate(plan, waveNumber)
	local errors = {}

	if type(plan) ~= "table" then
		return false, nil, { "plan은 object여야 한다" }
	end
	if type(plan.wave_name) ~= "string" or plan.wave_name == "" then
		return false, nil, { "wave_name이 비었다" }
	end
	if type(plan.enemies) ~= "table" or #plan.enemies == 0 then
		return false, nil, { "enemies가 비었다" }
	end
	if not contains(Config.Tactics, plan.tactic) then
		return false, nil, { "tactic이 허용 목록에 없다: " .. tostring(plan.tactic) }
	end
	if not contains(Config.Events, plan.event) then
		return false, nil, { "event가 허용 목록에 없다: " .. tostring(plan.event) }
	end
	if type(plan.director_note) ~= "string" or plan.director_note == "" then
		return false, nil, { "director_note가 비었다" }
	end
	for i, e in ipairs(plan.enemies) do
		if type(e) ~= "table" then
			return false, nil, { "enemies[" .. i .. "]가 object가 아니다" }
		end
		if not contains(Config.EnemyTypes, e.type) then
			return false, nil, { "enemies[" .. i .. "].type이 허용 목록에 없다: " .. tostring(e.type) }
		end
		if not contains(Config.Lanes, e.lane) then
			return false, nil, { "enemies[" .. i .. "].lane이 허용 목록에 없다: " .. tostring(e.lane) }
		end
		if not isPositiveInteger(e.count) then
			return false, nil, { "enemies[" .. i .. "].count는 1 이상의 정수여야 한다: " .. tostring(e.count) }
		end
	end

	-- 여기부터는 보정 가능한 항목. cleanPlan에만 손댄다(원본은 그대로).
	local clean = {
		wave_name = plan.wave_name,
		enemies = {},
		tactic = plan.tactic,
		event = plan.event,
		director_note = plan.director_note,
	}
	for _, e in ipairs(plan.enemies) do
		table.insert(clean.enemies, { type = e.type, count = e.count, lane = e.lane })
	end

	local total = 0
	for _, e in ipairs(clean.enemies) do
		total += e.count
	end
	if total < Config.MinEnemies then
		scaleCounts(clean.enemies, Config.MinEnemies)
		table.insert(errors, "총합 " .. total .. "마리 < 최소 " .. Config.MinEnemies .. "마리: 비율 유지하며 증량")
	elseif total > Config.MaxEnemies then
		scaleCounts(clean.enemies, Config.MaxEnemies)
		table.insert(errors, "총합 " .. total .. "마리 > 최대 " .. Config.MaxEnemies .. "마리: 비율 유지하며 감량")
	end

	if clean.event == "blood_moon" and (type(waveNumber) ~= "number" or waveNumber < Config.BloodMoonMinWave) then
		clean.event = "none"
		table.insert(errors, "blood_moon은 " .. Config.BloodMoonMinWave .. "웨이브부터: none으로 교체")
	end

	return true, clean, errors
end

return WaveValidator
