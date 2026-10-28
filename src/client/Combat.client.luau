-- 전투 입력 전달 (단일 기준: docs/tasks/day3.md 3단계).
-- 직업 Tool의 Activated를 Attack RemoteEvent로 중계한다.
-- 조준 위치만 보내고 데미지 계산은 서버(CombatService)가 한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackEvent = remotes:WaitForChild("Attack")

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
	tool.Activated:Connect(function()
		attackEvent:FireServer(mouse.Hit.Position)
	end)
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
end)
if player.Character then
	hookContainer(player.Character)
end
