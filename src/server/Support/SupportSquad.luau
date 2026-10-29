-- 지원대 생성과 행동 (단일 기준: docs/tasks/day8b-support.md 4단계).
-- 로비 투표 결과가 나오면 빈자리만큼 규칙 기반 동료를 등불 옆에 만든다.
-- 지원대는 모델을 호출하지 않는다. 전투 중 모델 호출 금지 규칙 유지.
-- 인원: SupportMaxParty - 사람 수(0 이상). roles 앞에서부터 그 수만큼 쓴다.
local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ClassCatalog = require(Shared:WaitForChild("ClassCatalog"))

local SupportFolder = script.Parent
local SupportVote = require(SupportFolder:WaitForChild("SupportVote"))

-- CombatService·MatchStats는 함수 안에서 늦게 require한다.
-- EnemyFactory가 파티 인원용으로 이 모듈을 require하므로
-- 여기서 CombatService를 바로 require하면 순환 참조가 된다.
local combatService = nil
local function combat()
	if combatService == nil then
		combatService = require(
			SupportFolder.Parent:WaitForChild("Combat"):WaitForChild("CombatService")
		)
	end
	return combatService
end

local matchStats = nil
local function stats()
	if matchStats == nil then
		matchStats = require(
			SupportFolder.Parent:WaitForChild("Director"):WaitForChild("MatchStats")
		)
	end
	return matchStats
end

local SupportSquad = {}

local COHESION_OFFSETS = {
	Vector3.new(3, 0, 0),
	Vector3.new(-3, 0, 0),
	Vector3.new(0, 0, 3),
	Vector3.new(0, 0, -3),
}

-- 지원대끼리 충돌하지 않게 하는 충돌 그룹. Support끼리는 끄고,
-- 바닥·성벽·적·사람(기본 그룹)과는 그대로 충돌한다.
local SUPPORT_GROUP = "Support"

local function ensureSupportCollisionGroup()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(SUPPORT_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(SUPPORT_GROUP, SUPPORT_GROUP, false)
	end)
end

ensureSupportCollisionGroup()

-- 이름표용 직업 한글 표. ClassCatalog(src/shared)는 고치지 않는다.
local ROLE_KO = {
	guardian = "수호자",
	ranger = "궁수",
	cleric = "사제",
	arcanist = "비전술사",
}

-- 직업의 화면 표시 이름(한글). 모르는 값은 그대로 둔다.
function SupportSquad.koreanRoleName(role)
	return ROLE_KO[role] or role
end

local bots = {} -- 살아 있는 지원대 테이블 배열
local lastReport = {} -- 판 끝 보고용 스냅샷
local currentChoice = "none"
local generation = 0

