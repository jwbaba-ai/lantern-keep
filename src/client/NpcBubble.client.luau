-- NPC 말풍선 (단일 기준: docs/tasks/day5.md 5단계).
-- 서버의 Remotes.NpcSay를 받아 NPC 머리 위 BillboardGui로 9초간 보여 준다.
-- AI 대사일 때만 작은 글씨로 "AI가 생성한 대사입니다"를 붙인다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local npcSay = remotes:WaitForChild("NpcSay")

-- AssetIds가 Studio에 아직 없으면 초상화 없이 글자만 보여 준다.
local assetIdsModule = ReplicatedStorage:WaitForChild("Shared"):FindFirstChild("AssetIds")
local AssetIds = assetIdsModule and require(assetIdsModule) or nil

local PORTRAIT_KEY = { bram = "PortraitBram", mira = "PortraitMira" }

local function portraitOf(npcKey)
	if AssetIds then
		return AssetIds.imageOrNil(PORTRAIT_KEY[npcKey])
	end
	return nil
end

local UiScale = require(script.Parent:WaitForChild("UiScale"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "NpcBubble"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local PART_NAMES = { bram = "Bram", mira = "Mira" }
local open = {} -- [npcKey] = { bubble, token }

local function makeLabel(text, size, color, order)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, size)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = text
	label.LayoutOrder = order
	return label
end

local function showBubble(npcKey, text, isAI)
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Npcs")
	local body = folder and folder:FindFirstChild(PART_NAMES[npcKey])
	if body == nil then
		return
	end
	-- 같은 NPC의 이전 말풍선을 걷는다.
	local prev = open[npcKey]
	if prev then
		prev.bubble:Destroy()
	end
	local token = (prev and prev.token or 0) + 1
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "NpcSpeech"
	bubble.Adornee = body
	bubble.Size = UDim2.new(0, 260, 0, isAI and 100 or 70)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	bubble.AlwaysOnTop = true
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.2
	frame.Parent = bubble
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Parent = frame
	-- 말풍선 왼쪽에 초상화를 둔다. ID가 0이면 글자만 나온다.
	local portraitArt = portraitOf(npcKey)
	local portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.Size = UDim2.new(0, 56, 0, 56)
	portrait.BackgroundTransparency = 1
	portrait.Image = portraitArt or ""
	portrait.Visible = portraitArt ~= nil
	portrait.LayoutOrder = 1
	portrait.Parent = frame
	local textCol = Instance.new("Frame")
	textCol.Name = "TextCol"
	textCol.BackgroundTransparency = 1
	if portraitArt then
		textCol.Size = UDim2.new(1, -78, 1, -8)
	else
		textCol.Size = UDim2.new(1, -16, 1, -8)
	end
	textCol.LayoutOrder = 2
	textCol.Parent = frame
	local colLayout = Instance.new("UIListLayout")
	colLayout.Padding = UDim.new(0, 2)
	colLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	colLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	colLayout.Parent = textCol
	makeLabel(text, 44, Color3.new(1, 1, 1), 1).Parent = textCol
	if isAI then
		makeLabel("AI가 생성한 대사입니다", 20, Color3.fromRGB(200, 200, 200), 2).Parent = textCol
	end
	-- 휴대폰 배율: 말풍선은 새로 뜰 때마다 지금 화면 배율을 쓴다.
	local bubbleScale = Instance.new("UIScale")
	bubbleScale.Scale = UiScale.factor()
	bubbleScale.Parent = bubble
	bubble.Parent = gui
	open[npcKey] = { bubble = bubble, token = token }
	task.delay(9, function()
		local cur = open[npcKey]
		if cur and cur.token == token then
			bubble:Destroy()
			open[npcKey] = nil
		end
	end)
end

npcSay.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.npc ~= "bram" and payload.npc ~= "mira" then
		return
	end
	if type(payload.text) ~= "string" or payload.text == "" then
		return
	end
	showBubble(payload.npc, payload.text, payload.isAI == true)
end)
