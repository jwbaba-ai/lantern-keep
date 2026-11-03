-- 대기 건너뛰기 버튼 (단일 기준: docs/tasks/day14g.md 3단계).
-- SkipOpen이 true일 때(웨이브 사이 대기·결과 화면)만 보인다.
-- 기본 UI만 쓴다. AI 문구가 없어 고지는 붙이지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiScale = require(script.Parent:WaitForChild("UiScale"))

-- 화면 아래쪽, 휴대폰 점프 버튼 왼쪽(점프 버튼을 가리지 않게).
-- 842×390 측정에서 대화창(y 110~212) 안에 들어가 뒤에 가려지던 자리에서 내렸다.
local BUTTON_W = 140
local BUTTON_H = 44
local OFFSET_X = -115
local OFFSET_Y = -12

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local skipEvent = remotes:WaitForChild("SkipWait")

local gui = Instance.new("ScreenGui")
gui.Name = "SkipWait"
gui.ResetOnSpawn = false
-- NPC 대화창(기본 순서 0)보다 위에, 직업 선택 창(10)보다는 낮게 그린다.
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "SkipButton"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, OFFSET_X, 1, OFFSET_Y)
button.Size = UDim2.new(0, BUTTON_W, 0, BUTTON_H)
button.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
button.BackgroundTransparency = 0.25
button.BorderSizePixel = 0
button.Font = Enum.Font.GothamBold
button.TextScaled = true
button.TextColor3 = Color3.new(1, 1, 1)
button.Text = ""
button.Visible = false
button.Parent = gui

local buttonScale = Instance.new("UIScale")
buttonScale.Parent = button
UiScale.watch(function(s)
	buttonScale.Scale = s
end)

-- 내 표 여부는 클라이언트가 누른 상태로 기억한다.
local myVote = false

local function skipOpen()
	return ReplicatedStorage:GetAttribute("SkipOpen") == true
end

local function render()
	if not skipOpen() then
		myVote = false
		button.Visible = false
		return
	end
	local votes = ReplicatedStorage:GetAttribute("SkipVotes")
	local needed = ReplicatedStorage:GetAttribute("SkipNeeded")
	if type(votes) ~= "number" then
		votes = 0
	end
	if type(needed) ~= "number" then
		needed = 0
	end
	if myVote then
		button.Text = string.format("취소 %d/%d", votes, needed)
		button.BackgroundColor3 = Color3.fromRGB(60, 140, 70)
	else
		button.Text = string.format("건너뛰기 %d/%d", votes, needed)
		button.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	end
	button.Visible = true
end

button.MouseButton1Click:Connect(function()
	if not skipOpen() then
		return
	end
	myVote = not myVote
	skipEvent:FireServer()
	render()
end)

ReplicatedStorage:GetAttributeChangedSignal("SkipOpen"):Connect(render)
ReplicatedStorage:GetAttributeChangedSignal("SkipVotes"):Connect(render)
ReplicatedStorage:GetAttributeChangedSignal("SkipNeeded"):Connect(render)
render()
