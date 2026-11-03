-- 타격 반짝임과 피해 숫자 (단일 기준: docs/tasks/day14.md 2단계).
-- 적의 Health 어트리뷰트(서버에서 복제됨)만 읽는다. 서버 코드는 고치지 않는다.
-- 효과 코드가 실패해도 전투와 경기는 멈추지 않는다 (핸들러는 pcall로 감싼다).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FLASH_COLOR = Color3.new(1, 1, 1)
local FLASH_SECONDS = 0.1
local NUMBER_LIFETIME = 0.6
local NUMBER_RISE = 3
local MAX_NUMBERS = 20
local VISIBLE_RANGE = 80
-- 처치 폭발: 피해 숫자 20개 제한과 별도로 조각은 동시에 60개까지만 둔다.
local MAX_SHARDS = 60
local SHARD_LIFETIME = 0.4
local SHARD_DIRS = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

local player = Players.LocalPlayer

-- 적 파트 -> 마지막으로 본 체력.
local lastHealth = {}
-- 적 파트 -> 원래 색 (몸체 + 자손 BasePart, 처음 맞았을 때 한 번만 저장).
local originalColors = {}
-- 화면에 떠 있는 피해 숫자 수.
local activeNumbers = 0
-- 화면에 떠 있는 처치 조각 수 (숫자 제한과 별도).
local activeShards = 0

local function characterRoot()
	local character = player.Character
	if character then
		return character:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

-- 몸체와 자손 BasePart를 흰색으로 0.1초 바꿨다 되돌린다.
-- 원래 색은 적마다 처음 한 번만 저장한다 (연타 중에 흰색이 저장되지 않게).
local function flash(body)
	pcall(function()
		local saved = originalColors[body]
		if saved == nil then
			saved = {}
			local parts = { body }
			for _, part in ipairs(body:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(parts, part)
				end
			end
			for _, part in ipairs(parts) do
				saved[part] = part.Color
			end
			originalColors[body] = saved
		end
		for part, _ in pairs(saved) do
			if part.Parent ~= nil then
				part.Color = FLASH_COLOR
			end
		end
		task.delay(FLASH_SECONDS, function()
			local current = originalColors[body]
			if current then
				for part, color in pairs(current) do
					if part.Parent ~= nil then
						part.Color = color
					end
				end
			end
		end)
	end)
end

-- 줄어든 체력을 맞은 위치 위에 띄운다. 클라이언트 전용이라 전투 판정에 끼지 않는다.
local function showNumber(body, amount, killed)
	if activeNumbers >= MAX_NUMBERS then
		return
	end
	local root = characterRoot()
	if root and (body.Position - root.Position).Magnitude > VISIBLE_RANGE then
		return
	end
	activeNumbers += 1
	local ok, anchor = pcall(function()
		local dot = Instance.new("Part")
		dot.Name = "HitNumber"
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.Transparency = 1
		dot.Size = Vector3.new(0.5, 0.5, 0.5)
		dot.Position = body.Position
			+ Vector3.new(math.random() * 2 - 1, body.Size.Y / 2 + 1, math.random() * 2 - 1)
		dot.Parent = Workspace
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Damage"
		billboard.Size = UDim2.fromOffset(100, 36)
		billboard.AlwaysOnTop = true
		billboard.Parent = dot
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		if killed then
			label.TextColor3 = Color3.fromRGB(255, 220, 60)
		else
			label.TextColor3 = Color3.new(1, 1, 1)
		end
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.Text = tostring(amount)
		label.Parent = billboard
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 28
		cap.Parent = label
		TweenService:Create(
			dot,
			TweenInfo.new(NUMBER_LIFETIME, Enum.EasingStyle.Linear),
			{ Position = dot.Position + Vector3.new(0, NUMBER_RISE, 0) }
		):Play()
		TweenService:Create(
			label,
			TweenInfo.new(NUMBER_LIFETIME, Enum.EasingStyle.Linear),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		):Play()
		return dot
	end)
	if not ok or anchor == nil then
		activeNumbers = math.max(0, activeNumbers - 1)
		return
	end
	task.delay(NUMBER_LIFETIME + 0.1, function()
		anchor:Destroy()
		activeNumbers = math.max(0, activeNumbers - 1)
	end)
end

-- 처치 폭발: 적 색의 작은 조각 6개가 사방으로 튀며 사라진다.
-- 몸체는 클라이언트에서만 0.15초 동안 크기를 줄인다.
local function killBurst(body)
	if activeShards + 6 > MAX_SHARDS then
		return
	end
	activeShards += 6
	local ok, shards = pcall(function()
		local made = {}
		local start = body.Position
		local color = body.Color
		for _, dir in ipairs(SHARD_DIRS) do
			local jitter = Vector3.new(
				math.random() - 0.5,
				math.random() - 0.5,
				math.random() - 0.5
			)
			local shard = Instance.new("Part")
			shard.Name = "KillShard"
			shard.Anchored = true
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.Size = Vector3.new(0.4, 0.4, 0.4)
			shard.Color = color
			shard.Position = start
			shard.Parent = Workspace
			TweenService:Create(
				shard,
				TweenInfo.new(SHARD_LIFETIME, Enum.EasingStyle.Linear),
				{ Position = start + (dir + jitter) * 3, Transparency = 1 }
			):Play()
			table.insert(made, shard)
		end
		return made
	end)
	if not ok or shards == nil then
		activeShards = math.max(0, activeShards - 6)
		return
	end
	task.delay(SHARD_LIFETIME + 0.1, function()
		for _, shard in ipairs(shards) do
			pcall(function()
				shard:Destroy()
			end)
		end
		activeShards = math.max(0, activeShards - 6)
	end)
end

local function hookEnemy(body)
	if not body:IsA("BasePart") then
		return
	end
	if lastHealth[body] ~= nil then
		return
	end
	lastHealth[body] = body:GetAttribute("Health") or 0
	body:GetAttributeChangedSignal("Health"):Connect(function()
		pcall(function()
			local now = body:GetAttribute("Health") or 0
			local before = lastHealth[body] or now
			lastHealth[body] = now
			if now >= before then
				return -- 치유(Shaman)·같은 값: 이전 값만 고치고 효과는 없다.
			end
			local amount = math.floor(before - now + 0.5)
			flash(body)
			showNumber(body, amount, now <= 0)
			if now <= 0 then
				killBurst(body)
				pcall(function()
					TweenService:Create(
						body,
						TweenInfo.new(0.15, Enum.EasingStyle.Linear),
						{ Size = body.Size * 0.3 }
					):Play()
				end)
			end
		end)
	end)
end

-- 적 폴더가 늦게 생겨도 경고 없이 기다린다.
local enemies = nil
while enemies == nil do
	enemies = Workspace:WaitForChild("Enemies", 60)
end
for _, child in ipairs(enemies:GetChildren()) do
	hookEnemy(child)
end
enemies.ChildAdded:Connect(hookEnemy)
enemies.ChildRemoved:Connect(function(child)
	lastHealth[child] = nil
	originalColors[child] = nil
end)