-- 사람 수에 대한 지원대 수. 0 이상, roles 길이를 넘지 않는다.
function SupportSquad.botCount(humanCount)
	local n = math.max(0, (Config.SupportMaxParty or 4) - (humanCount or 0))
	local roles = Config.SupportSquads.solo.roles
	return math.min(n, #roles)
end

-- 앞에서부터 n개의 직업.
function SupportSquad.rolesFor(choice, n)
	local squad = Config.SupportSquads[choice]
	assert(squad, "rolesFor: unknown choice " .. tostring(choice))
	local out = {}
	for i = 1, math.min(n or 0, #squad.roles) do
		table.insert(out, squad.roles[i])
	end
	return out
end

-- 파티 인원: 사람 + 지원대 수(최대 SupportMaxParty).
-- 인자를 주면 순수 계산, 없으면 살아 있는 인원으로 센다.
function SupportSquad.partySize(humanCount, botCount)
	if humanCount == nil then
		humanCount = #Players:GetPlayers()
	end
	if botCount == nil then
		botCount = SupportSquad.activeCount()
	end
	return math.clamp(humanCount + botCount, 1, Config.SupportMaxParty or 4)
end

function SupportSquad.activeCount()
	local n = 0
	for _, bot in ipairs(bots) do
		if bot.active then
			n += 1
		end
	end
	return n
end

function SupportSquad.getBots()
	return bots
end

function SupportSquad.getChoice()
	return currentChoice
end

-- 판 끝 보고용: 살아 있으면 지금 명단, 끝났으면 마지막 스냅샷.
function SupportSquad.reportBots()
	if #bots > 0 then
		return bots
	end
	return lastReport
end

-- 테스트용 공유 상태. Studio 명령줄·MCP에서 require하면 게임이 쓰는
-- SupportSquad와 다른 사본이 실행돼서 reportBots()가 빈 값을 낸다.
-- 그래서 지원대 상태(유형·역할·맡은 성문·위치·피해·사망)를 ReplicatedStorage의
-- StringValue "SupportDebug"(JSON)에 1초마다 써 둔다. 화면 표시용이 아니다.
local function getDebugValue()
	local v = ReplicatedStorage:FindFirstChild("SupportDebug")
	if v and v:IsA("StringValue") then
		return v
	end
	if v then
		v:Destroy()
	end
	local created = Instance.new("StringValue")
	created.Name = "SupportDebug"
	created.Value = ""
	created.Parent = ReplicatedStorage
	return created
end

local function writeDebugSnapshot()
	local entry = { choice = currentChoice, bots = {} }
	for _, bot in ipairs(bots) do
		local pos = nil
		local model = bot.Character
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			pos = root.Position
		end
		table.insert(entry.bots, {
			name = bot.Name,
			role = bot.role,
			lane = bot.lane,
			damage = bot.damage or 0,
			deaths = bot.deaths or 0,
			x = pos and pos.X or nil,
			y = pos and pos.Y or nil,
			z = pos and pos.Z or nil,
		})
	end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, entry)
	if ok then
		pcall(function()
			getDebugValue().Value = json
		end)
	end
end

-- 성문별 적 수(lanes 테이블)와 사람이 서 있는 성문 목록을 받아
-- 지원대 n명이 맡을 성문을 정한다. 적이 많은 순, 사람이 있는 성문은 뒤로.
function SupportSquad.assignSoloLanes(laneCounts, humanLanes, n)
	local lanes = {}
	for _, lane in ipairs(Config.Lanes) do
		table.insert(lanes, lane)
	end
	local order = {}
	for i, lane in ipairs(Config.Lanes) do
		order[lane] = i
	end
	table.sort(lanes, function(a, b)
		local ca, cb = laneCounts[a] or 0, laneCounts[b] or 0
		if ca ~= cb then
			return ca > cb
		end
		return order[a] < order[b]
	end)
	local humanSet = {}
	for _, lane in ipairs(humanLanes or {}) do
		humanSet[lane] = true
	end
	local free, taken = {}, {}
	for _, lane in ipairs(lanes) do
		if humanSet[lane] then
			table.insert(taken, lane)
		else
			table.insert(free, lane)
		end
	end
	local ordered = {}
	for _, lane in ipairs(free) do
		table.insert(ordered, lane)
	end
	for _, lane in ipairs(taken) do
		table.insert(ordered, lane)
	end
	local out = {}
	for i = 1, math.min(n or 0, #ordered) do
		table.insert(out, ordered[i])
	end
	return out
end

local function getMap()
	return Workspace:WaitForChild("Map")
end

local function gatePosition(map, lane)
	local gates = map:FindFirstChild("Gates")
	local gate = gates and gates:FindFirstChild(lane)
	if gate and gate:IsA("BasePart") then
		return gate.Position
	end
	return Vector3.new(0, 6, 0)
end

local function lanternPosition(map)
	local lantern = map:FindFirstChild("Lantern")
	if lantern and lantern:IsA("BasePart") then
		return lantern.Position
	end
	return Vector3.new(0, 10, 0)
end

-- 맡은 성문 안쪽(성문과 등불 사이 1/3 지점).
local function innerPoint(map, lane)
	local gate = gatePosition(map, lane)
	local lantern = lanternPosition(map)
	local p = gate:Lerp(lantern, 1 / 3)
	return Vector3.new(p.X, 3, p.Z)
end

-- 사람이 서 있는 성문: 각 사람의 가장 가까운 성문.
local function humanLanes(map)
	local out = {}
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local best, bestDist = nil, nil
			for _, lane in ipairs(Config.Lanes) do
				local d = (gatePosition(map, lane) - root.Position).Magnitude
				if bestDist == nil or d < bestDist then
					best, bestDist = lane, d
				end
			end
			if best and not seen[best] then
				seen[best] = true
				table.insert(out, best)
			end
		end
	end
	return out
end

local function moveBot(bot, point)
	local model = bot.Character
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum:MoveTo(point)
		bot.lastMoveAt = os.clock()
	end
end

-- 목표 지점까지의 거리. 4스터드보다 멀면 이동 중이다.
local ARRIVE_RADIUS = 4

-- 목표까지 거리 > 4 → 이동 중(방향 돌리기 안 함), ≤ 4 → 도착.
function SupportSquad.isMovingToGoal(currentPos, goalPos)
	if currentPos == nil or goalPos == nil then
		return false
	end
	return (currentPos - goalPos).Magnitude > ARRIVE_RADIUS
end

local function getSupportFolder()
	local folder = Workspace:FindFirstChild("Support")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Support"
		folder.Parent = Workspace
	end
	return folder
end

local function buildModel(bot, choice, map, spawnAt)
	local old = bot.Character
	if old then
		old:Destroy()
	end
	bot.Character = nil
	local model = Players:CreateHumanoidModelFromDescription(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R15
	)
	model.Name = bot.Name
	local spec = ClassCatalog[bot.role]
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and spec then
		hum.MaxHealth = spec.MaxHealth
		hum.Health = spec.MaxHealth
	end
	local squadLabel = Config.SupportSquads[choice].label
	local display = SupportSquad.koreanRoleName(bot.role)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local tag = Instance.new("BillboardGui")
		tag.Name = "Nameplate"
		tag.Adornee = root
		tag.Size = UDim2.new(0, 200, 0, 40)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		tag.Parent = model
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = string.format("지원대 · %s · %s", squadLabel, display)
		label.Parent = tag
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = SUPPORT_GROUP
			end)
		end
	end
	model:PivotTo(CFrame.new(spawnAt))
	model.Parent = getSupportFolder()
	bot.Character = model
	bot.spawnAt = spawnAt
	hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		-- 엉켜 올라가는 상태 방지: Climbing을 끈다.
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		end)
		hum.Died:Connect(function()
			SupportSquad.onBotDied(bot)
		end)
	end
	-- 서버가 움직이는 모델이니 서버가 물리를 맡는다.
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local ok, err = pcall(function()
			root:SetNetworkOwner(nil)
		end)
		if not ok then
			warn(string.format("[Support] network owner failed %s: %s", bot.Name, tostring(err)))
		end
	end
