-- 적 생성·이동 모듈 (타입별 색 구분 파트 + Health 어트리뷰트 + 이름 BillboardGui).
-- spawn(enemyType, lane, waypoints, lantern, onResolved, mods):
--   waypoints를 순서대로 Tween 이동하고, 등불에 닿으면 등불 Health를 깎은 뒤 제거한다.
--   onResolved(enemyType, lane, how) -- how는 "arrived" 또는 "killed".
--   mods(선택): { healthMult, sizeMult, namePrefix } — 이벤트 효과용.
-- 테스트용 처치: 플레이어가 없을 때만 생성 후 체력 비례 시간
-- (Health * TimePerHealth)이 지나면 "killed"로 처리한다.
-- (TimePerHealth=0.15이면 Brute만 등불까지 닿는다. FallbackWaves 주석 참고.)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyCatalog = require(Shared:WaitForChild("EnemyCatalog"))
-- 파티 인원(사람 + 지원대)은 SupportSquad가 셈한다.
-- SupportSquad는 Config·ClassCatalog·SupportVote만 require하므로 순환 참조가 없다.
local SupportSquad = require(script.Parent.Parent:WaitForChild("Support"):WaitForChild("SupportSquad"))
local Figures = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("Figures"))
local Labels = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("Labels"))

-- 적 한국어 이름표(EnemyCatalog은 고치지 않는다).
local ENEMY_KO = {
	Grunt = "졸개",
	Runner = "질주병",
	Brute = "거한",
	Archer = "궁병",
	Shaman = "주술사",
}

-- 종류별 실루엣 (day11c, 기본 파트만. 몸체 크기 기준 비율이라 정예 sizeMult에도 맞는다).
-- 눈은 앞(-Z)면에 붙인다. 이동 트윈이 CFrame으로 방향을 틀면 함께 돈다.
-- Grunt·Runner 2개, Brute·Archer·Shaman 3개, 그 밖(보스 포함)은 머리+눈 2개.
local function buildSilhouette(body, enemyType)
	local w, h, d = body.Size.X, body.Size.Y, body.Size.Z
	local cf = body.CFrame
	local color = body.BrickColor
	-- 머리 블록.
	local headSize = Vector3.new(w * 0.55, h * 0.28, d * 0.55)
	local headY = h / 2 + headSize.Y / 2 - h * 0.05
	local headCf = cf * CFrame.new(0, headY, 0)
	if enemyType == "Runner" then
		headCf = headCf * CFrame.Angles(0.35, 0, 0) -- 앞으로 기운 머리
	end
	Figures.attach(body, {
		Name = "Head",
		Size = headSize,
		CFrame = headCf,
		BrickColor = color,
	})
	-- 빛나는 눈 (얇은 Neon 가로 막대, 빨강).
	Figures.attach(body, {
		Name = "Eyes",
		Size = Vector3.new(w * 0.5, math.max(0.15, h * 0.07), 0.2),
		CFrame = cf * CFrame.new(0, h * 0.15, -(d / 2 + 0.1)),
		Material = Enum.Material.Neon,
		BrickColor = BrickColor.new("Bright red"),
	})
	if enemyType == "Brute" then
		-- 넓은 어깨 블록.
		Figures.attach(body, {
			Name = "Shoulders",
			Size = Vector3.new(w * 1.5, h * 0.22, d * 1.15),
			CFrame = cf * CFrame.new(0, h * 0.32, 0),
			BrickColor = color,
		})
	elseif enemyType == "Archer" then
		-- 등에 활 (얇은 세로 막대).
		Figures.attach(body, {
			Name = "Bow",
			Size = Vector3.new(0.2, h * 0.95, 0.2),
			CFrame = cf * CFrame.new(w * 0.3, h * 0.05, d / 2 + 0.15),
			Material = Enum.Material.Wood,
			BrickColor = BrickColor.new("Reddish brown"),
		})
	elseif enemyType == "Shaman" then
		-- 머리 위 뿔 장식 (보라).
		local hornSize = Vector3.new(w * 0.22, h * 0.4, d * 0.22)
		Figures.attach(body, {
			Name = "Horn",
			Size = hornSize,
			CFrame = cf * CFrame.new(0, headY + headSize.Y / 2 + hornSize.Y / 2 - h * 0.05, 0),
			Material = Enum.Material.Neon,
			BrickColor = BrickColor.new("Bright violet"),
		})
	end
end

local EnemyFactory = {
	TimePerHealth = 0.15, -- 초/체력. 테스트 처치까지 걸리는 시간 배율
}

-- 살아 있는 적 파트 -> { resolve, spec }. CombatService.damage가 이 표를
-- 거쳐 처치하면 이동 루프와 테스트 타이머가 killed 경로로 정리된다.
local active = {}

local function getEnemiesFolder()
	local f = workspace:FindFirstChild("Enemies")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Enemies"
		f.Parent = workspace
	end
	return f
end

-- 적 폴더를 돌려준다 (없으면 만든다).
function EnemyFactory.getFolder()
	return getEnemiesFolder()
end

