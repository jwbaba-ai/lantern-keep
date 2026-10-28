-- DirectorState 필드 구성 검사 (단일 기준: docs/tasks/day4.md 6단계).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Director["DirectorState.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FallbackWaves = require(Shared:WaitForChild("FallbackWaves"))

local DirectorFolder = script.Parent
local DirectorState = require(DirectorFolder:WaitForChild("DirectorState"))
local PartyScale = require(DirectorFolder:WaitForChild("PartyScale"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[DirectorState.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

local function totalOf(plan)
	local sum = 0
	for _, e in ipairs(plan.enemies) do
		sum += e.count
	end
	return sum
end

local musePlan = {
	wave_name = "Eyes on the North",
	enemies = {
		{ type = "Grunt", count = 6, lane = "north" },
		{ type = "Runner", count = 4, lane = "east" },
	},
	tactic = "focus_weak_lane",
	event = "fog",
	director_note = "They saw the north hold and press it.",
}
local fallbackPlan = FallbackWaves[3]
local identityFilter = function(text)
	return text
end
-- 필터를 쓸 수 없을 때(플레이어 없음)를 재현하는 실패 필터.
local failingFilter = function(_text)
	error("no filter available")
end

-- 1. 필수 필드가 모두 있음.
do
	local data = DirectorState.buildState({
		phase = "wave",
		displayWave = 3,
		source = "muse",
		plan = musePlan,
		waveName = musePlan.wave_name,
		directorNote = musePlan.director_note,
		intermissionEndsAt = 0,
		filterFn = identityFilter,
	})
	local hasAll = data.phase ~= nil
		and data.display_wave ~= nil
		and data.display_name ~= nil
		and data.display_note ~= nil
		and data.lanes ~= nil
		and data.intermission_ends_at ~= nil
	check("required_fields_present", hasAll)
end

-- 2. lanes 합계 = plan.enemies의 count 합계.
do
	local data = DirectorState.buildState({
		phase = "wave",
		displayWave = 3,
		source = "muse",
		plan = musePlan,
		waveName = musePlan.wave_name,
		directorNote = musePlan.director_note,
		intermissionEndsAt = 0,
		filterFn = identityFilter,
	})
	local sum = (data.lanes.north or 0)
		+ (data.lanes.south or 0)
		+ (data.lanes.east or 0)
		+ (data.lanes.west or 0)
	check("lanes_match_plan_total", sum == totalOf(musePlan))
end

-- 3. 필터를 쓸 수 없으면 display가 FallbackWaves 글자와 같음.
do
	local data = DirectorState.buildState({
		phase = "intermission",
		displayWave = 3,
		source = "fallback",
		plan = fallbackPlan,
		waveName = fallbackPlan.wave_name,
		directorNote = fallbackPlan.director_note,
		intermissionEndsAt = 123.0,
		filterFn = failingFilter,
	})
	check(
		"fallback_text_without_filter",
		data.display_name == fallbackPlan.wave_name
			and data.display_note == fallbackPlan.director_note
	)
end

-- 4. 설계 중 상태: 고정 문구 + 빈 성문.
do
	local data = DirectorState.buildState({
		phase = "intermission",
		displayWave = 4,
		source = "pending",
		plan = nil,
		waveName = nil,
		directorNote = nil,
		intermissionEndsAt = 456.0,
		filterFn = failingFilter,
	})
	local lanesEmpty = (data.lanes.north or -1) == 0
		and (data.lanes.south or -1) == 0
		and (data.lanes.east or -1) == 0
		and (data.lanes.west or -1) == 0
	check(
		"designing_state",
		data.display_name == DirectorState.DESIGNING_TEXT and lanesEmpty
	)
end

-- 5. 보정한 plan을 넘기면 lanes 합계 = 보정 합계.
do
	local scaled = PartyScale.scalePlan(musePlan, 1)
	local data = DirectorState.buildState({
		phase = "intermission",
		displayWave = 3,
		source = "muse",
		plan = scaled,
		waveName = musePlan.wave_name,
		directorNote = musePlan.director_note,
		intermissionEndsAt = 0,
		filterFn = identityFilter,
	})
	local sum = (data.lanes.north or 0)
		+ (data.lanes.south or 0)
		+ (data.lanes.east or 0)
		+ (data.lanes.west or 0)
	check("scaled_plan_lanes_match", sum == totalOf(scaled))
end

-- 6. 결과 상태: 고정 문구 + 결과 필드.
do
	local data = DirectorState.buildState({
		phase = "result",
		displayWave = 7,
		source = "muse",
		plan = nil,
		waveName = nil,
		directorNote = nil,
		intermissionEndsAt = 789.0,
		filterFn = failingFilter,
		result = "victory",
		wavesCompleted = 7,
		lanternHealthPct = 62,
	})
	check(
		"result_state",
		data.display_name == "승리!"
			and data.result == "victory"
			and data.waves_completed == 7
			and data.lantern_health_pct == 62
			and string.find(data.display_note, "7웨이브 중 7웨이브 생존") ~= nil
	)
end

-- 7. 로비: 플레이어 0명(필터 실패)에도 고정 문구가 그대로 나옴.
do
	local data = DirectorState.buildState({
		phase = "lobby",
		displayWave = 1,
		source = "pending",
		plan = nil,
		waveName = "곧 시작합니다",
		directorNote = "",
		intermissionEndsAt = 123.0,
		filterFn = failingFilter,
	})
	check(
		"lobby_fixed_text_without_filter",
		data.display_name == "곧 시작합니다"
	)
end

return results
