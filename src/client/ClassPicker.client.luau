-- 직업 선택 화면 (단일 기준: docs/tasks/day3.md 2단계).
-- 접속 시 화면 가운데 버튼 4개(직업 이름 + 한 줄 설명)를 보여주고,
-- 고른 직업을 ChooseClass로 서버에 보낸다. 서버가 Class 어트리뷰트를
-- 채우면(직접 선택 또는 10초 후 자동 지정) 화면을 닫는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassCatalog = require(Shared:WaitForChild("ClassCatalog"))

local CLASS_ORDER = { "guardian", "ranger", "arcanist", "cleric" }

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local chooseEvent = remotes:WaitForChild("ChooseClass")

local gui = Instance.new("ScreenGui")
gui.Name = "ClassPicker"
gui.ResetOnSpawn = false
-- 직업 창을 맨 위에 둔다 (배너·투표 창과 겹치면 이 창이 보인다).
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.new(0.5, 0, 0.5, 0)
frame.Size = UDim2.new(0, 440, 0, 320)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
-- 기본 SortOrder(Name)면 LayoutOrder가 무시돼 제목이 맨 아래로 가므로 명시한다.
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = frame

-- 짧은 한국어 표기 (ClassCatalog은 고치지 않는다).
local BUTTON_TEXT = {
	guardian = "수호자 · 앞에서 막는 탱커",
	ranger = "궁수 · 멀리서 쏘는 원거리",
	arcanist = "비전술사 · 범위 마법",
	cleric = "사제 · 치유와 부활",
}

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "직업을 고르세요"
title.LayoutOrder = 0
title.Parent = frame

for i, classKey in ipairs(CLASS_ORDER) do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -16, 0, 56)
	button.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Text = BUTTON_TEXT[classKey] or classKey
	button.LayoutOrder = i
	button.Parent = frame
	button.MouseButton1Click:Connect(function()
		chooseEvent:FireServer(classKey)
	end)
end

local function hideIfChosen()
	if player:GetAttribute("Class") ~= nil then
		gui:Destroy()
	end
end
player:GetAttributeChangedSignal("Class"):Connect(hideIfChosen)
hideIfChosen()
