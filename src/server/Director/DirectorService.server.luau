-- 경기 흐름 (단일 기준: docs/GAME_DESIGN.md 한 판의 흐름).
-- 웨이브 1~TotalWaves 반복: 진행 -> 종료 -> 요약 -> 대기 시작과 동시에 다음 웨이브 요청.
-- 통과한 계획은 적용하고, 실패(nil·검증 실패)하면 FallbackWaves를 쓴다. 경기는 절대 멈추지 않는다.
-- 이벤트는 2일차에 Output 로그만 남긴다 (효과는 4일차).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FallbackWaves = require(Shared:WaitForChild("FallbackWaves"))

local DirectorFolder = script.Parent
local DirectorClient = require(DirectorFolder:WaitForChild("DirectorClient"))
local WaveValidator = require(DirectorFolder:WaitForChild("WaveValidator"))
local DirectorState = require(DirectorFolder:WaitForChild("DirectorState"))
local PartyScale = require(DirectorFolder:WaitForChild("PartyScale"))
local MatchStats = require(DirectorFolder:WaitForChild("MatchStats"))
local EnemyFactory = require(DirectorFolder.Parent:WaitForChild("Enemies"):WaitForChild("EnemyFactory"))
local CombatService = require(DirectorFolder.Parent:WaitForChild("Combat"):WaitForChild("CombatService"))

local SPAWN_INTERVAL = 1.0 -- 적 한 마리씩 꺼내는 간격(초)
local WAVE_TIMEOUT = 180 -- 웨이브 강제 종료까지 최대 대기(초)

local function lanternHealth(lantern)
	return lantern:GetAttribute("Health") or 0
end

local function lanternHealthPct(lantern)
	return math.floor(lanternHealth(lantern) / Config.LanternMaxHealth * 100 + 0.5)
end

local function logPlan(wave, source, plan)
	print(string.format(
		"[Director] wave=%d source=%s tactic=%s event=%s note=%s",
		wave,
		source,
		plan.tactic,
		plan.event,
		plan.director_note
	))
end

-- 대기 종료 시각 (workspace:GetServerTimeNow() 기준, 전투 중에는 0).
local function intermissionEndsAt(secondsLeft)
	return Workspace:GetServerTimeNow() + math.max(0, secondsLeft)
end

