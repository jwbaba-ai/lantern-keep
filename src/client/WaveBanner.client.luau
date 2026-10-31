-- 웨이브 배너 (단일 기준: docs/tasks/day4.md 2단계).
-- 화면 위 가운데에 ReplicatedStorage.DirectorState(JSON)를 보여 준다.
-- 서버가 필터한 글자(display_name·display_note)만 쓰고, 원문은 받지 않는다.
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
-- AssetIds가 Studio에 아직 없으면 그림 없이 글자만 보여 준다.
local assetIdsModule = Shared:FindFirstChild("AssetIds")
local AssetIds = assetIdsModule and require(assetIdsModule) or nil

local UiScale = require(script.Parent:WaitForChild("UiScale"))

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

local LANE_KO = { north = "북문", south = "남문", east = "동문", west = "서문" }

local TACTIC_KO = {
	focus_weak_lane = "약한 성문 집중",
	split_push = "전 성문 시간차 공격",
	flank = "측면 우회",
	siege = "공성",
}

-- Config.Lanes 순서 (동점 정렬용).
local LANE_ORDER = { north = 1, south = 2, east = 3, west = 4 }

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
-- 고정 크기 + 중앙 앵커: 안쪽 UIScale이 한 번만 걸려 컨테이너와 같은 크기가 된다.
textFrame.AnchorPoint = Vector2.new(0.5, 0.5)
textFrame.Position = UDim2.fromScale(0.5, 0.5)
textFrame.Size = UDim2.fromOffset(520, 150)
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

-- 접힌 한 줄 (웨이브 중 6초 뒤): 왼쪽 위 Roblox 메뉴 버튼 아래에 둔다.
-- 등불 체력바(LanternBar)는 오른쪽 위에 있어서 겹치지 않는다.
-- 이벤트 그림과 디렉터 표식은 큰 배너 안에만 있어 접히면 함께 숨는다.
local miniFrame = Instance.new("Frame")
miniFrame.Name = "Mini"
miniFrame.AnchorPoint = Vector2.new(0, 0)
miniFrame.Size = UDim2.new(0, 360, 0, 28)
miniFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
miniFrame.BackgroundTransparency = 0.3
miniFrame.BorderSizePixel = 0
miniFrame.Visible = false
miniFrame.Parent = gui

local miniScale = Instance.new("UIScale")
miniScale.Parent = miniFrame

local miniLabel = Instance.new("TextLabel")
miniLabel.Name = "MiniLine"
miniLabel.Size = UDim2.new(1, -12, 1, 0)
miniLabel.Position = UDim2.new(0, 6, 0, 0)
miniLabel.BackgroundTransparency = 1
miniLabel.TextScaled = true
miniLabel.TextXAlignment = Enum.TextXAlignment.Left
miniLabel.TextColor3 = Color3.new(1, 1, 1)
miniLabel.Text = ""
miniLabel.Parent = miniFrame
local miniCap = Instance.new("UITextSizeConstraint")
miniCap.MaxTextSize = 16
miniCap.Parent = miniLabel

-- 왼쪽 위 메뉴 버튼 아래. ScreenGui 기본(IgnoreGuiInset=false) 원점이
-- 이미 메뉴 버튼 아래라, 가로 노치 여유(GetGuiInset X)만 더한다.
local function applyMiniPosition()
	local insetX = 0
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and typeof(inset) == "Vector2" then
		insetX = inset.X
	end
	miniFrame.Position = UDim2.new(0, insetX + 12, 0, 12)
end
applyMiniPosition()

-- 휴대폰 배율: 트윈용 UIScale과 겹치지 않게 글자 프레임에 따로 둔다.
local textUiScale = Instance.new("UIScale")
textUiScale.Parent = textFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
-- 기본 SortOrder(Name)면 LayoutOrder가 무시돼 웨이브 이름이 맨 아래로 가므로 명시한다.
layout.SortOrder = Enum.SortOrder.LayoutOrder
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
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = size
	cap.Parent = label
	return label
end

