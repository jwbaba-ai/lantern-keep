-- 전투 판정 서비스 (단일 기준: docs/tasks/day3.md 3단계).
-- 클라이언트는 Tool Activated 때 조준 위치(Vector3)만 Attack으로 보내고,
-- 데미지 계산은 서버에서만 한다. 서버는 쿨다운·사거리·직업을 검증한 뒤
-- 직업별로 판정하고, 피해·처치를 MatchStats 트래커에 공격자별로 기록한다.
-- DirectorService가 웨이브마다 beginWave(tracker)로 기록 대상을 넘긴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassCatalog = require(Shared:WaitForChild("ClassCatalog"))

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
		if body:IsA("BasePart") and (body.Position - center).Magnitude <= radius then
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
	part.Material = Enum.Material.Neon
	part.BrickColor = color
	part.Size = Vector3.new(0.4, 0.4, offset.Magnitude)
	part.CFrame = CFrame.lookAt(fromPos + offset * 0.5, toPos)
	part.Parent = Workspace
	Debris:AddItem(part, 0.2)
end

local function dealDamage(player, body, amount)
	local result = EnemyFactory.damage(body, amount)
	if result == nil then
		return
	end
	if currentTracker then
		MatchStats.recordDamage(currentTracker, player, amount)
	end
end

local function guardianAttack(player, root, _aim)
	local spec = ClassCatalog.guardian
	local facing = root.CFrame.LookVector
	for _, body in ipairs(enemiesInRadius(root.Position, spec.Radius)) do
		local dir = body.Position - root.Position
		if dir.Magnitude > 0.01 and facing:Dot(dir.Unit) > 0 then
			dealDamage(player, body, spec.Damage)
		end
	end
	flash(root.Position, root.Position + facing * spec.Radius, BrickColor.new("Bright orange"))
end

local function rangerAttack(player, root, aim)
	local spec = ClassCatalog.ranger
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local dir = aim - origin
	if dir.Magnitude < 0.01 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = Workspace:Raycast(origin, dir.Unit * spec.Range, params)
	local hitPos = origin + dir.Unit * spec.Range
	if result then
		hitPos = result.Position
		local body = isEnemyPart(result.Instance)
		if body then
			dealDamage(player, body, spec.Damage)
		end
	end
	flash(origin, hitPos, BrickColor.new("Bright yellow"))
end

local function arcanistAttack(player, _root, aim)
	local spec = ClassCatalog.arcanist
	for _, body in ipairs(enemiesInRadius(aim, spec.Radius)) do
		dealDamage(player, body, spec.Damage)
	end
	flash(aim + Vector3.new(0, spec.Radius, 0), aim, BrickColor.new("Bright violet"))
end

local function clericAttack(player, root, _aim)
	local spec = ClassCatalog.cleric
	-- 치유: 반경 안 아군 회복. 체력 25% 이하의 다른 아군을 살리면 revives +1.
	for _, ally in ipairs(Players:GetPlayers()) do
		local char = ally.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local allyRoot = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and allyRoot then
			if (allyRoot.Position - root.Position).Magnitude <= spec.Radius then
				local beforePct = hum.Health / hum.MaxHealth
				hum.Health = math.min(hum.MaxHealth, hum.Health + spec.Heal)
				if ally ~= player and beforePct <= CombatService.ReviveHealthPct and currentTracker then
					MatchStats.recordRevive(currentTracker)
				end
				flash(root.Position, allyRoot.Position, BrickColor.new("Bright green"))
			end
		end
	end
	-- 근접 공격: 반경 안의 적에게 피해.
	for _, body in ipairs(enemiesInRadius(root.Position, spec.MeleeRadius)) do
		dealDamage(player, body, spec.AttackDamage)
	end
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
	-- 쿨다운 검증.
	local now = os.clock()
	if not CombatService.checkCooldown(classKey, player.UserId, now) then
		return
	end
	CombatService.markAttacked(player.UserId, now)
	ATTACKERS[classKey](player, root, CombatService.resolveAim(classKey, root.Position, aim))
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
