-- 결과 화면 (단일 기준: docs/tasks/day6.md 2단계).
-- DirectorState phase="result"일 때만 화면 가운데에 크게 보여 준다.
-- 서버가 보낸 고정 문구(display_name·display_note)만 쓰고, AI 문구는 없다.
-- phase="lobby"가 되면 사라진다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- AssetIds가 Studio에 아직 없으면 초상화 없이 글자만 보여 준다.
local assetIdsModule = ReplicatedStorage:WaitForChild("Shared"):FindFirstChild("AssetIds")
local AssetIds = assetIdsModule and require(assetIdsModule) or nil

local function artOf(key)
	if AssetIds then
		return AssetIds.imageOrNil(key)
	end
	return nil
end

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ResultScreen"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.new(0.5, 0, 0.4, 0)
frame.Size = UDim2.new(0, 480, 0, 320)
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
local countdownLine = makeLabel("Countdown", 5, 22, Color3.fromRGB(160, 160, 160))

memoryLine.Text = "Bram과 Mira가 이번 판을 기억합니다"

-- Bram과 Mira 초상화를 나란히 보여 준다. ID가 0이면 줄 전체가 접힌다.
local portraitsRow = Instance.new("Frame")
portraitsRow.Name = "Portraits"
portraitsRow.Size = UDim2.new(1, -24, 0, 80)
portraitsRow.BackgroundTransparency = 1
portraitsRow.Visible = false
portraitsRow.LayoutOrder = 4
portraitsRow.Parent = frame

local portraitsLayout = Instance.new("UIListLayout")
portraitsLayout.FillDirection = Enum.FillDirection.Horizontal
portraitsLayout.Padding = UDim.new(0, 12)
portraitsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
portraitsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
portraitsLayout.Parent = portraitsRow

local function makePortrait(name, order)
	local portrait = Instance.new("ImageLabel")
	portrait.Name = name
	portrait.Size = UDim2.new(0, 72, 0, 72)
	portrait.BackgroundTransparency = 1
	portrait.Image = ""
	portrait.Visible = false
	portrait.LayoutOrder = order
	portrait.Parent = portraitsRow
	return portrait
end

local bramPortrait = makePortrait("Bram", 1)
local miraPortrait = makePortrait("Mira", 2)

local lastData = nil

local function render()
	local data = lastData
	if not data then
		return
	end
	titleLine.Text = data.display_name or ""
	subLine.Text = data.display_note or ""
	local bramArt = artOf("PortraitBram")
	local miraArt = artOf("PortraitMira")
	bramPortrait.Image = bramArt or ""
	bramPortrait.Visible = bramArt ~= nil
	miraPortrait.Image = miraArt or ""
	miraPortrait.Visible = miraArt ~= nil
	portraitsRow.Visible = (bramArt or miraArt) ~= nil
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
