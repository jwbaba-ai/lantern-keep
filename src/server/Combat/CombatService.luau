-- 전투 판정 서비스 (단일 기준: docs/tasks/day3.md 3단계).
-- 클라이언트는 Tool Activated 때 조준 위치(Vector3)만 Attack으로 보내고,
-- 데미지 계산은 서버에서만 한다. 서버는 쿨다운·사거리·직업을 검증한 뒤
-- 직업별로 판정하고, 피해·처치를 MatchStats 트래커에 공격자별로 기록한다.
-- DirectorService가 웨이브마다 beginWave(tracker)로 기록 대상을 넘긴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassCatalog = require(Shared:WaitForChild("ClassCatalog"))
local AutoTarget = require(Shared:WaitForChild("AutoTarget"))

local CombatFolder = script.Parent
local MatchStats = require(CombatFolder.Parent:WaitForChild("Director"):WaitForChild("MatchStats"))
local EnemyFactory = require(CombatFolder.Parent:WaitForChild("Enemies"):WaitForChild("EnemyFactory"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local attackEvent = remotes:FindFirstChild("Attack")
if not attackEvent then
	attackEvent = Instance.new("RemoteEvent")
	attackEvent.Name = "Attack"
	attackEvent.Parent = remotes
end

local CombatService = {
	ReviveHealthPct = 0.25, -- 이 이하 체력의 아군을 치유하면 revives +1
}

local currentTracker = nil
local lastAttackAt = {} -- [userId] = os.clock()

function CombatService.beginWave(tracker)
	currentTracker = tracker
end

function CombatService.endWave()
	currentTracker = nil
end

-- 처치된 몸체는 0.15초 뒤에 지워진다. 그 사이 산 적처럼 다루지 않게
-- 체력이 0 이하면 죽은 몸체로 본다.
local function isAlive(body)
	return (body:GetAttribute("Health") or 0) > 0
end

local function isEnemyPart(inst)
	local enemies = Workspace:FindFirstChild("Enemies")
	while inst do
		if inst.Parent == enemies then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

local function enemiesInRadius(center, radius)
	local out = {}
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return out
	end
	for _, body in ipairs(enemies:GetChildren()) do
		if body:IsA("BasePart") and isAlive(body) and (body.Position - center).Magnitude <= radius then
			table.insert(out, body)
		end
	end
	return out
end

-- 공격 방향으로 짧게 남는 빛 기둥. 0.2초 뒤에 사라진다.
local function flash(fromPos, toPos, color)
	local offset = toPos - fromPos
	if offset.Magnitude < 0.5 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.BrickColor = color
	part.Size = Vector3.new(0.4, 0.4, offset.Magnitude)
	part.CFrame = CFrame.lookAt(fromPos + offset * 0.5, toPos)
	part.Parent = Workspace
	Debris:AddItem(part, 0.2)
end

-- 공격 연출용 파트 예산. 동시에 남아 있는 서버 효과 파트는 80개까지만 둔다.
-- 넘으면 효과를 만들지 않는다 (피해 판정에는 영향 없음).
local activeFxParts = 0
local MAX_FX_PARTS = 80
local function fxClaim(n)
	if activeFxParts + n > MAX_FX_PARTS then
		return false
	end
	activeFxParts += n
	return true
end
local function fxRelease(n, afterSeconds)
	task.delay(afterSeconds, function()
		activeFxParts = math.max(0, activeFxParts - n)
	end)
end

-- 효과 파트 공용: 고정 + 사격·이동 판정에 끼지 않음 (공통 규칙 10).
local function fxPart(props)
	local p = Instance.new("Part")
	p.Name = props.Name or "Fx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	if props.Size then
		p.Size = props.Size
	end
	p.Material = props.Material or Enum.Material.Neon
	if props.Color then
		p.Color = props.Color
	elseif props.BrickColor then
		p.BrickColor = props.BrickColor
	end
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.CFrame then
		p.CFrame = props.CFrame
	elseif props.Position then
		p.Position = props.Position
	end
	p.Parent = Workspace
	return p
end

local function fxDestroy(part, afterSeconds)
	task.delay(afterSeconds, function()
		pcall(function()
			part:Destroy()
		end)
	end)
end

-- ranger: 빛 기둥 대신 화살(노란 Neon)이 날아가고, 맞은 곳에 작은 노란 공이 커지며 사라진다.
local function rangerFx(origin, hitPos)
	local dist = (hitPos - origin).Magnitude
	if dist >= 0.5 and fxClaim(1) then
		local flight = math.max(dist / 240, 0.05)
		fxRelease(1, flight + 0.05)
		pcall(function()
			local arrow = fxPart({
				Name = "Arrow",
				Size = Vector3.new(0.2, 0.2, 2),
				CFrame = CFrame.lookAt(origin, hitPos),
				BrickColor = BrickColor.new("Bright yellow"),
			})
			TweenService:Create(
				arrow,
				TweenInfo.new(flight, Enum.EasingStyle.Linear),
				{ Position = hitPos }
			):Play()
			fxDestroy(arrow, flight + 0.05)
		end)
	end
	if fxClaim(1) then
		fxRelease(1, 0.2)
		pcall(function()
			local ball = fxPart({
				Name = "HitPop",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.5, 0.5, 0.5),
				Position = hitPos,
				BrickColor = BrickColor.new("Bright yellow"),
			})
			TweenService:Create(
				ball,
				TweenInfo.new(0.15),
				{ Size = Vector3.new(1.5, 1.5, 1.5), Transparency = 1 }
			):Play()
			fxDestroy(ball, 0.2)
		end)
	end
end

-- arcanist: 조준점 위 12스터드에서 보라 공이 떨어진 뒤, 보라 공과 바닥 고리가 함께 퍼진다.
local function arcanistFx(aim, radius)
	if not fxClaim(3) then
		return
	end
	fxRelease(3, 0.6)
	pcall(function()
		local drop = fxPart({
			Name = "Drop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.5, 1.5, 1.5),
			Position = aim + Vector3.new(0, 12, 0),
			BrickColor = BrickColor.new("Bright violet"),
		})
		TweenService:Create(
			drop,
			TweenInfo.new(0.15, Enum.EasingStyle.Linear),
			{ Position = aim }
		):Play()
		fxDestroy(drop, 0.18)
		task.delay(0.15, function()
			local dia = math.max(1, radius * 2)
			local boom = fxPart({
				Name = "Boom",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1, 1, 1),
				Position = aim,
				BrickColor = BrickColor.new("Bright violet"),
				Transparency = 0.3,
			})
			TweenService:Create(
				boom,
				TweenInfo.new(0.35),
				{ Size = Vector3.new(dia, dia, dia), Transparency = 1 }
			):Play()
			fxDestroy(boom, 0.4)
			local ring = fxPart({
				Name = "BlastRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 1, 1),
				CFrame = CFrame.new(aim) * CFrame.Angles(0, 0, math.rad(90)),
				BrickColor = BrickColor.new("Bright violet"),
				Transparency = 0.3,
			})
			TweenService:Create(
				ring,
				TweenInfo.new(0.35),
				{ Size = Vector3.new(0.2, dia, dia), Transparency = 1 }
			):Play()
			fxDestroy(ring, 0.4)
		end)
	end)
