-- 웨이브 배너 (단일 기준: docs/tasks/day4.md 2단계).
-- 화면 위 가운데에 ReplicatedStorage.DirectorState(JSON)를 보여 준다.
-- 서버가 필터한 글자(display_name·display_note)만 쓰고, 원문은 받지 않는다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
-- AssetIds가 Studio에 아직 없으면 그림 없이 글자만 보여 준다.
local assetIdsModule = Shared:FindFirstChild("AssetIds")
local AssetIds = assetIdsModule and require(assetIdsModule) or nil

local function artOf(key)
	if AssetIds then
		return AssetIds.imageOrNil(key)
	end
	return nil
end

-- 이벤트 이름 -> AssetIds 키. none이면 배경 그림이 없다.
local EVENT_ART = {
	fog = "BannerFog",
	elite_spawn = "BannerElite",
	reinforcement_delay = "BannerReinforcement",
	blood_moon = "BannerBloodMoon",
}

local TOTAL_WAVES = Config.TotalWaves

local LANE_KO = { north = "북문", south = "남문", east = "동문", west = "서문" }

local TACTIC_KO = {
	focus_weak_lane = "약한 성문 집중",
	split_push = "전 성문 동시 공격",
	flank = "측면 우회",
	siege = "공성",
}

local EVENT_KO = {
	fog = "안개",
	elite_spawn = "정예 출현",
	reinforcement_delay = "증원 지연",
	blood_moon = "핏빛 달",
}

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "WaveBanner"
gui.ResetOnSpawn = false
-- 그림과 글자가 같은 ZIndex여도 그리는 순서가 형제 순서로 정해지게 한다.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- 배너 전체를 묶는 컨테이너: 크기 조정·pop 트윈이 그림과 글자에 같이 걸린다.
local frame = Instance.new("Frame")
frame.Name = "Banner"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 12)
frame.Size = UDim2.new(0, 520, 0, 150)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.25
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Parent = gui

-- 이벤트 배경 그림: 컨테이너 안에서 글자보다 뒤(ZIndex 1)에 깔고,
-- 글자가 읽히도록 어두운 판을 그 위에 둔다.
local artLayer = Instance.new("Frame")
artLayer.Name = "EventArt"
artLayer.Size = UDim2.new(1, 0, 1, 0)
artLayer.BackgroundTransparency = 1
artLayer.Visible = false
artLayer.ZIndex = 1
artLayer.Parent = frame

local artImage = Instance.new("ImageLabel")
artImage.Name = "Art"
artImage.Size = UDim2.new(1, 0, 1, 0)
artImage.BackgroundTransparency = 1
artImage.ScaleType = Enum.ScaleType.Crop
artImage.Image = ""
artImage.Parent = artLayer

local artDim = Instance.new("Frame")
artDim.Name = "Dim"
artDim.Size = UDim2.new(1, 0, 1, 0)
artDim.BackgroundColor3 = Color3.new(0, 0, 0)
artDim.BackgroundTransparency = 0.45
artDim.BorderSizePixel = 0
artDim.Parent = artLayer

-- 글자 프레임: 그림과 형제로 글자보다 앞(ZIndex 2)에 둔다.
-- UIListLayout은 이 안에만 둔다.
local textFrame = Instance.new("Frame")
textFrame.Name = "Text"
textFrame.Size = UDim2.new(1, 0, 1, 0)
textFrame.BackgroundTransparency = 1
textFrame.ZIndex = 2
textFrame.Parent = frame

-- AI 디렉터 표식: muse 웨이브일 때 컨테이너 안 오른쪽 위에 둔다.
local directorBadge = Instance.new("ImageLabel")
directorBadge.Name = "DirectorBadge"
directorBadge.AnchorPoint = Vector2.new(1, 0)
directorBadge.Position = UDim2.new(1, -6, 0, 6)
directorBadge.Size = UDim2.new(0, 40, 0, 40)
directorBadge.BackgroundTransparency = 1
directorBadge.Image = ""
directorBadge.Visible = false
directorBadge.ZIndex = 3
directorBadge.Parent = frame

local scale = Instance.new("UIScale")
scale.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = textFrame

local function makeLabel(name, order, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, -16, 0, size)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = ""
	label.LayoutOrder = order
	label.Parent = textFrame
	return label
end

local titleLine = makeLabel("Title", 1, 30, Color3.new(1, 1, 1))
local badgeLine = makeLabel("Badge", 2, 22, Color3.fromRGB(120, 220, 255))
local noteLine = makeLabel("Note", 3, 24, Color3.new(1, 1, 1))
local laneLine = makeLabel("Lanes", 4, 22, Color3.fromRGB(255, 230, 150))
local countdownLine = makeLabel("Countdown", 5, 20, Color3.fromRGB(180, 255, 180))
local aiNotice = makeLabel("AINotice", 6, 16, Color3.fromRGB(160, 160, 160))

local lastPhase = nil
local lastSource = nil
local lastData = nil