local function getWaypoints(map, lane)
	local folder = map:WaitForChild("Lanes"):WaitForChild(lane)
	local parts = {}
	for _, p in ipairs(folder:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	table.sort(parts, function(a, b)
		return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
	end)
	local points = {}
	for _, p in ipairs(parts) do
		table.insert(points, p.Position)
	end
	return points
end

-- 웨이브 하나를 끝까지 진행하고 통계를 돌려준다.
local function playWave(map, lantern, wave, plan)
	local tracker = MatchStats.new()
	CombatService.beginWave(tracker)
	local waypointsByLane = {}
	for _, lane in ipairs(Config.Lanes) do
		waypointsByLane[lane] = getWaypoints(map, lane)
	end

	local bodies = {}
	local function onResolved(_type, lane, how)
		MatchStats.recordResolved(tracker, lane, how)
	end

	for _, entry in ipairs(plan.enemies) do
		for _ = 1, entry.count do
			if lanternHealth(lantern) <= 0 then
				break
			end
			local body = EnemyFactory.spawn(
				entry.type,
				entry.lane,
				waypointsByLane[entry.lane],
				lantern,
				onResolved
			)
			if body then
				MatchStats.recordSpawn(tracker, entry.lane)
				table.insert(bodies, body)
			end
			task.wait(SPAWN_INTERVAL)
		end
		if lanternHealth(lantern) <= 0 then
			break
		end
	end

	local waited = 0
	while tracker.arrived + tracker.killed < tracker.spawned and waited < WAVE_TIMEOUT do
		if lanternHealth(lantern) <= 0 then
			break
		end
		task.wait(0.5)
		waited += 0.5
	end
	if tracker.arrived + tracker.killed < tracker.spawned then
		if lanternHealth(lantern) <= 0 then
			print("[Director] wave=" .. wave .. " lantern destroyed: 남은 적 정리")
		else
			warn("[Director] wave=" .. wave .. " timeout: 남은 적 정리 후 계속한다")
		end
		for _, b in ipairs(bodies) do
			if b.Parent ~= nil then
				b:Destroy()
			end
		end
	end
	CombatService.endWave()
	return tracker
end

-- 맵 준비 대기
local map = workspace:WaitForChild("Map")
while map:GetAttribute("Ready") ~= true do
	task.wait(0.5)
end
local lantern = map:WaitForChild("Lantern")

local state = ReplicatedStorage:FindFirstChild("DirectorState")
if not state then
	state = Instance.new("StringValue")
	state.Name = "DirectorState"
	state.Parent = ReplicatedStorage
end

local currentPlan = FallbackWaves[1]
local currentSource = "fallback"
local wavesCompleted = 0

for wave = 1, Config.TotalWaves do
	if lanternHealth(lantern) <= 0 then
		break
	end
	-- 파티 인원 보정: 검증 통과 뒤 적용 직전에 적 수를 줄인다 (요약은 그대로).
	local partySize = #Players:GetPlayers()
	local playPlan, scaledTotal = PartyScale.scalePlan(currentPlan, partySize)
	print(string.format(
		"[Director] wave=%d party=%d scaled_enemies=%d",
		wave,
		partySize,
		scaledTotal
	))
	logPlan(wave, currentSource, playPlan)
	DirectorState.publish(state, {
		phase = "wave",
		displayWave = wave,
		source = currentSource,
		plan = playPlan,
		waveName = playPlan.wave_name,
		directorNote = playPlan.director_note,
		intermissionEndsAt = 0,
	})

	local tracker = playWave(map, lantern, wave, playPlan)
	wavesCompleted = wave

	if lanternHealth(lantern) <= 0 then
		break
	end
	if wave == Config.TotalWaves then
		break
	end

	-- 대기 시작과 동시에 다음 웨이브 요청 (전투 중 호출 금지: 웨이브 사이만).
	local roster = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(roster, {
			userId = player.UserId,
			role = player:GetAttribute("Class") or "guardian",
		})
	end
	local summary = MatchStats.buildSummary(tracker, wave, lanternHealthPct(lantern), {
		tactic = currentPlan.tactic,
		event = currentPlan.event,
	}, roster)
	local okSummary, summaryJson = pcall(HttpService.JSONEncode, HttpService, summary)
	if okSummary then
		print("[MatchStats] " .. summaryJson)
	end
	local started = os.clock()
	-- 대기 시작 직후 (디렉터 응답 전): 다음 웨이브는 설계 중 문구로 알린다.
	DirectorState.publish(state, {
		phase = "intermission",
		displayWave = wave + 1,
		source = "pending",
		plan = nil,
		waveName = nil,
		directorNote = nil,
		intermissionEndsAt = intermissionEndsAt(Config.IntermissionSeconds),
	})
	local nextPlan = FallbackWaves[wave + 1]
	local nextSource = "fallback"
	local requested = DirectorClient.requestNextWave(summary)
	if requested then
		local ok, clean, errs = WaveValidator.validate(requested, wave + 1)
		if ok and clean then
			nextPlan = clean
			nextSource = "muse"
			for _, e in ipairs(errs) do
				warn("[Director] wave=" .. (wave + 1) .. " auto-fix: " .. e)
			end
		else
			warn("[Director] wave=" .. (wave + 1) .. " plan rejected: " .. table.concat(errs, " / "))
		end
	end
	currentPlan = nextPlan
	currentSource = nextSource

	local rest = Config.IntermissionSeconds - (os.clock() - started)
	-- 디렉터 응답 또는 대체 웨이브 확정: 다음 웨이브 정보로 갱신한다.
	DirectorState.publish(state, {
		phase = "intermission",
		displayWave = wave + 1,
		source = nextSource,
		plan = nextPlan,
		waveName = nextPlan.wave_name,
		directorNote = nextPlan.director_note,
		intermissionEndsAt = intermissionEndsAt(rest),
	})
	if rest > 0 then
		task.wait(rest)
	end
end

if lanternHealth(lantern) <= 0 then
	print("[Director] match over result=defeat waves_completed=" .. wavesCompleted)
else
	print("[Director] match over result=victory waves_completed=" .. wavesCompleted)
end
