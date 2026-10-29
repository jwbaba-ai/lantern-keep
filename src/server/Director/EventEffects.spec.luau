-- EventEffects 검사 (단일 기준: docs/tasks/day11.md 4단계).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Director["EventEffects.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DirectorFolder = script.Parent
local EventEffects = require(DirectorFolder:WaitForChild("EventEffects"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[EventEffects.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

local function close(a, b)
	return math.abs(a - b) < 1e-9
end

-- 1. Atmosphere 있음 + fog -> Density 0.65, 종료 -> 0.3.
do
	local plan = EventEffects.fogPlan(true)
	check(
		"fog_plan_atmosphere",
		plan.key == "Density" and close(plan.apply, 0.65) and close(plan.restore, 0.3)
	)
end

-- 2. Atmosphere 없음 + fog -> FogEnd를 쓴다.
do
	local plan = EventEffects.fogPlan(false)
	check(
		"fog_plan_no_atmosphere",
		plan.key == "FogEnd" and plan.apply == Config.FogEndDuringEvent
	)
end

-- 3. blood_moon은 Ambient와 OutdoorAmbient를 함께 저장·복원한다.
do
	local keys = EventEffects.bloodMoonKeys()
	local hasAmbient, hasOutdoor = false, false
	for _, k in ipairs(keys) do
		if k == "Ambient" then
			hasAmbient = true
		elseif k == "OutdoorAmbient" then
			hasOutdoor = true
		end
	end
	check("blood_moon_keys", hasAmbient and hasOutdoor)
end

-- 4. fog 왕복: 적용 중 0.65(또는 FogEnd), clear 뒤 원래 값으로 돌아간다.
do
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local beforeDensity = atmo and atmo.Density or nil
	local beforeFogEnd = Lighting.FogEnd
	EventEffects.apply("fog")
	local midOk = false
	if atmo then
		midOk = close(atmo.Density, 0.65)
	else
		midOk = Lighting.FogEnd == Config.FogEndDuringEvent
	end
	EventEffects.clear()
	local backOk = false
	local atmoNow = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		backOk = atmoNow ~= nil and close(atmoNow.Density, beforeDensity)
	else
		backOk = Lighting.FogEnd == beforeFogEnd
	end
	check("fog_round_trip", midOk and backOk)
end

-- 5. blood_moon 왕복: 적용 중 붉은 조명, clear 뒤 원래 값으로 돌아간다.
do
	local beforeAmbient = Lighting.Ambient
	local beforeOutdoor = Lighting.OutdoorAmbient
	EventEffects.apply("blood_moon")
	local midOk = Lighting.Ambient == EventEffects.BloodMoonAmbient
		and Lighting.OutdoorAmbient == EventEffects.BloodMoonOutdoorAmbient
	EventEffects.clear()
	local backOk = Lighting.Ambient == beforeAmbient
		and Lighting.OutdoorAmbient == beforeOutdoor
	check("blood_moon_round_trip", midOk and backOk)
end

return results
