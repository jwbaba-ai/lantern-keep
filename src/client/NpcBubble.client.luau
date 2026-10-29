-- NPC 말풍선 (단일 기준: docs/tasks/day5.md 5단계, day10 4번).
-- AI 대사는 화면 아래 고정 대화창에 두 줄로 쌓아 보여 주고(9초),
-- NPC 머리 위에는 "…"만 남긴다. 기본 대사(비AI)는 예전처럼 머리 위 말풍선이다.
-- AI 대사일 때만 작은 글씨로 "AI가 생성한 대사입니다"를 붙인다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
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

-- 기본 대사(비AI)용 머리 위 말풍선. AI 대사는 아래 고정 대화창으로 간다.
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

-- 화면 고정 대화창(AI 대사 전용). 화면 아래 가운데, 툴바(무기 버튼) 위다.
-- 너비는 min(520, 화면 너비 - 24). 두 NPC가 동시에 말하면 세로로 쌓는다
-- (Bram 위, Mira 아래). 서로 겹치지 않고 화면 안에 있다.
local DIALOG_BASE_W = 520
local DIALOG_BOTTOM_GAP = 120
local BODY_TEXT_SIZE = 18

local dialog = Instance.new("Frame")
dialog.Name = "NpcDialog"
dialog.AnchorPoint = Vector2.new(0.5, 1)
dialog.Position = UDim2.new(0.5, 0, 1, -DIALOG_BOTTOM_GAP)
dialog.Size = UDim2.new(0, DIALOG_BASE_W, 0, 0)
dialog.AutomaticSize = Enum.AutomaticSize.Y
dialog.BackgroundTransparency = 1
dialog.Visible = false
dialog.Parent = gui

local dialogLayout = Instance.new("UIListLayout")
dialogLayout.FillDirection = Enum.FillDirection.Vertical
dialogLayout.Padding = UDim.new(0, 6)
dialogLayout.SortOrder = Enum.SortOrder.LayoutOrder
dialogLayout.Parent = dialog

local function dialogWidth()
	local camera = Workspace.CurrentCamera
	local vw = 1024
	if camera then
		vw = camera.ViewportSize.X
	end
	return math.min(DIALOG_BASE_W, vw - 24)
end

local function applyDialogSize()
	dialog.Size = UDim2.new(0, dialogWidth(), 0, 0)
end
applyDialogSize()
UiScale.watch(function()
	applyDialogSize()
end)

local NPC_TITLE = { bram = "Bram · 노장 대장", mira = "Mira · 견습 치유사" }
local rows = {}

-- 본문 한 줄 높이를 재서 최대 높이(3줄)를 정한다.
local lineHeight =
	TextService:GetTextSize("가", BODY_TEXT_SIZE, Enum.Font.Gotham, Vector2.new(10000, 10000)).Y
local bodyMaxH = math.ceil(lineHeight * 3)

local function makeRow(npcKey, order)
	local row = Instance.new("Frame")
	row.Name = npcKey
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Visible = false
	row.Parent = dialog

	local hLayout = Instance.new("UIListLayout")
	hLayout.FillDirection = Enum.FillDirection.Horizontal
	hLayout.Padding = UDim.new(0, 8)
	hLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	hLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hLayout.Parent = row

	local portraitArt = portraitOf(npcKey)
	local portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.Size = UDim2.new(0, 48, 0, 48)
	portrait.BackgroundTransparency = 1
	portrait.Image = portraitArt or ""
	portrait.Visible = portraitArt ~= nil
	portrait.LayoutOrder = 1
	portrait.Parent = row

	local col = Instance.new("Frame")
	col.Name = "TextCol"
	col.BackgroundTransparency = 1
	if portraitArt then
		col.Size = UDim2.new(1, -64, 0, 0)
	else
		col.Size = UDim2.new(1, -16, 0, 0)
	end
	col.AutomaticSize = Enum.AutomaticSize.Y
	col.LayoutOrder = 2
	col.Parent = row

	local colLayout = Instance.new("UIListLayout")
	colLayout.FillDirection = Enum.FillDirection.Vertical
	colLayout.Padding = UDim.new(0, 2)
	colLayout.SortOrder = Enum.SortOrder.LayoutOrder
	colLayout.Parent = col

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(255, 230, 150)
	nameLabel.Text = NPC_TITLE[npcKey]
	nameLabel.LayoutOrder = 1
	nameLabel.Parent = col

	local body = Instance.new("TextLabel")
	body.Name = "Line"
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = BODY_TEXT_SIZE
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.VerticalAlignment.Top
	body.ClipsDescendants = true
	body.Text = ""
	body.LayoutOrder = 2
	body.Parent = col
	local bodyCap = Instance.new("UISizeConstraint")
	bodyCap.MaxSize = Vector2.new(100000, bodyMaxH)
	bodyCap.Parent = body

	local ai = Instance.new("TextLabel")
	ai.Name = "AINotice"
	ai.Size = UDim2.new(1, 0, 0, 16)
	ai.BackgroundTransparency = 1
	ai.Font = Enum.Font.Gotham
	ai.TextSize = 14
	ai.TextXAlignment = Enum.TextXAlignment.Left
	ai.TextColor3 = Color3.fromRGB(200, 200, 200)
	ai.Text = "AI가 생성한 대사입니다"
	ai.LayoutOrder = 3
	ai.Parent = col

	rows[npcKey] = { frame = row, body = body, ai = ai, token = 0 }
end

makeRow("bram", 1)
makeRow("mira", 2)

local function refreshDialogVisible()
	dialog.Visible = rows.bram.frame.Visible or rows.mira.frame.Visible
end

local function showDialog(npcKey, text, isAI)
	local slot = rows[npcKey]
	if slot == nil then
		return
	end
	slot.body.Text = text
	slot.ai.Visible = isAI == true
	slot.frame.Visible = true
	refreshDialogVisible()
	slot.token += 1
	local token = slot.token
	task.delay(9, function()
		if slot.token == token then
			slot.frame.Visible = false
			refreshDialogVisible()
		end
	end)
end

-- 머리 위 "…" 표시. AI 대사가 나갈 때 누가 말하는지 9초 동안 보인다.
local dots = {}
local function showDot(npcKey)
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Npcs")
	local body = folder and folder:FindFirstChild(PART_NAMES[npcKey])
	if body == nil then
		return
	end
	local prev = dots[npcKey]
	if prev then
		prev.bubble:Destroy()
	end
	local token = (prev and prev.token or 0) + 1
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "NpcSpeaking"
	bubble.Adornee = body
	bubble.Size = UDim2.new(0, 120, 0, 40)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	bubble.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "…"
	label.Parent = bubble
	local dotScale = Instance.new("UIScale")
	dotScale.Scale = UiScale.factor()
	dotScale.Parent = bubble
	bubble.Parent = gui
	dots[npcKey] = { bubble = bubble, token = token }
	task.delay(9, function()
		local cur = dots[npcKey]
		if cur and cur.token == token then
			bubble:Destroy()
			dots[npcKey] = nil
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
	if payload.isAI == true then
		showDialog(payload.npc, payload.text, true)
		showDot(payload.npc)
	else
		showBubble(payload.npc, payload.text, false)
	end
end)
