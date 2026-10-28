-- NPC 말풍선 (단일 기준: docs/tasks/day5.md 5단계).
-- 서버의 Remotes.NpcSay를 받아 NPC 머리 위 BillboardGui로 6초간 보여 준다.
-- AI 대사일 때만 작은 글씨로 "AI가 생성한 대사입니다"를 붙인다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local npcSay = remotes:WaitForChild("NpcSay")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "NpcBubble"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local PART_NAMES = { bram = "Bram", mira = "Mira" }
local open = {} -- [npcKey] = { bubble, token }

local function makeLabel(text, size, color, order)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 0, size)
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
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = frame
	makeLabel(text, 44, Color3.new(1, 1, 1), 1).Parent = frame
	if isAI then
		makeLabel("AI가 생성한 대사입니다", 18, Color3.fromRGB(160, 160, 160), 2).Parent = frame
	end
	bubble.Parent = gui
	open[npcKey] = { bubble = bubble, token = token }
	task.delay(6, function()
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