-- 배너 글자 줄 높이는 기존(30/22/24/22/20/16)의 약 80%다.
local titleLine = makeLabel("Title", 1, 24, Color3.new(1, 1, 1))
local badgeLine = makeLabel("Badge", 2, 18, Color3.fromRGB(120, 220, 255))
local noteLine = makeLabel("Note", 3, 19, Color3.new(1, 1, 1))
local countdownLine = makeLabel("Countdown", 5, 16, Color3.fromRGB(180, 255, 180))
local aiNotice = makeLabel("AINotice", 6, 13, Color3.fromRGB(160, 160, 160))

-- 셋째 줄 행: 보스 초상화(작게, 보스 웨이브에만) + 성문 요약 글자.
-- 글자 프레임 안의 가로 행이라 휴대폰 배율(UIScale)은 그대로 받는다.
local laneRow = Instance.new("Frame")
laneRow.Name = "LanesRow"
laneRow.Size = UDim2.new(1, -16, 0, 18)
laneRow.BackgroundTransparency = 1
laneRow.LayoutOrder = 4
laneRow.Parent = textFrame

local laneRowLayout = Instance.new("UIListLayout")
laneRowLayout.FillDirection = Enum.FillDirection.Horizontal
laneRowLayout.Padding = UDim.new(0, 4)
laneRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
laneRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
laneRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
laneRowLayout.Parent = laneRow

-- [보스] 앞에 작게 붙는 초상화. ID가 0이면 글자만 나온다 (말풍선과 같은 규칙).
local bossPortrait = Instance.new("ImageLabel")
bossPortrait.Name = "BossPortrait"
bossPortrait.Size = UDim2.new(0, 26, 0, 26)
bossPortrait.BackgroundTransparency = 1
bossPortrait.Image = ""
bossPortrait.Visible = false
bossPortrait.LayoutOrder = 1
bossPortrait.Parent = laneRow

local laneLine = Instance.new("TextLabel")
laneLine.Name = "Lanes"
laneLine.Size = UDim2.new(1, -16, 0, 18)
laneLine.BackgroundTransparency = 1
laneLine.TextScaled = true
laneLine.TextColor3 = Color3.fromRGB(255, 230, 150)
laneLine.Text = ""
laneLine.LayoutOrder = 2
laneLine.Parent = laneRow
local laneCap = Instance.new("UITextSizeConstraint")
laneCap.MaxTextSize = 18
laneCap.Parent = laneLine

-- 보스 행 크기: 초상화가 보일 때만 행을 키우고 글자칸을 줄인다.
-- 디렉터 표식과 같이 휴대폰 배율을 받는다.
local BASE_BOSS = 26
local function applyBossRowSize(s)
	local portraitPx = math.floor(BASE_BOSS * s + 0.5)
	if bossPortrait.Visible then
		bossPortrait.Size = UDim2.fromOffset(portraitPx, portraitPx)
		laneRow.Size = UDim2.new(1, -16, 0, portraitPx)
		laneLine.Size = UDim2.new(1, -16 - portraitPx - 4, 0, 18)
	else
		laneRow.Size = UDim2.new(1, -16, 0, 18)
		laneLine.Size = UDim2.new(1, -16, 0, 18)
	end
end

-- 컨테이너 크기는 화면 배율에 맞추고, 글자는 안쪽 UIScale로 맞춘다.
-- iPhone 가로(844x390, 배율 0.55)면 높이가 약 83으로 화면의 35% 안에 든다.
local BASE_W, BASE_H = 520, 150
-- 큰 배너 너비 상한(배율 적용 전 기준): 휴대폰 세로 화면에서 등불 체력바와
-- 겹치지 않게 min(520, 화면 너비 - 24)로 둔다.
local function baseBannerWidth()
	local camera = Workspace.CurrentCamera
	local vw = 1024
	if camera then
		vw = camera.ViewportSize.X
	end
	return math.min(BASE_W, vw - 24)
