-- 전투 입력 전달 + 누르고 있으면 연속 공격 + 쿨다운 막대 (단일 기준: docs/tasks/day14c-fix.md 4단계).
-- 직업 Tool의 Activated에서 반복을 시작하고 Deactivated·Tool 해제·캐릭터 사망 때 멈춘다.
-- 간격은 ClassCatalog[직업].Cooldown + 0.05초. 쿨다운 검사는 서버가 그대로 맡는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassCatalog = require(Shared:WaitForChild("ClassCatalog"))
local UiScale = require(script.Parent:WaitForChild("UiScale"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackEvent = remotes:WaitForChild("Attack")

-- 쿨다운 막대: 화면 아래 가운데(핫바 바로 위) 가로 120x6. Tool을 들고 있을 때만 보인다.
local gui = Instance.new("ScreenGui")
gui.Name = "CombatBar"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local barBack = Instance.new("Frame")
barBack.Name = "CooldownBar"
barBack.AnchorPoint = Vector2.new(0.5, 1)
barBack.Position = UDim2.new(0.5, 0, 1, -80)
barBack.Size = UDim2.new(0, 120, 0, 6)
barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
barBack.BackgroundTransparency = 0.25
barBack.BorderSizePixel = 0
barBack.Active = false
barBack.Visible = false
barBack.Parent = gui

local barScale = Instance.new("UIScale")
barScale.Parent = barBack
UiScale.watch(function(s)
	barScale.Scale = s
end)

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
barFill.BorderSizePixel = 0
barFill.Active = false
barFill.Parent = barBack

local attackToken = 0
local function stopLoop()
	attackToken += 1
end

local function equippedClassTool()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("ClassTool") then
		return tool
	end
	return nil
end

local function refreshBar()
	barBack.Visible = equippedClassTool() ~= nil
end

local function sendAttack(spec)
	pcall(function()
		attackEvent:FireServer(mouse.Hit.Position)
	end)
	barFill.Size = UDim2.new(0, 0, 1, 0)
	TweenService:Create(barFill, TweenInfo.new(spec.Cooldown), { Size = UDim2.new(1, 0, 1, 0) }):Play()
end

local function startLoop()
	stopLoop()
	attackToken += 1
	local token = attackToken
	local classKey = player:GetAttribute("Class")
	local spec = classKey and ClassCatalog[classKey]
	if not spec then
		return
	end
	local interval = spec.Cooldown + 0.05
	task.spawn(function()
		while token == attackToken do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				break
			end
			if equippedClassTool() == nil then
				break
			end
			sendAttack(spec)
			task.wait(interval)
		end
	end)
end

local function hookTool(tool)
	if not tool:IsA("Tool") then
		return
	end
	if not tool:GetAttribute("ClassTool") then
		return
	end
	if tool:GetAttribute("CombatHooked") then
		return
	end
	tool:SetAttribute("CombatHooked", true)
	tool.Activated:Connect(startLoop)
	tool.Deactivated:Connect(stopLoop)
	tool.Unequipped:Connect(function()
		stopLoop()
		refreshBar()
	end)
	tool.Equipped:Connect(refreshBar)
	tool.Destroying:Connect(stopLoop)
end

local function hookContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

hookContainer(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function(character)
	hookContainer(character)
	refreshBar()
end)
player.CharacterRemoving:Connect(stopLoop)
if player.Character then
	hookContainer(player.Character)
end
refreshBar()