end

-- 엉켜 올라가는 안전망: 등불 높이보다 30스터드 넘게 높거나
-- 그만큼 아래로 떨어지면 자기 생성 자리로 돌려놓는다.
local UNSTUCK_ABOVE = 30
local UNSTUCK_BELOW = 30

local function checkUnstuck(map, lantern)
	for _, bot in ipairs(bots) do
		if bot.active and bot.spawnAt then
			local model = bot.Character
			local root = model and model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local y = root.Position.Y
				if y > lantern.Y + UNSTUCK_ABOVE or y < lantern.Y - UNSTUCK_BELOW then
					local ok, err = pcall(function()
						root.AssemblyLinearVelocity = Vector3.zero
						model:PivotTo(CFrame.new(bot.spawnAt))
					end)
					if ok then
						print(string.format("[Support] unstuck %s", bot.Name))
						if bot.lane then
							moveBot(bot, innerPoint(map, bot.lane))
						end
					else
						warn("[Support] unstuck failed: " .. tostring(err))
					end
				end
			end
		end
	end
end

function SupportSquad.onBotDied(bot)
	if not bot.active then
		return
	end
	bot.deaths += 1
	local tracker = combat().getTracker()
	if tracker then
		stats().recordDeath(tracker, bot)
	end
	task.delay(Config.SupportRespawnSeconds or 10, function()
		if not bot.active then
			return
		end
		local map = getMap()
		buildModel(bot, currentChoice, map, lanternPosition(map) + Vector3.new(0, 3, 0))
		if bot.lane then
			moveBot(bot, innerPoint(map, bot.lane))
		end
	end)