end
local BASE_BADGE = 40
local currentScale = 1
local function applyBannerScale(s)
	local baseW = baseBannerWidth()
	frame.Size = UDim2.fromOffset(
		math.floor(baseW * s + 0.5),
		math.floor(BASE_H * s + 0.5)
	)
	-- 글자 프레임도 같은 너비로 맞춘다(안쪽 배율로 컨테이너와 같은 크기가 된다).
	textFrame.Size = UDim2.fromOffset(baseW, BASE_H)
	textUiScale.Scale = s
	-- 디렉터 표식도 같은 배율을 받는다.
	directorBadge.Size = UDim2.fromOffset(
		math.floor(BASE_BADGE * s + 0.5),
		math.floor(BASE_BADGE * s + 0.5)
	)
	directorBadge.Position = UDim2.new(1, -math.floor(6 * s + 0.5), 0, math.floor(6 * s + 0.5))
	-- 보스 초상화 행도 같은 배율을 받는다.
	currentScale = s
	applyBossRowSize(s)
	-- 접힌 줄(높이 약 28)도 같은 배율을 받는다.
	miniScale.Scale = s
	applyMiniPosition()
end
UiScale.watch(applyBannerScale)

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

-- 성문 요약: 출발 순서대로 시간을 붙인다.
-- 예: "북문 6 → 동문 4 (+8초) → 서문 3 (+16초)".
-- laneOrder는 서버가 보낸 lane_order(출발 순서 배열)다.
local function laneSummary(lanes, laneOrder)
	if type(laneOrder) == "table" and #laneOrder > 0 then
		local parts = {}
		for i, slot in ipairs(laneOrder) do
			local name = LANE_KO[slot.lane]
			if name and (slot.count or 0) > 0 then
				if i == 1 then
					table.insert(parts, string.format("%s %d", name, slot.count))
				else
					table.insert(parts, string.format(
						"%s %d (+%d초)",
						name,
						slot.count,
						slot.start_at or 0
					))
				end
			end
		end
		return table.concat(parts, " → ")
	end
	local rows = {}
	for lane, count in pairs(lanes) do
		if count > 0 and LANE_KO[lane] then
			table.insert(rows, { lane = lane, count = count })
		end
	end
	table.sort(rows, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return (LANE_ORDER[a.lane] or 99) < (LANE_ORDER[b.lane] or 99)
	end)
	local parts = {}
	for _, row in ipairs(rows) do
		table.insert(parts, string.format("%s %d", LANE_KO[row.lane], row.count))
	end
	return table.concat(parts, " · ")
end

-- 접힌 줄용 성문 이름 나열 (출발 순서, 시간·적 수 없음).
-- 예: "북문 → 동문 → 서문".
local function laneNamesShort(data)
	if type(data.lane_order) == "table" and #data.lane_order > 0 then
		local parts = {}
		for _, slot in ipairs(data.lane_order) do
			local name = LANE_KO[slot.lane]
			if name then
				table.insert(parts, name)
			end
		end
		return table.concat(parts, " → ")
	end
	local order = {}
	for lane, count in pairs(data.lanes or {}) do
		if count > 0 and LANE_KO[lane] then
			table.insert(order, lane)
		end
	end
	table.sort(order, function(a, b)
		local ca, cb = (data.lanes or {})[a] or 0, (data.lanes or {})[b] or 0
		if ca ~= cb then
			return ca > cb
		end
		return (LANE_ORDER[a] or 99) < (LANE_ORDER[b] or 99)
	end)
	local parts = {}
	for _, lane in ipairs(order) do
		table.insert(parts, LANE_KO[lane])
	end
	return table.concat(parts, " → ")
end

-- 접힌 줄 내용: "Day 2 · 웨이브 3/5 · 북문 → 동문 → 서문".
-- 보스 웨이브면 앞에 "[보스]"를 붙인다.
local function miniText(data)
	local prefix = ""
	if data.boss == true then
		prefix = "[보스] "
	end
	return string.format(
		"%sDay %d · 웨이브 %d/%d · %s",
		prefix,
		data.day or 1,
		data.display_wave or 0,
		data.total_waves or 0,
		laneNamesShort(data)
	)
