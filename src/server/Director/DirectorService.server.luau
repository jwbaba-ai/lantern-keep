-- 경기 흐름 (단일 기준: docs/GAME_DESIGN.md 한 판의 흐름).
-- 서버가 살아 있는 동안 runMatch()를 반복한다:
-- 로비 -> 웨이브 1~이번 Day 웨이브 수 -> 결과(phase="result") -> NPC 기억 저장 ->
-- MatchRestartSeconds 결과 화면 -> 초기화 -> 로비부터 다시.
-- 승리하면 다음 Day로 가고, 패배하면 같은 Day에 다시 도전한다.
-- 웨이브 반복: 진행 -> 종료 -> 요약 -> 대기 시작과 동시에 다음 웨이브 요청.
-- 통과한 계획은 적용하고, 실패(nil·검증 실패)하면 FallbackWaves를 쓴다. 경기는 절대 멈추지 않는다.
-- 웨이브 시작·대기·결과 상태를 DirectorState(JSON)로 알리고,
-- 이벤트 효과는 EventEffects가 적용·복원한다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FallbackWaves = require(Shared:WaitForChild("FallbackWaves"))
local ClassCatalog = require(Shared:WaitForChild("ClassCatalog"))

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
local DayRules = require(DirectorFolder:WaitForChild("DayRules"))
local PartyScale = require(DirectorFolder:WaitForChild("PartyScale"))
local MatchStats = require(DirectorFolder:WaitForChild("MatchStats"))
local EnemyFactory = require(DirectorFolder.Parent:WaitForChild("Enemies"):WaitForChild("EnemyFactory"))
local CombatService = require(DirectorFolder.Parent:WaitForChild("Combat"):WaitForChild("CombatService"))
local SupportSquad = require(DirectorFolder.Parent:WaitForChild("Support"):WaitForChild("SupportSquad"))

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

-- 웨이브 완료 수 계산 (순수 함수).
-- 등불이 꺼졌으면 패배한 웨이브를 세지 않고 이전 값을 유지한다.
-- 승리·시간 초과·debugFastMatch(등불 > 0)는 그 웨이브를 완료로 센다.
local function completedAfterWave(completed, wave, lanternHp)
	if lanternHp <= 0 then
		return completed
	end
	return wave
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

-- 적이 가장 많은 성문. 동점이면 Config.Lanes 순서 앞쪽.
local function busiestLane(plan)
	local counts = { north = 0, south = 0, east = 0, west = 0 }
	for _, e in ipairs(plan.enemies) do
		if counts[e.lane] ~= nil then
			counts[e.lane] += e.count
		end
	end
	local bestLane = Config.Lanes[1]
	local best = -1
	for _, lane in ipairs(Config.Lanes) do
		if counts[lane] > best then
			best = counts[lane]
			bestLane = lane
		end
	end
	return bestLane
end

-- 보스 웨이브면 계획 복사본에 { type = "Warlord", count = 1, lane }을 붙인다.
-- 디렉터는 보스를 고를 수 없고(Config.EnemyTypes에 없음),
-- 서버가 검증·보정 뒤에 붙인다. 원본은 고치지 않는다.
-- 돌려값: bossPlan, bossLane (보스 웨이브가 아니면 원래 계획과 nil).
local function withBoss(plan, day, wave)
	if not DayRules.isBossWave(day, wave) then
		return plan, nil
	end
	local lane = busiestLane(plan)
	local bossed = {
		wave_name = plan.wave_name,
		enemies = {},
		tactic = plan.tactic,
		event = plan.event,
		director_note = plan.director_note,
	}
	for _, e in ipairs(plan.enemies) do
		table.insert(bossed.enemies, { type = e.type, count = e.count, lane = e.lane })
	end
	table.insert(bossed.enemies, { type = "Warlord", count = 1, lane = lane })
	return bossed, lane
end

-- 디버그 "남은 웨이브 건너뛰기" 플래그 (NpcDebug.debugFastMatch()가 켠다).
-- 실제 경기 흐름 코드는 그대로 쓰고, 이 플래그만 확인한다.
local function fastMatchRequested()
	return ReplicatedStorage:GetAttribute("DebugFastMatch") == true
end