end

-- 사거리 안에서 가장 가까운 적 파트.
local function nearestEnemy(pos, range)
	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		return nil
	end
	local best, bestDist = nil, nil
	for _, body in ipairs(folder:GetChildren()) do
		if body:IsA("BasePart") then
			local d = (body.Position - pos).Magnitude
			if d <= range and (bestDist == nil or d < bestDist) then
				best, bestDist = body, d
			end
		end
	end
	return best
end

local function attackRange(classKey)
	local spec = ClassCatalog[classKey]
	if not spec then
		return 0
	end
	if classKey == "guardian" then
		return spec.Radius
	elseif classKey == "ranger" or classKey == "arcanist" then
		return spec.Range
	elseif classKey == "cleric" then
		return spec.MeleeRadius
	end
	return 0
end

local function accumulateDamage(bot)
	local tracker = combat().getTracker()
	if not tracker then
		return
	end
	if tracker ~= bot.lastTracker then
		bot.lastTracker = tracker
		bot.lastSeen = 0
	end
	local dealt = tracker.damage[bot.UserId] or 0
	bot.damage += math.max(0, dealt - (bot.lastSeen or 0))
	bot.lastSeen = dealt
end

-- 이동 중인지 본다. 맡은 성문 안쪽 목표에서 4스터드보다 멀면 이동 중이다.
-- 이동 중에는 MoveTo를 끊지 않게 CFrame을 쓰지 않고,
-- SupportRetargetSeconds마다 MoveTo를 다시 부른다(solo·coop 공통).
local function updateMovement(bot, root)
	if bot.lane == nil then
		return false
	end
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return false
	end
	local goal = innerPoint(map, bot.lane)
	if not SupportSquad.isMovingToGoal(root.Position, goal) then
		return false
	end
	local now = os.clock()
	if now - (bot.lastMoveAt or 0) >= (Config.SupportRetargetSeconds or 5) then
		moveBot(bot, goal)
	end
	return true
end

-- 지원대 1명의 한 틱. 직업 Cooldown마다 사거리 안에서 가장 가까운 적을 노린다.
local function tickBot(bot)
	local model = bot.Character
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then
		return
	end
	local moving = updateMovement(bot, root)
	local svc = combat()
	if bot.role == "cleric" then
		-- 반경 안에서 체력 비율이 가장 낮은 아군을 치유한다
		-- (SupportHealBelowPct 이하일 때). 아니면 근접 공격만 한다.
		local spec = ClassCatalog.cleric
		local _, pct = svc.lowestAllyInRadius(root, spec.Radius)
		if pct <= (Config.SupportHealBelowPct or 0.6) then
			svc.performAttack(bot, "cleric", root, root.Position)
		else
			local target = nearestEnemy(root.Position, spec.MeleeRadius)
			if target then
				svc.clericMelee(bot, root)
			end
		end
		accumulateDamage(bot)
		return
	end
	local target = nearestEnemy(root.Position, attackRange(bot.role))
	if not target then
		return
	end
	-- 도착한 뒤에만 몸 방향을 적 쪽으로 돌린다(이동 중에는 MoveTo를 끊지 않게
	-- CFrame을 쓰지 않는다. 조준은 대상 위치를 그대로 쓰므로 몸 방향이 필요 없다).
	-- 돌릴 때는 위치를 바꾸지 않는다.
	if not moving then
		local look = Vector3.new(target.Position.X, root.Position.Y, target.Position.Z)
		if (look - root.Position).Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, look)
		end
	end
	svc.performAttack(bot, bot.role, root, target.Position)
	accumulateDamage(bot)
end

-- 살아 있는 적이 가장 많은 성문. 동점이면 Config.Lanes 순서 앞쪽.
local function busiestLiveLane()
	local counts = { north = 0, south = 0, east = 0, west = 0 }
	local folder = Workspace:FindFirstChild("Enemies")
	if folder then
		for _, body in ipairs(folder:GetChildren()) do
			local lane = body:IsA("BasePart") and body:GetAttribute("Lane") or nil
			if lane and counts[lane] ~= nil then
				counts[lane] += 1
			end
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