end

-- guardian: 바라보는 방향(수평) ±40도에 주황 Neon 조각 3개를 0.2초 보인다.
local function guardianFx(rootPos, facing, radius)
	if not fxClaim(3) then
		return
	end
	fxRelease(3, 0.25)
	pcall(function()
		local flat = Vector3.new(facing.X, 0, facing.Z)
		if flat.Magnitude < 0.01 then
			flat = Vector3.new(0, 0, -1)
		end
		local base = CFrame.lookAt(rootPos, rootPos + flat)
		for _, ang in ipairs({ -40, 0, 40 }) do
			local dir = (base * CFrame.Angles(0, math.rad(ang), 0)).LookVector
			local at = rootPos + dir * radius * 0.6
			local shard = fxPart({
				Name = "Slash",
				Size = Vector3.new(0.4, 0.4, 1.6),
				CFrame = CFrame.lookAt(at, at + dir),
				BrickColor = BrickColor.new("Bright orange"),
			})
			fxDestroy(shard, 0.2)
		end
	end)
end

-- 치유·근접 고리. feetPos는 발밑 위치.
local function ringFx(feetPos, color, startDia, endDia, rise, seconds)
	if not fxClaim(1) then
		return
	end
	fxRelease(1, seconds + 0.05)
	pcall(function()
		local ring = fxPart({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, startDia, startDia),
			CFrame = CFrame.new(feetPos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Transparency = 0.3,
		})
		TweenService:Create(
			ring,
			TweenInfo.new(seconds),
			{ CFrame = CFrame.new(feetPos + Vector3.new(0, rise, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 1 }
		):Play()
		fxDestroy(ring, seconds + 0.05)
	end)
end

-- 공격자: 플레이어(Player) 또는 지원대 테이블.
-- { UserId, Character(모델), role 또는 Class 어트리뷰트 }를 가진다.
-- MatchStats에는 이 값을 그대로 넘긴다.
local function dealDamage(attacker, body, amount)
	local result = EnemyFactory.damage(body, amount)
	if result == nil then
		return
	end
	if currentTracker then
		-- 실제로 깎은 체력만 기록한다 (넘치는 피해 제외).
		MatchStats.recordDamage(currentTracker, attacker, result.dealt)
	end
end

local function guardianAttack(attacker, root, _aim, facingOverride)
	local spec = ClassCatalog.guardian
	local facing = facingOverride or root.CFrame.LookVector
	for _, body in ipairs(enemiesInRadius(root.Position, spec.Radius)) do
		local dir = body.Position - root.Position
		if dir.Magnitude > 0.01 and facing:Dot(dir.Unit) > 0 then
			dealDamage(attacker, body, spec.Damage)
		end
	end
	guardianFx(root.Position, facing, spec.Radius)
end

local function rangerAttack(attacker, root, aim)
	local spec = ClassCatalog.ranger
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local dir = aim - origin
	if dir.Magnitude < 0.01 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.Character }
	local result = Workspace:Raycast(origin, dir.Unit * spec.Range, params)
	local hitPos = origin + dir.Unit * spec.Range
	if result then
		hitPos = result.Position
		local body = isEnemyPart(result.Instance)
		if body then
			dealDamage(attacker, body, spec.Damage)
		end
	end
	rangerFx(origin, hitPos)
end

local function arcanistAttack(attacker, _root, aim)
	local spec = ClassCatalog.arcanist
	for _, body in ipairs(enemiesInRadius(aim, spec.Radius)) do
		dealDamage(attacker, body, spec.Damage)
	end
	arcanistFx(aim, spec.Radius)
end

-- 치유 대상: 사람 캐릭터와 지원대 모델 모두.
local function allyCharacters()
	local out = {}
	for _, ally in ipairs(Players:GetPlayers()) do
		if ally.Character then
			table.insert(out, ally.Character)
		end
	end
	local folder = Workspace:FindFirstChild("Support")
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") then
				table.insert(out, model)
			end
		end
	end
	return out
end

local function clericHeal(attacker, root)
	local spec = ClassCatalog.cleric
	-- 치유: 반경 안 아군 회복. 체력 25% 이하의 다른 아군을 살리면 revives +1.
	local attackerChar = attacker.Character
	for _, char in ipairs(allyCharacters()) do
		local hum = char:FindFirstChildOfClass("Humanoid")
		local allyRoot = char:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and allyRoot then
			if (allyRoot.Position - root.Position).Magnitude <= spec.Radius then
				local beforePct = hum.Health / hum.MaxHealth
				hum.Health = math.min(hum.MaxHealth, hum.Health + spec.Heal)
				if char ~= attackerChar and beforePct <= CombatService.ReviveHealthPct and currentTracker then
					MatchStats.recordRevive(currentTracker, attacker)
				end
				ringFx(
					allyRoot.Position - Vector3.new(0, 2.5, 0),
					Color3.fromRGB(60, 220, 90),
					1.5, 1.5, 3, 0.5
				)
			end
		end
	end
end

local function clericMelee(attacker, root)
	local spec = ClassCatalog.cleric
	-- 근접 공격: 반경 안의 적에게 피해.
	for _, body in ipairs(enemiesInRadius(root.Position, spec.MeleeRadius)) do
		dealDamage(attacker, body, spec.AttackDamage)
	end
	ringFx(
		root.Position - Vector3.new(0, 2.5, 0),
		Color3.new(1, 1, 1),
		1, spec.MeleeRadius * 2, 0, 0.2
	)
end

local function clericAttack(attacker, root, _aim)
	clericHeal(attacker, root)
	clericMelee(attacker, root)
end

local ATTACKERS = {
	guardian = guardianAttack,
	ranger = rangerAttack,
	arcanist = arcanistAttack,
	cleric = clericAttack,
}

-- 조준 위치 판정 (단일 기준: docs/tasks/day4.md 0-1.1).
-- guardian·cleric은 조준을 쓰지 않으므로 그대로 허용한다.
-- ranger는 조준 방향만 쓴다(레이 길이는 Range 고정). 그대로 허용한다.
-- arcanist는 조준 위치를 캐릭터 기준 Range 안으로 잘라서(clamp) 쓴다.
-- 이 함수는 공격을 거부하지 않는다. 쿨다운은 checkCooldown이 맡는다.
function CombatService.resolveAim(classKey, rootPosition, aim)
	if classKey == "arcanist" then
		local range = ClassCatalog.arcanist.Range
		local offset = aim - rootPosition
		if offset.Magnitude > range then
			return rootPosition + offset.Unit * range
		end
	end
	return aim
end

-- 쿨다운이 지났으면 true. 직업·쿨다운 검증용.
function CombatService.checkCooldown(classKey, userId, now)
	local spec = ClassCatalog[classKey]
	if not spec then
		return false
	end
	local last = lastAttackAt[userId]
	if last and now - last < spec.Cooldown then
		return false
	end
	return true
end

function CombatService.markAttacked(userId, now)
	lastAttackAt[userId] = now
end

-- 지금 웨이브의 기록 대상. 지원대 피해 누적용. 웨이브 밖이면 nil.
function CombatService.getTracker()
	return currentTracker
end

-- 반경 안에서 체력 비율이 가장 낮은 살아 있는 아군(사람·지원대) 모델과 비율.
-- 없으면 nil, 1. 지원대 cleric의 치유 판단용.
function CombatService.lowestAllyInRadius(root, radius)
	local worst = nil
	local worstPct = nil
	for _, char in ipairs(allyCharacters()) do
		local hum = char:FindFirstChildOfClass("Humanoid")
		local allyRoot = char:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and hum.MaxHealth > 0 and allyRoot then
			if (allyRoot.Position - root.Position).Magnitude <= radius then
				local pct = hum.Health / hum.MaxHealth
				if worstPct == nil or pct < worstPct then
					worst = char
					worstPct = pct
				end
			end
		end
	end
	return worst, worstPct or 1
end

-- cleric 근접 공격만 따로. 치유가 필요 없을 때 지원대가 쓴다.
function CombatService.clericMelee(attacker, root)
	clericMelee(attacker, root)
end

-- 공격자(플레이어·지원대)의 직업 공격 1회. 쿨다운 검사를 함께 한다.
-- 플레이어 RemoteEvent 경로와 지원대 행동 루프가 같은 함수를 쓴다.
-- facingOverride: guardian 자동 조준 방향(선택, 없으면 LookVector).
function CombatService.performAttack(attacker, classKey, root, aim, facingOverride)
	local spec = ClassCatalog[classKey]
	if not spec then
		return
	end
	local userId = attacker.UserId
	if userId == nil then
		return
	end
	local now = os.clock()
	if not CombatService.checkCooldown(classKey, userId, now) then
		return
	end
	CombatService.markAttacked(userId, now)
	ATTACKERS[classKey](attacker, root, CombatService.resolveAim(classKey, root.Position, aim), facingOverride)
end

attackEvent.OnServerEvent:Connect(function(player, aim)
	if typeof(aim) ~= "Vector3" then
		return
	end
	local classKey = player:GetAttribute("Class")
	local spec = classKey and ClassCatalog[classKey]
	if not spec then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- 플레이어 경로에서만 자동 조준을 쓴다. 지원대는 지금 목표 선택을 그대로 둔다.
	local aimPoint = aim
	local facingOverride = nil
	if classKey == "ranger" or classKey == "arcanist" or classKey == "guardian" then
		local list = {}
		local enemies = Workspace:FindFirstChild("Enemies")
		if enemies then
			for _, body in ipairs(enemies:GetChildren()) do
				if body:IsA("BasePart") and isAlive(body) then
					table.insert(list, { pos = body.Position, ref = body })
				end
			end
		end
		local picked = AutoTarget.pick(classKey, root.Position, aim, list)
		if picked then
			if classKey == "guardian" then
				local dir = picked.pos - root.Position
				dir = Vector3.new(dir.X, 0, dir.Z)
				if dir.Magnitude > 0.01 then
					facingOverride = dir.Unit
				end
			else
				aimPoint = picked.pos
			end
		end
	end
	-- 쿨다운 검증은 performAttack이 맡는다.
	CombatService.performAttack(player, classKey, root, aimPoint, facingOverride)
end)

-- 사망 기록 (리스폰은 기본 리스폰을 그대로 쓴다).
local function hookDeaths(player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		character:WaitForChild("Humanoid", 5)
		humanoid = character:FindFirstChildOfClass("Humanoid")
	end
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		if currentTracker then
			MatchStats.recordDeath(currentTracker, player)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		task.defer(hookDeaths, player)
	end)
	if player.Character then
		task.defer(hookDeaths, player)
	end
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.defer(hookDeaths, player)
	end)
end)

return CombatService