-- 적 파트에 피해를 준다. 전투 데미지의 유일한 입구다.
-- 돌려값: { status = "died"|"alive", dealt = 실제로 깎은 체력 }.
-- dealt는 남은 체력과 피해 중 작은 값(넘치는 피해 제외). nil(이미 정리된 적).
function EnemyFactory.damage(body, amount)
	local entry = active[body]
	if not entry or body.Parent == nil then
		return nil
	end
	local before = body:GetAttribute("Health") or 0
	local dealt = math.min(before, amount)
	local hp = before - amount
	if hp <= 0 then
		body:SetAttribute("Health", 0)
		entry.resolve("killed")
		return { status = "died", dealt = dealt }
	end
	body:SetAttribute("Health", hp)
	return { status = "alive", dealt = dealt }
end

-- mods(선택): { healthMult, sizeMult, namePrefix } — 이벤트 효과용.
-- dayHealthMult(선택): Day 체력 배율. DirectorService가 DayRules.scale(day).health를 인자로 넘긴다.
function EnemyFactory.spawn(enemyType, lane, waypoints, lantern, onResolved, mods, dayHealthMult)
	local spec = EnemyCatalog[enemyType]
	if not spec or #waypoints == 0 then
		return nil
	end

	-- 파티 인원 보정: 적 체력 배율 (Config.PartyHealthScale, 스폰 시점 인원 기준).
	-- 인원은 사람 + 지원대 수(최대 SupportMaxParty)다.
	local partySize = SupportSquad.partySize()
	local eventMult = (mods and mods.healthMult) or 1
	local dayMult = dayHealthMult or 1
	local maxHp = math.max(1, math.floor(spec.Health * Config.PartyHealthScale[partySize] * eventMult * dayMult + 0.5))

	local body = Instance.new("Part")
	body.Name = enemyType
	if mods and mods.sizeMult then
		body.Size = spec.Size * mods.sizeMult
	else
		body.Size = spec.Size
	end
	body.Position = waypoints[1]
	body.Anchored = true
	body.CanCollide = false
	body.BrickColor = spec.Color
	body:SetAttribute("Health", maxHp)
	body:SetAttribute("EnemyType", enemyType)
	body:SetAttribute("Lane", lane)

	-- DisplayName이 있는 보스는 그대로, 이벤트 접두어(namePrefix)는 앞에 붙인다.
	-- 보스만 벽 너머로 보이게(AlwaysOnTop) 유지한다.
	local displayName = spec.DisplayName or ENEMY_KO[enemyType] or enemyType
	body.Parent = getEnemiesFolder()
	buildSilhouette(body, enemyType)
	-- 종류·정예 크기마다 키가 다르니 고정값을 쓰지 않고,
	-- 몸체와 장식 중 가장 높은 윗면 위 1.5에 이름표를 둔다.
	local top = body.Position.Y + body.Size.Y / 2
	for _, part in ipairs(body:GetChildren()) do
		if part:IsA("BasePart") then
			top = math.max(top, part.Position.Y + part.Size.Y / 2)
		end
	end
	Labels.attach(body, body, {
		text = ((mods and mods.namePrefix) or "") .. displayName,
		maxDistance = 70,
		alwaysOnTop = spec.DisplayName ~= nil,
		offset = Vector3.new(0, top - body.Position.Y + 1.5, 0),
	})

	local resolved = false
	local function resolve(how)
		if resolved then
			return
		end
		resolved = true
		active[body] = nil
		if onResolved then
			task.spawn(onResolved, enemyType, lane, how)
		end
		body:Destroy()
	end
	active[body] = { resolve = resolve, spec = spec }

	-- 테스트 처치 타이머: 사람도 지원대도 없을 때(자동 테스트)만 쓴다.
	-- 사람이 0명이어도 지원대가 있으면 실제 전투로 진행한다.
	if Config.AutoKillWhenNoPlayers and #Players:GetPlayers() == 0 and SupportSquad.activeCount() == 0 then
		task.delay(maxHp * EnemyFactory.TimePerHealth, function()
			resolve("killed")
		end)
	end

	-- 레인 이동. 바깥에서 파트가 제거돼도 멈추도록 Parent를 확인한다.
	-- 각 구간 시작에 방향을 먼저 즉시 맞추고, 트윈은 위치만 옮긴다.
	-- Position 트윈으로 되돌리지 않는다(용접 장식이 따라오지 않는다).
	-- 속도·경로·도착 판정은 그대로다.
	task.spawn(function()
		for i = 2, #waypoints do
			if resolved or body.Parent == nil then
				return
			end
			local dist = (waypoints[i] - body.Position).Magnitude
			body.CFrame = Figures.faceFlatCFrame(body.Position, body.CFrame.LookVector, waypoints[i])
			local goal = CFrame.new(waypoints[i]) * body.CFrame.Rotation
			local tween = TweenService:Create(
				body,
				TweenInfo.new(math.max(dist / spec.Speed, 0.01), Enum.EasingStyle.Linear),
				{ CFrame = goal }
			)
			local done = false
			tween.Completed:Connect(function()
				done = true
			end)
			tween:Play()
			while not done and not resolved and body.Parent ~= nil do
				task.wait(0.1)
			end
			if resolved or body.Parent == nil then
				tween:Cancel()
				return
			end
		end
		if resolved then
			return
		end
		local hp = lantern:GetAttribute("Health") or 0
		lantern:SetAttribute("Health", math.max(0, hp - spec.LanternDamage))
		resolve("arrived")
	end)

	return body
end

return EnemyFactory
