-- 직업 선택 서비스 (단일 기준: docs/tasks/day3.md 2단계).
-- 접속 시 클라이언트가 고른 직업을 ChooseClass로 받아 플레이어 어트리뷰트
-- `Class`에 저장하고, 최대 체력을 적용한 뒤 해당 Tool을 지급한다.
-- 10초 안에 고르지 않으면 guardian으로 자동 지정한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassCatalog = require(Shared:WaitForChild("ClassCatalog"))

local AUTO_PICK_SECONDS = 10
local TOOL_NAMES = {
	guardian = "Guardian Blade",
	ranger = "Ranger Bow",
	arcanist = "Arcanist Orb",
	cleric = "Cleric Mace",
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local chooseEvent = remotes:FindFirstChild("ChooseClass")
if not chooseEvent then
	chooseEvent = Instance.new("RemoteEvent")
	chooseEvent.Name = "ChooseClass"
	chooseEvent.Parent = remotes
end

local function giveTool(player, classKey)
	for _, child in ipairs(player.Backpack:GetChildren()) do
		if child:GetAttribute("ClassTool") then
			child:Destroy()
		end
	end
	if player.Character then
		for _, child in ipairs(player.Character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("ClassTool") then
				child:Destroy()
			end
		end
	end
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAMES[classKey] or classKey
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = ClassCatalog[classKey].Description
	tool:SetAttribute("ClassTool", true)
	tool.Parent = player.Backpack
	return tool
end

-- 직업 Tool을 바로 들게 한다. Humanoid가 없으면 가방에만 둔다.
local function equipTool(player, tool)
	if tool == nil or tool.Parent == nil then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	pcall(function()
		humanoid:EquipTool(tool)
	end)
end

local function applyHealth(player, classKey)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = ClassCatalog[classKey].MaxHealth
		humanoid.Health = ClassCatalog[classKey].MaxHealth
	end
end

local function assignClass(player, classKey)
	if not ClassCatalog[classKey] then
		return
	end
	player:SetAttribute("Class", classKey)
	applyHealth(player, classKey)
	equipTool(player, giveTool(player, classKey))
end

chooseEvent.OnServerEvent:Connect(function(player, classKey)
	if typeof(classKey) ~= "string" then
		return
	end
	if not ClassCatalog[classKey] then
		return
	end
	-- 한 경기에 한 번만 고른다. 이미 골랐으면 무시 (재선택 체력 회복 방지).
	if player:GetAttribute("Class") ~= nil then
		return
	end
	assignClass(player, classKey)
end)

local function hookPlayer(player)
	player.CharacterAdded:Connect(function()
		local classKey = player:GetAttribute("Class")
		if classKey and ClassCatalog[classKey] then
			-- Humanoid가 준비될 때까지 기다렸다가 체력·Tool·장착을 적용한다.
			task.defer(function()
				local character = player.Character
				if character then
					character:WaitForChild("Humanoid", 5)
				end
				if player.Parent == nil then
					return
				end
				applyHealth(player, classKey)
				equipTool(player, giveTool(player, classKey))
			end)
		end
	end)
	task.delay(AUTO_PICK_SECONDS, function()
		if player.Parent == nil then
			return
		end
		if not player:GetAttribute("Class") then
			assignClass(player, "guardian")
		end
	end)
end

-- 스크립트 시작 전에 들어온 플레이어도 놓치지 않는다.
for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end
Players.PlayerAdded:Connect(hookPlayer)