end

-- 계획에서 보스(Warlord)가 나오는 성문의 한글 이름. 없으면 nil.
local function bossLaneKo(plan)
	if type(plan) ~= "table" or type(plan.enemies) ~= "table" then
		return nil
	end
	for _, e in ipairs(plan.enemies) do
		if e.type == "Warlord" and LANE_KO[e.lane] then
			return LANE_KO[e.lane]
		end
	end
	return nil
end

local function render()
	local data = lastData
	if not data then
		return
	end
	local day = data.day or 1
	local totalWaves = data.total_waves or 0
	if data.phase == "lobby" then
		titleLine.Text = string.format("Day %d · %s", day, data.display_name or "")
	else
		titleLine.Text = string.format(
			"Day %d · 웨이브 %d / %d · %s",
			day,
			data.display_wave or 0,
			totalWaves,
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
	-- 보스 웨이브면 앞에 "[보스] 그림자 군주 · 북문"을 붙인다(고정 문구).
	local lanes = laneSummary(data.lanes or {}, data.lane_order)
	local tacticKo = data.plan and TACTIC_KO[data.plan.tactic]
	local bossKo = bossLaneKo(data.plan)
	local bossPrefix = nil
	if data.boss == true and bossKo then
		bossPrefix = string.format("[보스] 그림자 군주 · %s", bossKo)
	end
	local rest = ""
	if lanes ~= "" and tacticKo then
		rest = string.format("%s · %s", lanes, tacticKo)
	elseif lanes ~= "" then
		rest = lanes
	elseif tacticKo then
		rest = tacticKo
	end
	if bossPrefix then
		laneLine.Text = bossPrefix .. (rest ~= "" and " · " .. rest or "")
	else
		laneLine.Text = rest
	end
	-- [보스] 앞에 보스 초상화를 작게 붙인다. ID가 0이면 글자만 나온다.
	local warlordArt = artOf("PortraitWarlord")
	if bossPrefix and warlordArt then
		bossPortrait.Image = warlordArt
		bossPortrait.Visible = true
	else
		bossPortrait.Image = ""
		bossPortrait.Visible = false
	end
	applyBossRowSize(currentScale)
	-- 배경 그림: 보스 웨이브면 BannerBoss를 이벤트 그림보다 먼저 깐다.
	-- ID가 0이면 글자만 나온다.
	local bossArt = data.boss == true and artOf("BannerBoss") or nil
	local eventKey = data.plan and EVENT_ART[data.plan.event]
	local art = bossArt or (eventKey and artOf(eventKey)) or nil
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

-- 접기 상태. 웨이브 시작 6초 뒤 true가 된다.
-- 웨이브 중 상태가 바뀌어도 다시 펼치지 않고 접힌 줄 내용만 갱신한다.
local collapsed = false
local collapseToken = 0

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
	local waveStarted = data.phase == "wave" and lastPhase ~= "wave"
	lastPhase = data.phase
	lastSource = data.source
	lastData = data
	if data.phase == "wave" then
		if waveStarted then
			-- 웨이브 시작: 크게 보여 주고 6초 뒤에 한 줄로 접는다.
			collapseToken += 1
			local token = collapseToken
			collapsed = false
			miniFrame.Visible = false
			render()
			frame.Visible = true
			task.delay(6, function()
				if token == collapseToken and lastData and lastData.phase == "wave" then
					collapsed = true
					frame.Visible = false
					miniLabel.Text = miniText(lastData)
					miniFrame.Visible = true
				end
			end)
		else
			-- 웨이브 중 상태 변경(예: 보스 등장): 다시 펼치지 않는다.
			render()
			if collapsed then
				miniLabel.Text = miniText(data)
			end
		end
	else
		-- 로비·대기·결과: 다시 펼친다 (결과 화면이 맡는 동안은 숨긴다).
		collapseToken += 1
		collapsed = false
		miniFrame.Visible = false
		render()
		frame.Visible = data.phase ~= "result"
	end
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
