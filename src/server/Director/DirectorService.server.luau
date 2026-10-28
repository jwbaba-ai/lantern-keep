-- 경기 흐름 (단일 기준: docs/GAME_DESIGN.md 한 판의 흐름).
-- 웨이브 1~TotalWaves 반복: 진행 -> 종료 -> 요약 -> 대기 시작과 동시에 다음 웨이브 요청.
-- 통과한 계획은 적용하고, 실패(nil·검증 실패)하면 FallbackWaves를 쓴다. 경기는 절대 멈추지 않는다.
-- 웨이브 시작·대기 상태를 DirectorState(JSON)로 알리고, 이벤트 효과는 EventEffects가 적용·복원한다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FallbackWaves = require(Shared:WaitForChild("FallbackWaves"))

local WorldFolder = script.Parent.Parent:WaitForChild("World")
local GateHighlight = require(WorldFolder:WaitForChild("GateHighlight"))

local DirectorFolder = script.Parent
local NpcMemoryFolder = DirectorFolder.Parent:WaitForChild("NpcMemory")
local MatchRecord = require(NpcMemoryFolder:WaitForChild("MatchRecord"))
local MemoryStore = require(NpcMemoryFolder:WaitForChild("MemoryStore"))
local NpcClient = require(NpcMemoryFolder:WaitForChild("NpcClient"))
local EventEffects = require(DirectorFolder:WaitForChild("EventEffects"))
local DirectorClient = require(DirectorFolder:WaitForChild("DirectorClient"))
local WaveValidator = require(DirectorFolder:WaitForChild("WaveValidator"))
local DirectorState = require(DirectorFolder:WaitForChild("DirectorState"))
local PartyScale = require(DirectorFolder:WaitForChild("PartyScale"))
local MatchStats = require(DirectorFolder:WaitForChild("MatchStats"))
local EnemyFactory = require(DirectorFolder.Parent:WaitForChild("Enemies"):WaitForChild("EnemyFactory"))
local CombatService = require(DirectorFolder.Parent:WaitForChild("Combat"):WaitForChild("CombatService"))

local SPAWN_INTERVAL = 1.0 -- 적 한 마리씩 꺼내는 간격(초)
local WAVE_TIMEOUT = 180 -- 웨이브 강제 종료까지 최대 대기(초)
local NPC_SAVE_TIMEOUT = 25 -- 서버 종료 시 기억 저장을 기다리는 상한(초)

-- 경기 종료 처리(요약 + 저장)가 진행 중이면 true. BindToClose가 보고 기다린다.
local npcSaveInProgress = false
game:BindToClose(function()
	local waited = 0
	while npcSaveInProgress and waited < NPC_SAVE_TIMEOUT do
		task.wait(0.5)
		waited += 0.5
	end
end)

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
	-- 이벤트 효과 적용 (웨이브가 끝나면 원래 값으로 되돌린다).
	local waveMods = EventEffects.apply(plan.event)
	local spawnInterval = EventEffects.spawnInterval(plan.event, SPAWN_INTERVAL)
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
				onResolved,
				EventEffects.nextSpawnMods(waveMods)
			)
			if body then
				MatchStats.recordSpawn(tracker, entry.lane)
				table.insert(bodies, body)
			end
			task.wait(spawnInterval)
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
	EventEffects.clear()
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

-- 로비: 1명 이상 들어오고 모두 직업을 고를 때까지 기다린다.
-- 최대 MatchStartWaitSeconds까지만 기다리고, 그래도 0명이면 자동 테스트로 진행한다.
local function lobbyReady()
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in ipairs(players) do
		if player:GetAttribute("Class") == nil then
			return false
		end
	end
	return true
end
local lobbyEndsAt = Workspace:GetServerTimeNow() + (Config.MatchStartWaitSeconds or 20)
DirectorState.publish(state, {
	phase = "lobby",
	displayWave = 1,
	source = "pending",
	plan = nil,
	waveName = "곧 시작합니다",
	directorNote = "",
	intermissionEndsAt = lobbyEndsAt,
})
while not lobbyReady() and Workspace:GetServerTimeNow() < lobbyEndsAt do
	task.wait(0.5)
end

-- NPC 기억용 경기 기록. P 슬롯은 로비 종료 시점 명단으로 배정한다.
local startIds = {}
for _, player in ipairs(Players:GetPlayers()) do
	table.insert(startIds, player.UserId)
end
local matchRecord = MatchRecord.new(startIds)

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
	-- 웨이브 시작: 성문 강조를 끄고 원래 색으로 되돌린다.
	GateHighlight.stop(map)
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
	MatchRecord.recordWave(matchRecord, summary, MatchRecord.perPlayerFromTracker(tracker, roster))
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
	-- 대기 중 미리보기에도 웨이브 시작 때와 같은 PartyScale 보정을 쓴다
	-- (시작 시점에 인원이 바뀌면 그때 다시 보정한다).
	local previewPlan = PartyScale.scalePlan(nextPlan, #Players:GetPlayers())
	DirectorState.publish(state, {
		phase = "intermission",
		displayWave = wave + 1,
		source = nextSource,
		plan = previewPlan,
		waveName = nextPlan.wave_name,
		directorNote = nextPlan.director_note,
		intermissionEndsAt = intermissionEndsAt(rest),
	})
	-- 다음 웨이브가 정해지면 대기 시간 동안 공격 성문을 깜빡인다.
	GateHighlight.start(map, DirectorState.lanesOf(previewPlan))
	if rest > 0 then
		task.wait(rest)
	end
end

-- NPC 기억: 이번 경기 기록을 저장하고 다음 판 대사를 미리 받아 둔다.
-- 모델 호출은 경기가 끝난 뒤 1회만. 실패해도 경기 흐름은 막지 않는다.
local function finishNpcMemory(result)
	npcSaveInProgress = true
	local ok, err = pcall(function()
		local userIds = {}
		for _, player in ipairs(Players:GetPlayers()) do
			table.insert(userIds, player.UserId)
		end
		MemoryStore.finishAndSave(matchRecord, result, wavesCompleted, userIds, function(previous, events)
			return NpcClient.summarize(previous, events)
		end)
	end)
	npcSaveInProgress = false
	if not ok then
		warn("[Npc] 경기 종료 처리 실패: " .. tostring(err))
	end
end

GateHighlight.stop(map)
if lanternHealth(lantern) <= 0 then
	print("[Director] match over result=defeat waves_completed=" .. wavesCompleted)
	finishNpcMemory("defeat")
else
	print("[Director] match over result=victory waves_completed=" .. wavesCompleted)
	finishNpcMemory("victory")
end
