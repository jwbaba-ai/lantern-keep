-- 웨이브 시작 큰 글자 (단일 기준: docs/tasks/day14.md 3단계).
-- ReplicatedStorage.DirectorState(JSON)를 읽어 phase가 다른 값에서 wave로 바뀔 때 보여 준다.
-- AI가 만든 웨이브 이름·한마디는 쓰지 않는다. 숫자만 쓰므로 필터·고지가 필요 없다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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

local function showLines(bigText, bigColor, smallText)
	showToken += 1
	local token = showToken
	setVisibleLines(bigText, bigColor, smallText)
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

local function show(data)
	if data.boss == true then
		showLines("보스 웨이브", Color3.fromRGB(255, 70, 60), string.format("Day %d", data.day or 1))
	else
		showLines(
			string.format("웨이브 %d / %d", data.display_wave or 0, data.total_waves or 0),
			Color3.new(1, 1, 1),
			string.format("Day %d", data.day or 1)
		)
	end
end

-- 웨이브 클리어: 같은 자리·같은 타이밍의 금색 글자.
-- result(경기 끝)로는 바뀌지 않는다. 결과 화면이 따로 있다.
local function showClear()
	showLines("웨이브 클리어!", Color3.fromRGB(255, 200, 60), "")
end

-- 투표 결과 창이 떠 있으면 큰 글자를 잠시 미룬다 (NpcBubble의 대사와 같은 방식).
-- SupportState(JSON)의 announce가 비어 있지 않고 announce_until이 아직이면
-- 남은 시간 + 0.2초 뒤에 보여 준다. 읽기 실패·값 없음·숫자 아님은 바로 보여 준다.
-- 미루는 사이에 phase가 wave가 아니게 되면 보여 주지 않는다 (결과 화면에 뜨면 안 된다).
local state = ReplicatedStorage:WaitForChild("DirectorState")

local function deferShow()
	local delay = 0
	pcall(function()
		local support = ReplicatedStorage:FindFirstChild("SupportState")
		if support == nil or type(support.Value) ~= "string" or support.Value == "" then
			return
		end
		local data = HttpService:JSONDecode(support.Value)
		if type(data) ~= "table" then
			return
		end
		if type(data.announce) ~= "string" or data.announce == "" then
			return
		end
		if type(data.announce_until) ~= "number" then
			return
		end
		local remain = data.announce_until - Workspace:GetServerTimeNow()
		if remain > 0 then
			delay = remain + 0.2
		end
	end)
	if delay > 0 then
		task.delay(delay, function()
			local ok, current = pcall(HttpService.JSONDecode, HttpService, state.Value)
			if ok and type(current) == "table" and current.phase == "wave" then
				show(current)
			end
		end)
	else
		local ok, current = pcall(HttpService.JSONDecode, HttpService, state.Value)
		if ok and type(current) == "table" and current.phase == "wave" then
			show(current)
		end
	end
end

local lastPhase = nil
local function onChanged()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, state.Value)
	if not ok or type(data) ~= "table" then
		return
	end
	local phase = data.phase
	local wasWave = lastPhase == "wave"
	lastPhase = phase
	if phase == "wave" and not wasWave then
		deferShow()
	elseif wasWave and phase == "intermission" then
		showClear()
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
