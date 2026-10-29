-- 지원대 투표 패널 (단일 기준: docs/tasks/day8b-support.md 3단계).
-- 로비 동안 배너 아래에 보인다. 버튼 3개(각개전투파·협력파·지원대 없이)와
-- 실시간 투표 현황(누가 무엇을 골랐는지, 표 수)을 보여 준다.
-- 서버 코드에 적힌 고정 문구만 쓰므로 AI 고지는 붙이지 않는다.
-- 로비가 끝나면 집계 알림(SupportState.announce)을 6초 동안 보여 준다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UiScale = require(script.Parent:WaitForChild("UiScale"))

local CHOICE_LABEL = { solo = "각개전투파", coop = "협력파", none = "없음" }
local BUTTONS = {
	{ choice = "solo", text = "각개전투파" },
	{ choice = "coop", text = "협력파" },
	{ choice = "none", text = "지원대 없이" },
}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local voteEvent = remotes:WaitForChild("SupportVote")

local gui = Instance.new("ScreenGui")
gui.Name = "SupportVote"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Size = UDim2.new(0, 420, 0, 210)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.25
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = gui

local frameScale = Instance.new("UIScale")
frameScale.Parent = frame

-- 배너(위 12 + 높이 150*배율) 아래에 붙는다.
local function applyScale(s)
	frameScale.Scale = s
	frame.Position = UDim2.new(0.5, 0, 0, math.floor(12 + 150 * s + 8 + 0.5))
end
UiScale.watch(applyScale)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Parent = frame

local function makeLabel(name, order, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, -16, 0, size)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = ""
	label.LayoutOrder = order
	label.Parent = frame
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = size
	cap.Parent = label
	return label
end

local titleLine = makeLabel("Title", 1, 20, Color3.new(1, 1, 1))
local votesLine = makeLabel("Votes", 3, 14, Color3.fromRGB(255, 230, 150))
votesLine.Size = UDim2.new(1, -16, 0, 60)
votesLine.TextWrapped = true
votesLine.TextYAlignment = Enum.TextYAlignment.Top
local countsLine = makeLabel("Counts", 4, 16, Color3.fromRGB(180, 255, 180))
local announceLine = makeLabel("Announce", 5, 16, Color3.fromRGB(160, 220, 255))
titleLine.Text = "지원대 투표"

local buttonRow = Instance.new("Frame")
buttonRow.Name = "Buttons"
buttonRow.Size = UDim2.new(1, -16, 0, 34)
buttonRow.BackgroundTransparency = 1
buttonRow.LayoutOrder = 2
buttonRow.Parent = frame

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.Padding = UDim.new(0, 8)
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonLayout.Parent = buttonRow

for _, def in ipairs(BUTTONS) do
	local button = Instance.new("TextButton")
	button.Name = def.choice
	button.Size = UDim2.new(0, 120, 0, 32)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Text = def.text
	button.Parent = buttonRow
	button.MouseButton1Click:Connect(function()
		voteEvent:FireServer(def.choice)
	end)
end

local lastDirector = nil
local lastSupport = nil

local function render()
	local director = lastDirector
	local support = lastSupport
	if not director or not support then
		frame.Visible = false
		return
	end
	if director.phase == "lobby" then
		buttonRow.Visible = true
		titleLine.Text = "지원대 투표"
		local rows = {}
		for _, entry in ipairs(support.votes or {}) do
			table.insert(rows, string.format("%s · %s", entry.name, CHOICE_LABEL[entry.choice] or entry.choice))
		end
		votesLine.Text = table.concat(rows, "\n")
		local counts = support.counts or {}
		countsLine.Text = string.format(
			"협력파 %d · 각개전투파 %d · 없음 %d",
			counts.coop or 0,
			counts.solo or 0,
			counts.none or 0
		)
		announceLine.Text = ""
		frame.Visible = true
		return
	end
	-- 로비 뒤: 집계 알림이 6초 동안만 보인다.
	buttonRow.Visible = false
	local announce = support.announce or ""
	local untilAt = support.announce_until or 0
	if announce ~= "" and untilAt > 0 and Workspace:GetServerTimeNow() < untilAt then
		titleLine.Text = "지원대 투표 결과"
		votesLine.Text = ""
		countsLine.Text = ""
		announceLine.Text = announce
		frame.Visible = true
	else
		frame.Visible = false
	end
end

local directorState = ReplicatedStorage:WaitForChild("DirectorState")
local supportState = ReplicatedStorage:WaitForChild("SupportState")

local function onDirector()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, directorState.Value)
	if not ok or type(data) ~= "table" then
		return
	end
	lastDirector = data
	render()
end

local function onSupport()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, supportState.Value)
	if not ok or type(data) ~= "table" then
		return
	end
	lastSupport = data
	render()
end

directorState.Changed:Connect(onDirector)
supportState.Changed:Connect(onSupport)
if directorState.Value ~= "" then
	onDirector()
end
if supportState.Value ~= "" then
	onSupport()
end

-- 집계 알림 6초가 지나면 패널을 숨긴다.
task.spawn(function()
	while true do
		task.wait(0.5)
		render()
	end
end)
