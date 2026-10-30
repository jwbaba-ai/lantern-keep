-- 서버 시작 시 그레이박스 맵을 코드로 생성한다 (단일 기준: docs/GAME_DESIGN.md 맵 절).
-- workspace.Map이 없으면 만든다. 만들든 말든 끝에는 Ready 어트리뷰트를 true로 둔다.
-- 구조: Map/ Lantern(Health 어트리뷰트), Gates/<lane>, Spawns/<lane>, Lanes/<lane>/"1".."3".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MapDecor = require(script.Parent:WaitForChild("MapDecor"))

local GATE_DISTANCE = 60 -- 등불에서 성문까지
local SPAWN_DISTANCE = 210 -- 등불에서 스폰 지점까지 (성문 바깥 150)
local GATE_COLORS = {
	north = "Bright blue",
	south = "Bright red",
	east = "Bright yellow",
	west = "Bright green",
}

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function laneDirection(lane)
	if lane == "north" then
		return Vector3.new(0, 0, -1)
	elseif lane == "south" then
		return Vector3.new(0, 0, 1)
	elseif lane == "east" then
		return Vector3.new(1, 0, 0)
	else
		return Vector3.new(-1, 0, 0)
	end
end

-- 성문 방향 이름표 (고정 문구라 필터 없음).
-- 배너의 성문 표기(북문·남문·동문·서문)와 같은 이름 + 영문 약자를 함께 쓴다.
local GATE_LABEL = {
	north = "북문 N",
	south = "남문 S",
	east = "동문 E",
	west = "서문 W",
}

local function addGateLabel(gate, lane)
	if gate:FindFirstChild("GateLabel") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "GateLabel"
	tag.Adornee = gate
	-- 글자 높이 y 30(성문 중심 6 + 24): 탑 꼭대기(톱니 y 25)보다 위라 가로대·탑에 가리지 않는다.
	tag.Size = UDim2.fromScale(10, 3)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 24, 0)
	tag.MaxDistance = 250
	tag.AlwaysOnTop = true
	tag.Parent = gate
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Text = GATE_LABEL[lane]
	text.TextColor3 = BrickColor.new(GATE_COLORS[lane]).Color
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.TextStrokeTransparency = 0
	text.Parent = tag
end

local function buildMap()
	local map = Instance.new("Folder")
	map.Name = "Map"

	-- 등불: 높은 기둥 + 빛. Health 어트리뷰트가 경기 체력이다.
	local lantern = makePart({
		Name = "Lantern",
		Size = Vector3.new(4, 20, 4),
		Position = Vector3.new(0, 10, 0),
		BrickColor = BrickColor.new("Bright yellow"),
		Material = Enum.Material.Neon,
	})
	lantern:SetAttribute("Health", Config.LanternMaxHealth)
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 60
	light.Parent = lantern
	lantern.Parent = map

	local gates = Instance.new("Folder")
	gates.Name = "Gates"
	gates.Parent = map
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = map
	local lanes = Instance.new("Folder")
	lanes.Name = "Lanes"
	lanes.Parent = map

	for _, lane in ipairs(Config.Lanes) do
		local dir = laneDirection(lane)
		local gatePos = dir * GATE_DISTANCE
		local spawnPos = dir * SPAWN_DISTANCE

		-- 성문 (동/서는 길쭉한 방향을 90도 돌린다)
		local wideX = lane == "north" or lane == "south"
		local gate = makePart({
			Name = lane,
			Size = wideX and Vector3.new(16, 12, 2) or Vector3.new(2, 12, 16),
			Position = Vector3.new(gatePos.X, 6, gatePos.Z),
			BrickColor = BrickColor.new(GATE_COLORS[lane]),
		})
		gate.Parent = gates
		addGateLabel(gate, lane)

		-- 스폰 지점 (납작한 패드)
		local pad = makePart({
			Name = lane,
			Size = Vector3.new(6, 1, 6),
			Position = Vector3.new(spawnPos.X, 0.5, spawnPos.Z),
			BrickColor = BrickColor.new("Medium stone grey"),
		})
		pad.Parent = spawns

		-- 웨이포인트: 스폰 -> 성문 -> 등불 앞. 이름은 순서대로 "1".."3".
		local laneFolder = Instance.new("Folder")
		laneFolder.Name = lane
		laneFolder.Parent = lanes
		local points = {
			Vector3.new(spawnPos.X, 3, spawnPos.Z),
			Vector3.new(gatePos.X, 3, gatePos.Z),
			dir * 6 + Vector3.new(0, 3, 0),
		}
		for i, pos in ipairs(points) do
			local wp = makePart({
				Name = tostring(i),
				Size = Vector3.new(2, 2, 2),
				Position = pos,
				Transparency = 1,
			})
			wp.Parent = laneFolder
		end
	end

	map.Parent = workspace
	return map
end

local map = workspace:FindFirstChild("Map")
if not map then
	map = buildMap()
end
-- 이미 저장된 맵에도 이름표가 없으면 붙인다.
local gatesFolder = map:FindFirstChild("Gates")
if gatesFolder then
	for _, lane in ipairs(Config.Lanes) do
		local gate = gatesFolder:FindFirstChild(lane)
		if gate then
			addGateLabel(gate, lane)
		end
	end
end
-- 장식은 pcall로: 실패해도 Ready는 켜고 경기는 진행한다.
local ok, decorParts, decorLights, decorParticles = pcall(MapDecor.build, map)
if ok then
	print(string.format("[Map] decor parts=%d lights=%d particles=%d", decorParts, decorLights, decorParticles))
else
	warn("[Map] decor failed: " .. tostring(decorParts))
end
map:SetAttribute("Ready", true)
print("[Map] ready: lantern=" .. Config.LanternMaxHealth .. " gates=4 spawns=4 lanes=4")
