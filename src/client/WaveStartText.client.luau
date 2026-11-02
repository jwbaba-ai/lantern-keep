-- 웨이브 시작 큰 글자 (단일 기준: docs/tasks/day14.md 3단계).
-- ReplicatedStorage.DirectorState(JSON)를 읽어 phase가 다른 값에서 wave로 바뀔 때 보여 준다.
-- AI가 만든 웨이브 이름·한마디는 쓰지 않는다. 숫자만 쓰므로 필터·고지가 필요 없다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiScale = require(script.Parent:WaitForChild("UiScale"))

local SHOW_SECONDS = 0.2
local HOLD_SECONDS = 1.5
local HIDE_SECONDS = 0.4

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "WaveStartText"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- 화면 가운데 위쪽(세로 32%). 입력을 막지 않는다.
local frame = Instance.new("Frame")
frame.Name = "Text"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0.32, 0)
frame.Size = UDim2.new(0, 520, 0, 120)
frame.BackgroundTransparency = 1
frame.Active = false
frame.Parent = gui

local frameScale = Instance.new("UIScale")
frameScale.Parent = frame
UiScale.watch(function(s)
	frameScale.Scale = s
end)

local function makeLine(name, y, height, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.new(0, 0, 0, y)
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.TextTransparency = 1
	label.Active = false
	label.Text = ""
	label.Parent = frame
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = size
	cap.Parent = label
	return label
end

local bigLine = makeLine("Big", 0, 72, 56, Color3.new(1, 1, 1))
local smallLine = makeLine("Small", 76, 36, 28, Color3.fromRGB(220, 220, 220))

local showToken = 0

local function setVisibleLines(bigText, bigColor, smallText)
	bigLine.Text = bigText
	bigLine.TextColor3 = bigColor
	smallLine.Text = smallText
end

local function show(data)
	showToken += 1
	local token = showToken
	if data.boss == true then
		setVisibleLines("보스 웨이브", Color3.fromRGB(255, 70, 60), string.format("Day %d", data.day or 1))
	else
		setVisibleLines(
			string.format("웨이브 %d / %d", data.display_wave or 0, data.total_waves or 0),
			Color3.new(1, 1, 1),
			string.format("Day %d", data.day or 1)
		)
	end
	TweenService:Create(bigLine, TweenInfo.new(SHOW_SECONDS), { TextTransparency = 0 }):Play()
	TweenService:Create(smallLine, TweenInfo.new(SHOW_SECONDS), { TextTransparency = 0 }):Play()
	task.delay(SHOW_SECONDS + HOLD_SECONDS, function()
		if token ~= showToken then
			return
		end
		TweenService:Create(bigLine, TweenInfo.new(HIDE_SECONDS), { TextTransparency = 1 }):Play()
		TweenService:Create(smallLine, TweenInfo.new(HIDE_SECONDS), { TextTransparency = 1 }):Play()
	end)
end

local lastPhase = nil
local state = ReplicatedStorage:WaitForChild("DirectorState")
local function onChanged()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, state.Value)
	if not ok or type(data) ~= "table" then
		return
	end
	local phase = data.phase
	local wasWave = lastPhase == "wave"
	lastPhase = phase
	if phase == "wave" and not wasWave then
		show(data)
	end
end
state.Changed:Connect(onChanged)
-- 접속 전에 이미 정해진 상태는 그린다. 웨이브 중 접속이면 큰 글자를 띄우지 않는다.
if state.Value ~= "" then
	local ok, data = pcall(HttpService.JSONDecode, HttpService, state.Value)
	if ok and type(data) == "table" then
		lastPhase = data.phase
	end
end
