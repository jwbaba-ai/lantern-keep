-- 웨이브 이벤트 효과 (단일 기준: docs/GAME_DESIGN.md 이벤트 효과).
-- 웨이브 시작 때 apply, 끝나면 clear로 원래 값으로 되돌린다.
-- elite_spawn의 첫 적 강화와 blood_moon 체력 배율은 스폰 수정값으로 돌려주고,
-- 실제 적용은 EnemyFactory.spawn(mods)이 한다.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local EventEffects = {}

-- fog 농도 (Atmosphere가 있으면 FogStart/FogEnd 대신 이 값을 쓴다.
-- Roblox는 Atmosphere가 있을 때 Fog 값을 무시하기 때문이다).
-- 기준 0.3은 MapDecor.applyLighting이 정한 밤 밀도다.
EventEffects.FogAtmosphereDensity = 0.65
EventEffects.BaseAtmosphereDensity = 0.3
EventEffects.BloodMoonAmbient = Color3.fromRGB(140, 30, 30)
EventEffects.BloodMoonOutdoorAmbient = Color3.fromRGB(90, 25, 25)

local saved = nil -- apply 때 저장한 원래 조명 값

-- 순수: fog이 건드리는 값. Atmosphere가 있으면 Density를, 없으면 FogEnd를 쓴다.
function EventEffects.fogPlan(hasAtmosphere)
	if hasAtmosphere then
		return {
			key = "Density",
			apply = EventEffects.FogAtmosphereDensity,
			restore = EventEffects.BaseAtmosphereDensity,
		}
	end
	return { key = "FogEnd", apply = Config.FogEndDuringEvent }
end

-- 순수: blood_moon이 저장·복원하는 Lighting 키 목록.
function EventEffects.bloodMoonKeys()
	return { "Ambient", "OutdoorAmbient" }
end

-- 웨이브 시작 때 부르는 전역 효과. 스폰 공통 수정값을 돌려준다.
function EventEffects.apply(event)
	EventEffects.clear()
	if event == "fog" then
		local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmo then
			saved = { AtmosphereDensity = atmo.Density }
			atmo.Density = EventEffects.FogAtmosphereDensity
		else
			saved = { FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd }
			Lighting.FogEnd = Config.FogEndDuringEvent
		end
	elseif event == "blood_moon" then
		saved = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
		Lighting.Ambient = EventEffects.BloodMoonAmbient
		Lighting.OutdoorAmbient = EventEffects.BloodMoonOutdoorAmbient
	end
	local healthMult = 1
	if event == "blood_moon" then
		healthMult = 1.5
	end
	return { healthMult = healthMult, elitePending = (event == "elite_spawn") }
end

-- 적 스폰 간격. reinforcement_delay면 2배.
function EventEffects.spawnInterval(event, base)
	if event == "reinforcement_delay" then
		return base * 2
	end
	return base
end

-- 다음에 스폰할 적 1마리의 수정값. elite는 첫 1마리만 크기·체력 2배.
function EventEffects.nextSpawnMods(waveMods)
	local mods = { healthMult = waveMods.healthMult }
	if waveMods.elitePending then
		waveMods.elitePending = false
		mods.healthMult *= 2
		mods.sizeMult = 2
		mods.namePrefix = "정예 "
	end
	return mods
end

-- 웨이브 종료: 조명을 원래 값으로 되돌린다.
function EventEffects.clear()
	if not saved then
		return
	end
	if saved.AtmosphereDensity ~= nil then
		local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmo then
			local density = saved.AtmosphereDensity
			pcall(function()
				atmo.Density = density
			end)
		end
	else
		for k, v in pairs(saved) do
			pcall(function()
				Lighting[k] = v
			end)
		end
	end
	saved = nil
end

return EventEffects
