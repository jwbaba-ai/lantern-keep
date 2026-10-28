-- 결과 화면 (단일 기준: docs/tasks/day6.md 2단계).
-- DirectorState phase="result"일 때만 화면 가운데에 크게 보여 준다.
-- 서버가 보낸 고정 문구(display_name·display_note)만 쓰고, AI 문구는 없다.
-- phase="lobby"가 되면 사라진다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ResultScreen"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.new(0.5, 0, 0.4, 0)
frame.Size = UDim2.new(0, 480, 0, 220)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.15
frame.Visible = false
frame.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = frame

local function makeLabel(name, order, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, -24, 0, size)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = ""
	label.LayoutOrder = order
	label.Parent = frame
	return label
end

local titleLine = makeLabel("Title", 1, 48, Color3.new(1, 1, 1))
local subLine = makeLabel("Sub", 2, 26, Color3.fromRGB(255, 230, 150))
local memoryLine = makeLabel("Memory", 3, 22, Color3.fromRGB(180, 255, 180))
local countdownLine = makeLabel("Countdown", 4, 22, Color3.fromRGB(160, 160, 160))

memoryLine.Text = "Bram과 Mira가 이번 판을 기억합니다"

local lastData = nil

local function render()
	local data = lastData
	if not data then
		return
	end
	titleLine.Text = data.display_name or ""
	subLine.Text = data.display_note or ""
end

local function refreshCountdown()
	if not lastData or lastData.phase ~= "result" then
		countdownLine.Text = ""
		return
	end
	local endsAt = lastData.intermission_ends_at or 0
	if endsAt <= 0 then
		countdownLine.Text = "다음 판 준비 중…"
		return
	end
	local left = math.ceil(endsAt - Workspace:GetServerTimeNow())
	if left > 0 then
		countdownLine.Text = string.format("다음 판까지 %d초", left)
	else
		countdownLine.Text = "곧 시작…"
	end
end

local state = ReplicatedStorage:WaitForChild("DirectorState")
local function onChanged()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, state.Value)
	if not ok or type(data) ~= "table" then
		return
	end
	lastData = data
	if data.phase == "result" then
		frame.Visible = true
		render()
		refreshCountdown()
	else
		frame.Visible = false
	end
end
state.Changed:Connect(onChanged)
if state.Value ~= "" then
	onChanged()
end

task.spawn(function()
	while true do
		task.wait(0.5)
		refreshCountdown()
	end
end)
