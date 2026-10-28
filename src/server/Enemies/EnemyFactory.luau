-- 적 생성·이동 모듈 (타입별 색 구분 파트 + Health 어트리뷰트 + 이름 BillboardGui).
-- spawn(enemyType, lane, waypoints, lantern, onResolved):
--   waypoints를 순서대로 Tween 이동하고, 등불에 닿으면 등불 Health를 깎은 뒤 제거한다.
--   onResolved(enemyType, lane, how) -- how는 "arrived" 또는 "killed".
-- 테스트용 처치: 플레이어가 없을 때만 생성 후 체력 비례 시간
-- (Health * TimePerHealth)이 지나면 "killed"로 처리한다.
-- (TimePerHealth=0.15이면 Brute만 등불까지 닿는다. FallbackWaves 주석 참고.)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyCatalog = require(Shared:WaitForChild("EnemyCatalog"))

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
-- 돌려값: "died"(처치됨), "alive"(생존), nil(이미 정리된 적).
function EnemyFactory.damage(body, amount)
	local entry = active[body]
	if not entry or body.Parent == nil then
		return nil
	end
	local hp = (body:GetAttribute("Health") or 0) - amount
	if hp <= 0 then
		body:SetAttribute("Health", 0)
		entry.resolve("killed")
		return "died"
	end
	body:SetAttribute("Health", hp)
	return "alive"
end

function EnemyFactory.spawn(enemyType, lane, waypoints, lantern, onResolved)
	local spec = EnemyCatalog[enemyType]
	if not spec or #waypoints == 0 then
		return nil
	end

	local body = Instance.new("Part")
	body.Name = enemyType
	body.Size = spec.Size
	body.Position = waypoints[1]
	body.Anchored = true
	body.CanCollide = false
	body.BrickColor = spec.Color
	body:SetAttribute("Health", spec.Health)
	body:SetAttribute("EnemyType", enemyType)
	body:SetAttribute("Lane", lane)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 100, 0, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = enemyType
	label.Parent = gui
	gui.Parent = body
	body.Parent = getEnemiesFolder()

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

	-- 테스트 처치 타이머: 플레이어가 없을 때(자동 테스트)만 쓴다.
	-- 1명 이상 있으면 실제 전투로만 적이 쓰러진다.
	if Config.AutoKillWhenNoPlayers and #Players:GetPlayers() == 0 then
		task.delay(spec.Health * EnemyFactory.TimePerHealth, function()
			resolve("killed")
		end)
	end

	-- 레인 이동. 바깥에서 파트가 제거돼도 멈추도록 Parent를 확인한다.
	task.spawn(function()
		for i = 2, #waypoints do
			if resolved or body.Parent == nil then
				return
			end
			local dist = (waypoints[i] - body.Position).Magnitude
			local tween = TweenService:Create(
				body,
				TweenInfo.new(math.max(dist / spec.Speed, 0.01), Enum.EasingStyle.Linear),
				{ Position = waypoints[i] }
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
