-- 등불 체력 막대 (단일 기준: docs/tasks/day4.md 5단계).
-- 화면 위 오른쪽에 Map.Lantern의 Health 어트리뷰트를 보여 준다.
-- 30% 이하면 붉게 깜빡인다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UiScale = require(script.Parent:WaitForChild("UiScale"))

local MAX_HEALTH = Config.LanternMaxHealth
local LOW_PCT = 0.3

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LanternBar"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -12, 0, 12)
frame.Size = UDim2.new(0, 220, 0, 44)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.25
frame.Parent = gui

-- 휴대폰 배율: 화면이 바뀌면(회전) 다시 맞춘다.
local frameScale = Instance.new("UIScale")
frameScale.Parent = frame
local layoutBar = nil
UiScale.watch(function(s)
	frameScale.Scale = s
	if layoutBar then
		layoutBar()
	end
end)

-- 큰 배너와 가로로 겹치면, 화면이 좁을 때만 체력바를 배너 아래로 내린다.
-- 위치는 오른쪽 정렬, y = 배너 아래 끝 + 8이다.
-- 배너가 접힌 한 줄일 때와 결과 화면일 때는 원래 자리(오른쪽 위)로 되돌린다.
-- 겹침 판정은 체력바의 원래 자리 사각형으로 해서, 내린 뒤에도 떨지 않게 한다.
-- 화면 크기가 바뀌면(가로·세로 전환) 다시 계산한다.
function layoutBar()
	local s = UiScale.factor()
	local camera = Workspace.CurrentCamera
	local vw = 1024
	if camera then
		vw = camera.ViewportSize.X
	end
	local barW = frame.Size.X.Offset * s
	local barH = frame.Size.Y.Offset * s
	local defaultX = vw - 12 - barW
	local playerGui = gui.Parent
	local bannerGui = playerGui and playerGui:FindFirstChild("WaveBanner")
	local banner = bannerGui and bannerGui:FindFirstChild("Banner")
	if banner and banner.Visible then
		local bp, bs = banner.AbsolutePosition, banner.AbsoluteSize
		local overlapX = defaultX < bp.X + bs.X and bp.X < defaultX + barW
		local overlapY = 12 < bp.Y + bs.Y and bp.Y < 12 + barH
		if overlapX and overlapY then
			frame.Position = UDim2.new(1, -12, 0, math.floor(bp.Y + bs.Y + 8 + 0.5))
			return
		end
	end
	frame.Position = UDim2.new(1, -12, 0, 12)
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 18)
title.BackgroundTransparency = 1
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "등불"
title.Parent = frame

local back = Instance.new("Frame")
back.Position = UDim2.new(0, 8, 0, 20)
back.Size = UDim2.new(1, -16, 0, 16)
back.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
back.BorderSizePixel = 0
back.Parent = frame

local fill = Instance.new("Frame")
fill.Size = UDim2.new(1, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
fill.BorderSizePixel = 0
fill.Parent = back

local map = Workspace:WaitForChild("Map")
local lantern = map:WaitForChild("Lantern")

local lowHealth = false

local function render()
	local hp = lantern:GetAttribute("Health") or MAX_HEALTH
	local pct = math.clamp(hp / MAX_HEALTH, 0, 1)
	fill.Size = UDim2.new(pct, 0, 1, 0)
	lowHealth = pct <= LOW_PCT
	if not lowHealth then
		fill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
		fill.Visible = true
	end
end

lantern:GetAttributeChangedSignal("Health"):Connect(render)
render()
layoutBar()

-- 30% 이하에서 붉게 깜빡인다.
task.spawn(function()
	while true do
		task.wait(0.5)
		if lowHealth then
			fill.Visible = not fill.Visible
			fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		end
		-- 배너가 뜨거나 접히면 따라간다.
		layoutBar()
	end
end)