local function clearFastMatch()
	ReplicatedStorage:SetAttribute("DebugFastMatch", false)
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
-- dayHealthMult: Day 체력 배율 (EnemyFactory.spawn에 인자로 넘긴다).
-- bossLane: 보스 웨이브의 보스 성문. 보스는 웨이브 시작 10초 뒤에 나온다.
-- 성문별 시간 차 (day9): 계획의 적을 성문별 묶음으로 나누고,
-- 적이 많은 성문부터 (i-1) x 간격초 뒤에 출발한다.
-- 묶음은 task.spawn으로 동시에 돌리고, 모든 묶음이 끝난 뒤 종료 판정을 시작한다.
-- 성문 안에서는 기존 SPAWN_INTERVAL 간격으로 한 마리씩 나온다
-- (reinforcement_delay 효과 포함). 등불 파괴·debugFastMatch 중단은 그대로다.
local function playWave(map, lantern, wave, plan, dayHealthMult, bossLane)
	local tracker = MatchStats.new()
	CombatService.beginWave(tracker)
	-- 보스 자리 예약: 10초 뒤에 나오므로, 그 전에 일반 적이 다 끝나도
	-- 웨이브가 끝나지 않게 spawned를 미리 하나 센다 (기존 arrived + killed < spawned 규칙 그대로).
	if bossLane ~= nil then
		MatchStats.recordSpawn(tracker, bossLane)
	end
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

	-- 웨이브가 끝나면(정리·다음 웨이브) 늦은 성문 스폰이 새지 않게 한다.
	local cancelled = false
	-- 성문별 적 묶음 (보스 제외, 계획 순서 유지).
	local order = DirectorState.laneStartTimes(
		plan,
		Config.LaneStaggerSeconds or 8,
		Config.SplitPushStaggerSeconds or 3
	)
	local groups = {}
	for _, entry in ipairs(plan.enemies) do
		-- 보스는 아래 delayed 스폰으로 따로 나온다 (10초 뒤).
		if entry.type ~= "Warlord" then
			groups[entry.lane] = groups[entry.lane] or {}
			for _ = 1, entry.count do
				table.insert(groups[entry.lane], entry.type)
			end
		end
	end
	local remaining = #order
	for _, slot in ipairs(order) do
		task.spawn(function()
			local ok, err = pcall(function()
				if slot.start_at > 0 then
					task.wait(slot.start_at)
				end
				for _, enemyType in ipairs(groups[slot.lane] or {}) do
					if cancelled or lanternHealth(lantern) <= 0 or fastMatchRequested() then
						break
					end
					local body = EnemyFactory.spawn(
						enemyType,
						slot.lane,
						waypointsByLane[slot.lane],
						lantern,
						onResolved,
						EventEffects.nextSpawnMods(waveMods),
						dayHealthMult
					)
					if body then
						MatchStats.recordSpawn(tracker, slot.lane)
						table.insert(bodies, body)
					end
					task.wait(spawnInterval)
				end
			end)
			if not ok then
				warn("[Director] wave=" .. wave .. " lane=" .. slot.lane .. " spawn failed: " .. tostring(err))
			end
			remaining -= 1
		end)
	end

	-- 보스는 웨이브 시작 10초 뒤에 나온다.
	-- 파티 체력 배율과 Day 체력 배율을 모두 받는다
	-- (파티 배율은 spawn 안에서, Day 배율은 인자로).
	-- 자동 테스트(플레이어 0명)의 체력 비례 처치도 보스에 그대로 적용된다.
	if bossLane ~= nil then
		task.delay(10, function()
			if cancelled or lanternHealth(lantern) <= 0 or fastMatchRequested() then
				-- 보스가 나오지 못하면 예약 자리를 정리한다.
				MatchStats.recordResolved(tracker, bossLane, "killed")
				return
			end
			local boss = EnemyFactory.spawn(
				"Warlord",
				bossLane,
				waypointsByLane[bossLane],
				lantern,
				onResolved,
				nil,
				dayHealthMult
			)
			if boss then
				table.insert(bodies, boss)
			else
				MatchStats.recordResolved(tracker, bossLane, "killed")
			end
		end)
	end

	-- 모든 성문 묶음이 끝날 때까지 기다린 뒤 종료 판정을 시작한다.
	-- 아직 나오지 않은 적은 기다리므로 spawned 예약 없이도 규칙이 유지된다.
	-- 등불 파괴·debugFastMatch면 묶음이 끝나기 전에도 빠져나간다.
	local waitedGroups = 0
	while remaining > 0 and waitedGroups < WAVE_TIMEOUT do
		if lanternHealth(lantern) <= 0 or fastMatchRequested() then
			break
		end
		task.wait(0.5)
		waitedGroups += 0.5
	end
	local waited = 0
	while tracker.arrived + tracker.killed < tracker.spawned and waited < WAVE_TIMEOUT do
		if lanternHealth(lantern) <= 0 or fastMatchRequested() then
			break
		end
		task.wait(0.5)
		waited += 0.5
	end
	-- 늦은 성문 스폰이 정리 뒤에 새지 않게 막는다.
	cancelled = true
	if tracker.arrived + tracker.killed < tracker.spawned then
		if lanternHealth(lantern) <= 0 then
			print("[Director] wave=" .. wave .. " lantern destroyed: 남은 적 정리")
		elseif not fastMatchRequested() then
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

