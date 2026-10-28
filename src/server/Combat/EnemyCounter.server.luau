-- 적 반격 (단일 기준: docs/tasks/day3.md 4단계, 최소 구현).
-- 1초 틱으로 돈다. Grunt·Brute·Runner는 반경 5 안 플레이어에게 초당 피해,
-- Archer는 2초마다 반경 40 안 가장 가까운 플레이어에게 8 피해,
-- Shaman은 3초마다 반경 15 안 적을 20 회복한다.
-- 플레이어 사망은 CombatService가 deaths로 기록하고, 리스폰은 기본 리스폰을 쓴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyCatalog = require(Shared:WaitForChild("EnemyCatalog"))

local MELEE_DAMAGE = { Grunt = 8, Brute = 15, Runner = 5 }
local MELEE_RADIUS = 5
local ARCHER_RANGE = 40
local ARCHER_DAMAGE = 8
local SHAMAN_RANGE = 15
local SHAMAN_HEAL = 20

local function playerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function hurtPlayer(player, amount)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(amount)
	end
end

local tick = 0
while true do
	task.wait(1)
	tick += 1
	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		continue
	end
	for _, body in ipairs(folder:GetChildren()) do
		if not body:IsA("BasePart") then
			continue
		end
		local enemyType = body:GetAttribute("EnemyType")
		if MELEE_DAMAGE[enemyType] then
			for _, player in ipairs(Players:GetPlayers()) do
				local root = playerRoot(player)
				if root and (root.Position - body.Position).Magnitude <= MELEE_RADIUS then
					hurtPlayer(player, MELEE_DAMAGE[enemyType])
				end
			end
		elseif enemyType == "Archer" and tick % 2 == 0 then
			local nearest = nil
			local nearestDist = ARCHER_RANGE
			for _, player in ipairs(Players:GetPlayers()) do
				local root = playerRoot(player)
				if root then
					local dist = (root.Position - body.Position).Magnitude
					if dist <= nearestDist then
						nearest = player
						nearestDist = dist
					end
				end
			end
			if nearest then
				hurtPlayer(nearest, ARCHER_DAMAGE)
			end
		elseif enemyType == "Shaman" and tick % 3 == 0 then
			for _, other in ipairs(folder:GetChildren()) do
				if other:IsA("BasePart") and other ~= body then
					if (other.Position - body.Position).Magnitude <= SHAMAN_RANGE then
						local maxHp = EnemyCatalog[other:GetAttribute("EnemyType")]
						maxHp = maxHp and maxHp.Health or 0
						local hp = other:GetAttribute("Health") or 0
						other:SetAttribute("Health", math.min(maxHp, hp + SHAMAN_HEAL))
					end
				end
			end
		end
	end
end