local function moveCoop(map)
	local anchor = innerPoint(map, busiestLiveLane())
	for i, bot in ipairs(bots) do
		if bot.active then
			local offset = COHESION_OFFSETS[((i - 1) % #COHESION_OFFSETS) + 1]
			moveBot(bot, anchor + offset)
		end
	end
end

-- 웨이브 시작 때 자리 잡기. solo는 적이 많은 순으로 서로 다른 성문,
-- coop은 다 함께 적이 가장 많은 성문.
local function onWaveStart(plan)
	if #bots == 0 then
		return
	end
	local map = getMap()
	if currentChoice == "solo" then
		local counts = { north = 0, south = 0, east = 0, west = 0 }
		if type(plan) == "table" and type(plan.enemies) == "table" then
			for _, e in ipairs(plan.enemies) do
				if counts[e.lane] ~= nil then
					counts[e.lane] += e.count
				end
			end
		end
		local lanes = SupportSquad.assignSoloLanes(counts, humanLanes(map), #bots)
		for i, bot in ipairs(bots) do
			if bot.active then
				bot.lane = lanes[i]
				if bot.lane then
					moveBot(bot, innerPoint(map, bot.lane))
				end
			end
		end
	else
		for _, bot in ipairs(bots) do
			if bot.active then
				bot.lane = busiestLiveLane()
			end
		end
		moveCoop(map)
	end
end

-- 웨이브 시작 자리잡기: DirectorState가 wave로 바뀌면 한 번 실행한다.
-- DirectorService가 이 모듈을 require한 뒤에 DirectorState 값을 만들므로
-- 별도 스레드에서 기다린다(모듈 require를 막지 않는다).
task.spawn(function()
	local directorState = ReplicatedStorage:WaitForChild("DirectorState")
	local lastWavePhase = false
	directorState.Changed:Connect(function()
		local ok, data = pcall(HttpService.JSONDecode, HttpService, directorState.Value)
		if not ok or type(data) ~= "table" then
			return
		end
		local inWave = data.phase == "wave"
		if inWave and not lastWavePhase then
			onWaveStart(data.plan)
		end
		lastWavePhase = inWave
	end)
end)

local function countsText(counts)
	return string.format("solo=%d,coop=%d,none=%d", counts.solo or 0, counts.coop or 0, counts.none or 0)
end

local COUNT_ORDER = { "coop", "solo", "none" }
local function countsSummary(counts)
	local parts = {}
	for _, choice in ipairs(COUNT_ORDER) do
		local n = counts[choice] or 0
		if n > 0 then
			local label = Config.SupportSquads[choice] and Config.SupportSquads[choice].label or "없음"
			table.insert(parts, string.format("%s %d", label, n))
		end
	end
	return table.concat(parts, " · ")
end

-- 로비 종료 시점에 투표를 집계하고 지원대를 만든 뒤 결과를 알린다.
-- DirectorService가 로비 대기 끝에 동기 호출한다(웨이브 1 파티 계산 전).
-- forced 명령(debugSupport)이 있으면 투표를 무시한다.
-- 돌려값: choice("solo"|"coop"|"none"). "none"이면 지원대 없이 진행한다.
function SupportSquad.finalizeLobby()
	local humans = Players:GetPlayers()
	local supportState = ReplicatedStorage:FindFirstChild("SupportState")
	local choices = {}
	if supportState then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, supportState.Value)
		if ok and type(data) == "table" and type(data.votes) == "table" then
			for _, entry in ipairs(data.votes) do
				table.insert(choices, entry.choice)
			end
		end
	end
	local forced = ReplicatedStorage:GetAttribute("DebugSupport")
	local res, isForced = nil, false
	if forced == "solo" or forced == "coop" or forced == "none" then
		local counts = { solo = 0, coop = 0, none = 0 }
		for _, choice in ipairs(choices) do
			if counts[choice] ~= nil then
				counts[choice] += 1
			end
		end
		res = { choice = forced, counts = counts, tie = false, tied = {}, reason = "forced" }
		isForced = true
		ReplicatedStorage:SetAttribute("DebugSupport", nil)
	else
		res = SupportVote.tally(choices, Random.new())
	end
	local botsN = SupportSquad.botCount(#humans)
	local choice = res.choice
	local spawned = choice ~= "none" and botsN > 0
	if spawned then
		SupportSquad.spawnMatch(choice, botsN)
		currentChoice = choice
	else
		currentChoice = "none"
	end
	local label = choice ~= "none" and Config.SupportSquads[choice].label or ""
	local announce
	if not spawned then
		announce = "지원대 없이 시작합니다"
	elseif res.tie then
		announce = string.format(
			"동률(%s)이라 무작위로 %s를 골랐습니다",
			countsSummary(res.counts),
			label
		)
	else
		announce = string.format(
			"다수결로 %s 지원대가 합류합니다 (%s)",
			label,
			countsSummary(res.counts)
		)
	end
	if supportState then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, supportState.Value)
		if not ok or type(data) ~= "table" then
			data = {}
		end
		data.result = choice
		data.tie = res.tie
		data.tied = res.tied or {}
		data.announce = announce
		data.announce_until = Workspace:GetServerTimeNow() + 6
		local okEncode, json = pcall(HttpService.JSONEncode, HttpService, data)
		if okEncode then
			supportState.Value = json
		end
	end
	print(string.format(
		"[Support] vote counts=%s result=%s tie=%s bots=%d%s",
		countsText(res.counts),
		choice,
		tostring(res.tie),
		spawned and botsN or 0,
		isForced and " forced" or ""
	))
	return currentChoice
end

-- 투표 결과대로 빈자리만큼 등불 옆에 만든다.
function SupportSquad.spawnMatch(choice, count)
	SupportSquad.clearMatch()
	local map = getMap()
	local lantern = lanternPosition(map)
	local roles = SupportSquad.rolesFor(choice, count)
	for i, role in ipairs(roles) do
		local bot = {
			UserId = -i,
			IsSupport = true,
			Name = "Support" .. i,
			role = role,
			Character = nil,
			lane = nil,
			damage = 0,
			deaths = 0,
			active = true,
			lastTracker = nil,
			lastSeen = 0,
		}
		table.insert(bots, bot)
		buildModel(bot, choice, map, lantern + Vector3.new((i - 2.5) * 4, 3, 8))
	end
	generation += 1
	local gen = generation
	writeDebugSnapshot()
	task.spawn(function()
		while gen == generation do
			task.wait(0.25)
			for _, bot in ipairs(bots) do
				if bot.active then
					tickBot(bot)
				end
			end
		end
	end)
	task.spawn(function()
		while gen == generation do
			task.wait(1)
			if gen ~= generation then
				break
			end
			local ok, err = pcall(writeDebugSnapshot)
			if not ok then
				warn("[Support] debug snapshot failed: " .. tostring(err))
			end
			local okUnstuck, errUnstuck = pcall(function()
				local map = Workspace:FindFirstChild("Map")
				if map then
					checkUnstuck(map, lanternPosition(map))
				end
			end)
			if not okUnstuck then
				warn("[Support] unstuck check failed: " .. tostring(errUnstuck))
			end
		end
	end)
	if choice == "coop" then
		task.spawn(function()
			while gen == generation do
				task.wait(Config.SupportRetargetSeconds or 5)
				if gen ~= generation then
					break
				end
				for _, bot in ipairs(bots) do
					if bot.active then
						bot.lane = busiestLiveLane()
					end
				end
				moveCoop(map)
			end
		end)
	end
end

-- 판 끝: 지원대를 모두 지우고, 다음 로비 투표 결과로 다시 만든다.
function SupportSquad.clearMatch()
	generation += 1
	for _, bot in ipairs(bots) do
		bot.active = false
	end
	lastReport = bots
	bots = {}
	currentChoice = "none"
	local folder = Workspace:FindFirstChild("Support")
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
	end
end

return SupportSquad