-- 다음 판 준비: 등불 체력 100, 남은 적 제거, 이벤트 효과 복원, 성문 강조 끄기,
-- 살아 있는 플레이어 체력을 직업 최대 체력으로 채우기 (죽은 자는 리스폰에 맡긴다).
local function resetForNextMatch()
	lantern:SetAttribute("Health", Config.LanternMaxHealth)
	for _, player in ipairs(Players:GetPlayers()) do
		local classKey = player:GetAttribute("Class")
		local spec = classKey and ClassCatalog[classKey] or nil
		if spec then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = spec.MaxHealth
			end
		end
	end
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		for _, child in ipairs(enemies:GetChildren()) do
			child:Destroy()
		end
	end
	EventEffects.clear()
	GateHighlight.stop(map)
	CombatService.endWave()
end

local function publishResult(day, totalWaves, wavesCompleted, source, result, endsAt)
	DirectorState.publish(state, {
		phase = "result",
		displayWave = wavesCompleted,
		source = source,
		plan = nil,
		waveName = nil,
		directorNote = nil,
		intermissionEndsAt = endsAt,
		result = result,
		wavesCompleted = wavesCompleted,
		lanternHealthPct = lanternHealthPct(lantern),
		day = day,
		totalWaves = totalWaves,
		boss = false,
	})
end