-- 0.3초 커졌다 돌아오는 트윈.
local function pop()
	local big = TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1.08 })
	big:Play()
	big.Completed:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
	end)
end

-- 성문 요약: 적 수가 많은 순, 0인 성문은 숨김. 예: "북문 6 · 동문 4".
local function laneSummary(lanes)
	local rows = {}
	for lane, count in pairs(lanes) do
		if count > 0 and LANE_KO[lane] then
			table.insert(rows, { lane = lane, count = count })
		end
	end
	table.sort(rows, function(a, b)
		return a.count > b.count
	end)
	local parts = {}
	for _, row in ipairs(rows) do
		table.insert(parts, string.format("%s %d", LANE_KO[row.lane], row.count))
	end
	return table.concat(parts, " · ")
end

local function render()
	local data = lastData
	if not data then
		return
	end
	if data.phase == "lobby" then
		titleLine.Text = data.display_name or ""
	else
		titleLine.Text = string.format(
			"웨이브 %d / %d · %s",
			data.display_wave or 0,
			TOTAL_WAVES,
			data.display_name or ""
		)
	end
	if data.source == "muse" then
		badgeLine.Text = "AI 디렉터가 여러분의 플레이를 보고 설계한 웨이브"
		badgeLine.TextColor3 = Color3.fromRGB(120, 220, 255)
		aiNotice.Text = "AI가 생성한 문구입니다"
	elseif data.source == "fallback" then
		badgeLine.Text = "기본 웨이브"
		badgeLine.TextColor3 = Color3.fromRGB(160, 160, 160)
		aiNotice.Text = ""
	else
		badgeLine.Text = ""
		aiNotice.Text = ""
	end
	-- 이벤트가 none이 아니면 둘째 줄 앞에 한글 이름을 붙인다.
	local note = data.display_note or ""
	local eventKo = data.plan and EVENT_KO[data.plan.event]
	if eventKo then
		note = string.format("[%s] %s", eventKo, note)
	end
	noteLine.Text = note
	-- 셋째 줄: 공격 성문 요약 + 전술 한글 이름.
	local lanes = laneSummary(data.lanes or {})
	local tacticKo = data.plan and TACTIC_KO[data.plan.tactic]
	if lanes ~= "" and tacticKo then
		laneLine.Text = string.format("%s · %s", lanes, tacticKo)
	elseif lanes ~= "" then
		laneLine.Text = lanes
	elseif tacticKo then
		laneLine.Text = tacticKo
	else
		laneLine.Text = ""
	end
	-- 이벤트 그림: 있는 웨이브에만 배경으로 깐다. ID가 0이면 글자만 나온다.
	local eventKey = data.plan and EVENT_ART[data.plan.event]
	local art = eventKey and artOf(eventKey) or nil
	if art then
		artImage.Image = art
		artLayer.Visible = true
	else
		-- 그림이 없으면 자리를 남기지 않는다 (이전 웨이브 그림도 비운다).
		artImage.Image = ""
		artLayer.Visible = false
	end
	-- 디렉터 표식: muse 웨이브에만 컨테이너 안 오른쪽 위에 둔다.
	local directorArt = artOf("BannerDirector")
	if data.source == "muse" and directorArt then
		directorBadge.Image = directorArt
		directorBadge.Visible = true
	else
		directorBadge.Visible = false
	end
end

local function refreshCountdown()
	if not lastData or (lastData.phase ~= "intermission" and lastData.phase ~= "lobby") then
		countdownLine.Text = ""
		return
	end
	local endsAt = lastData.intermission_ends_at or 0
	if endsAt <= 0 then
		countdownLine.Text = ""
		return
	end
	local left = math.ceil(endsAt - Workspace:GetServerTimeNow())
	if left > 0 then
		if lastData.phase == "lobby" then
			countdownLine.Text = string.format("시작까지 %d초", left)
		else
			countdownLine.Text = string.format("다음 웨이브까지 %d초", left)
		end
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
	-- 대기 시작과 디렉터 응답 도착 때 트윈 효과를 넣는다.
	if data.phase ~= lastPhase or (lastSource == "pending" and data.source ~= "pending") then
		pop()
	end
	lastPhase = data.phase
	lastSource = data.source
	lastData = data
	render()
	-- 결과 화면이 맡는 동안은 배너 전체를 숨긴다.
	-- 그림·글자·표식이 모두 컨테이너 안에 있어 하나만 끄면 된다.
	frame.Visible = data.phase ~= "result"
	refreshCountdown()
end
state.Changed:Connect(onChanged)
-- 웨이브 1 상태는 클라이언트 접속 전에 이미 설정되어 있을 수 있다.
-- Value가 비어 있지 않으면 시작 시 한 번 그린다.
if state.Value ~= "" then
	onChanged()
end

-- 카운트다운 갱신.
task.spawn(function()
	while true do
		task.wait(0.5)
		refreshCountdown()
	end
end)