-- 경기 한 판: 로비 -> 웨이브 -> 결과 -> 기억 저장 -> 결과 화면 -> 초기화.
-- 플레이어의 직업은 판이 바뀌어도 유지하고, 다시 고르지 않는다.
-- day: 이번 판의 Day 번호. 웨이브 수는 DayRules.waveCount(day)로 정한다.
local function runMatch(matchNumber, day)
	-- 로비: 1명 이상 들어오고 모두 직업을 고르고 투표할 때까지 기다린다.
	-- 최대 MatchStartWaitSeconds까지만 기다리고, 그래도 0명이면 자동 테스트로 진행한다.
	-- 제한 시간은 첫 플레이어가 캐릭터를 받은 시점부터 잰다
	-- (접속 로딩 중에 로비가 끝나지 않게). 0명이면 판 시작부터 잰다.
	-- 이전 판에 낸 표는 다음 로비에 그대로 남아서 투표로 인정한다.
	local function votedSet()
		local voted = {}
		local supportState = ReplicatedStorage:FindFirstChild("SupportState")
		if supportState then
			local ok, data = pcall(HttpService.JSONDecode, HttpService, supportState.Value)
			if ok and type(data) == "table" and type(data.votes) == "table" then
				for _, entry in ipairs(data.votes) do
					if entry.userId ~= nil then
						voted[entry.userId] = true
					elseif entry.name ~= nil then
						voted[entry.name] = true
					end
				end
			end
		end
		return voted
	end
	local function lobbyReady()
		local players = Players:GetPlayers()
		if #players == 0 then
			return false
		end
		local voted = votedSet()
		for _, player in ipairs(players) do
			if player:GetAttribute("Class") == nil then
				return false
			end
			if not voted[player.UserId] and not voted[player.DisplayName] then
				return false
			end
		end
		return true
	end
	-- 이번 판의 웨이브 수와 Day 체력 배율. 로비 화면에도 Day를 알린다.
	local totalWaves = DayRules.waveCount(day)
	local dayHealthMult = DayRules.scale(day).health
	ReplicatedStorage:SetAttribute("Day", day)
	local lobbyEndsAt = Workspace:GetServerTimeNow() + (Config.MatchStartWaitSeconds or 20)
	local function publishLobby()
		DirectorState.publish(state, {
			phase = "lobby",
			displayWave = 1,
			source = "pending",
			plan = nil,
			waveName = "곧 시작합니다",
			directorNote = "",
			intermissionEndsAt = lobbyEndsAt,
			day = day,
			totalWaves = totalWaves,
			boss = false,
		})
	end
	publishLobby()
	-- 첫 캐릭터를 받은 시점에 제한 시간을 다시 잰다. 아직 캐릭터가 없으면
	-- 판 시작 기준 시각을 그대로 쓴다 (0명 자동 테스트).
	local firstCharSeen = false
	while not lobbyReady() and Workspace:GetServerTimeNow() < lobbyEndsAt and not fastMatchRequested() do
		if not firstCharSeen then
			for _, player in ipairs(Players:GetPlayers()) do
				if player.Character ~= nil then
					firstCharSeen = true
					lobbyEndsAt = Workspace:GetServerTimeNow() + (Config.MatchStartWaitSeconds or 20)
					publishLobby()
					break
				end
			end
		end
		task.wait(0.5)
	end

	-- 로비 종료: 지원대 투표를 집계하고 빈자리를 채운다.
	-- 웨이브 1 파티 계산 전에 동기로 끝낸다.
	-- 지원대 생성에 실패해도 경기는 계속한다 (대체: 지원대 없음).
	local supportChoice = "none"
	do
		local ok, choice = pcall(SupportSquad.finalizeLobby)
		if ok and choice ~= nil then
			supportChoice = choice
		else
			warn("[Support] spawn failed: " .. tostring(choice))
			pcall(SupportSquad.clearMatch)
			supportChoice = "none"
		end
	end

	-- NPC 기억용 경기 기록. P 슬롯·파티 키·partySize는 로비 종료 시점 명단 하나다.
	local startIds = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(startIds, player.UserId)
	end
	local matchRecord = MatchRecord.new(startIds)
	-- 판 번호: NpcService가 바뀔 때마다 기억을 다시 불러와 다음 판 인사를 준비한다.
	ReplicatedStorage:SetAttribute("MatchNumber", matchNumber)

	local currentPlan = FallbackWaves[1]
	local currentSource = "fallback"
	local wavesCompleted = 0

	for wave = 1, totalWaves do
		if fastMatchRequested() then
			clearFastMatch()
			break
		end
		if lanternHealth(lantern) <= 0 then
			break
		end
		-- 적용 순서: 검증 통과 뒤 PartyScale 보정 → DayRules 수 보정 → (보스 웨이브면) 보스 추가.
		-- 파티·Day 보정은 웨이브 시작 시점 복사본에만 건다 (요약·previous_wave는 그대로).
		-- 파티 인원: 사람 + 지원대 수(최대 SupportMaxParty).
		local partySize = SupportSquad.partySize()
		local partyPlan = PartyScale.scalePlan(currentPlan, partySize)
		local playPlan, bossLane = withBoss(DayRules.scalePlan(partyPlan, day), day, wave)
		local scaledTotal = 0
		for _, e in ipairs(playPlan.enemies) do
			scaledTotal += e.count
		end
		print(string.format(
			"[Director] day=%d wave=%d party=%d scaled_enemies=%d",
			day,
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
			day = day,
			totalWaves = totalWaves,
			boss = bossLane ~= nil,
		})

		local tracker = playWave(map, lantern, wave, playPlan, dayHealthMult, bossLane)
		-- 패배한 웨이브는 완료로 세지 않는다 (결과 화면·NPC 기억이 함께 고쳐진다).
		wavesCompleted = completedAfterWave(wavesCompleted, wave, lanternHealth(lantern))

		if lanternHealth(lantern) <= 0 then
			break
		end
		if fastMatchRequested() then
			clearFastMatch()
			break
		end
		if wave == totalWaves then
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
		for _, bot in ipairs(SupportSquad.getBots()) do
			table.insert(roster, {
				userId = bot.UserId,
				role = bot.role,
				support = true,
			})
		end
		local summary = MatchStats.buildSummary(tracker, wave, lanternHealthPct(lantern), {
			tactic = currentPlan.tactic,
			event = currentPlan.event,
		}, roster, day, totalWaves, supportChoice)
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
			day = day,
			totalWaves = totalWaves,
			boss = DayRules.isBossWave(day, wave + 1),
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
		-- 대기 중 미리보기와 성문 강조도 웨이브 시작 때와 같은 순서로 만든다
		-- (PartyScale → DayRules → 보스 추가, 시작 시점에 인원이 바뀌면 그때 다시 보정한다).
		local previewPlan = withBoss(
			DayRules.scalePlan(PartyScale.scalePlan(nextPlan, SupportSquad.partySize()), day),
			day,
			wave + 1
		)
		DirectorState.publish(state, {
			phase = "intermission",
			displayWave = wave + 1,
			source = nextSource,
			plan = previewPlan,
			waveName = nextPlan.wave_name,
			directorNote = nextPlan.director_note,
			intermissionEndsAt = intermissionEndsAt(rest),
			day = day,
			totalWaves = totalWaves,
			boss = DayRules.isBossWave(day, wave + 1),
		})
		-- 다음 웨이브가 정해지면 대기 시간 동안 공격 성문을 깜빡인다.
		-- 출발 순서가 보이게 첫 성문을 가장 밝게 한다.
		local previewOrder = DirectorState.laneStartTimes(
			previewPlan,
			Config.LaneStaggerSeconds or 8,
			Config.SplitPushStaggerSeconds or 3
		)
		GateHighlight.start(
			map,
			DirectorState.lanesOf(previewPlan),
			previewOrder[1] and previewOrder[1].lane or nil
		)
		local restLeft = rest
		while restLeft > 0 do
			if fastMatchRequested() then
				break
			end
			local step = math.min(0.5, restLeft)
			task.wait(step)
			restLeft -= step
		end
	end

	-- NPC 기억: 이번 경기 기록을 저장하고 다음 판 대사를 미리 받아 둔다.
	-- 모델 호출은 경기가 끝난 뒤 1회만. 실패해도 경기 흐름은 막지 않는다.
	-- 파티 키·partySize는 로비 종료 시점 명단(startIds) 하나로 정한다.
	-- 종료 시점의 Players:GetPlayers()는 쓰지 않는다 (중간 입장자 제외).
	local function finishNpcMemory(result, record, completedWaves, startIds)
		npcSaveInProgress = true
		local ok, err = pcall(function()
			MemoryStore.finishAndSave(record, result, completedWaves, startIds, function(previous, events)
				return NpcClient.summarize(previous, events)
			end, day, totalWaves, supportChoice)
		end)
		npcSaveInProgress = false
		if not ok then
			warn("[Npc] 경기 종료 처리 실패: " .. tostring(err))
		end
	end

	GateHighlight.stop(map)
	local result = "victory"
	if lanternHealth(lantern) <= 0 then
		result = "defeat"
	end
	print(string.format(
		"[Director] day=%d waves=%d result=%s",
		day,
		totalWaves,
		result
	))

	-- 1. 결과 알림 (카운트다운 끝 시각은 저장 뒤에 확정한다).
	publishResult(day, totalWaves, wavesCompleted, currentSource, result, 0)
	-- 판 끝: 지원대를 모두 지운다. 다음 로비 투표 결과로 다시 만든다.
	-- 실패해도 결과 화면·다음 판으로 계속 간다.
	local okClear, clearErr = pcall(SupportSquad.clearMatch)
	if not okClear then
		warn("[Support] clear failed: " .. tostring(clearErr))
	end
	-- 2. 경기 종료 처리(NPC 기억 요약·저장)를 끝까지 기다린다.
	finishNpcMemory(result, matchRecord, wavesCompleted, startIds)
	-- 3. 결과 화면을 MatchRestartSeconds초 보여 준다. 저장이 더 오래 걸리면 그만큼 늦게 시작한다.
	local restartSeconds = Config.MatchRestartSeconds or 15
	publishResult(day, totalWaves, wavesCompleted, currentSource, result, intermissionEndsAt(restartSeconds))
	task.wait(restartSeconds)
	-- 4. 다음 판 초기화. 직업은 유지한다.
	resetForNextMatch()
	return result
end

ReplicatedStorage:SetAttribute("MatchNumber", 0)
ReplicatedStorage:SetAttribute("Day", 1)
local matchNumber = 0
-- Day는 서버 안에서만 이어진다. 새 서버는 Day 1부터 시작한다.
-- 승리하면 다음 Day로 가고, 패배하면 같은 Day에 다시 도전한다.
local currentDay = 1
while true do
	matchNumber += 1
	-- 디버그: debugSetDay(n)이 있으면 다음 판 Day를 n으로 정하고 한 번만 쓴다.
	local debugDay = ReplicatedStorage:GetAttribute("DebugDay")
	if type(debugDay) == "number" and debugDay >= 1 then
		currentDay = math.floor(debugDay)
		ReplicatedStorage:SetAttribute("DebugDay", nil)
	end
	print(string.format("[Director] match=%d day=%d start", matchNumber, currentDay))
	local result = runMatch(matchNumber, currentDay)
	if result == "victory" then
		currentDay += 1
	end
	-- 플레이어가 0명이면(자동 테스트) 한 판만 돌고 멈춘다. 지금과 같은 동작이다.
	if #Players:GetPlayers() == 0 then
		print("[Director] no players after match: 한 판만 돌고 멈춘다")
		break
	end
end
