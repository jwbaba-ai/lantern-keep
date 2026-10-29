-- 맵 장식 (단일 기준: docs/tasks/day11.md).
-- 기본 도형·Enum.Material·Lighting·PointLight·Fire만 쓴다(외부 에셋 금지).
-- 게임 동작에 쓰는 이름과 좌표는 그대로 둔다: Map/Lantern, Map/Gates/<lane> 등.
-- 장식은 map(workspace.Map) 아래 Decor 폴더에만 만든다.
-- Decor가 이미 있으면 다시 만들지 않는다(멱등). 이미 저장된 place에서도 돌아간다.
-- 실패해도 경기가 멈추지 않게 MapBuilder가 pcall로 부른다.
local MapDecor = {}

-- 휴대폰 성능 예산 (day11 공통 규칙).
MapDecor.Budget = {
	Parts = 400,
	Lights = 12,
	Particles = 8,
}

-- 성문 방향 (MapBuilder와 같은 약속: north=(0,0,-1) ...).
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

-- 성문 축에 수직인 방향 (성벽·문틀 배치용).
local function lanePerp(lane)
	if lane == "north" or lane == "south" then
		return Vector3.new(1, 0, 0)
	else
		return Vector3.new(0, 0, 1)
	end
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

-- 원기둥 파트 (CylinderMesh는 파트 bounds에 내접한다. 정사각형에만 쓴다).
local function makeCylinder(props, diameter, height)
	local p = makePart(props)
	p.Size = Vector3.new(height, diameter, diameter)
	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = p
	return p
end

-- 바닥: Baseplate가 있으면 재질·색만 바꾼다(크기·위치·충돌 그대로).
local function applyBaseplate()
	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		base.Material = Enum.Material.Cobblestone
		base.Color = Color3.fromRGB(64, 58, 52)
	end
end

-- 성채 안쪽 광장: 반지름 55 Slate 원판 (얇고 충돌 없음).
local function buildPlaza(decor)
	local disc = makeCylinder({
		Name = "Plaza",
		Position = Vector3.new(0, 0.1, 0),
		Material = Enum.Material.Slate,
		BrickColor = BrickColor.new("Medium stone grey"),
	}, 110, 0.2)
	disc.Parent = decor
end

-- 반지름 60 사각 성벽. 성문 구멍은 성문 폭(16)보다 4 이상 넓게(20) 비운다.
-- 높이 14, 두께 4, 재질 Brick 또는 Slate, CanCollide=true.
local WALL_RADIUS = 60
local WALL_GAP_HALF = 10 -- 구멍 반폭 (전체 20)
local WALL_LEN = 52 -- 모서리(-62)에서 구멍 끝(-10)까지
local WALL_CENTER = 36 -- (62 + 10) / 2

local function buildWalls(decor)
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		local dir = laneDirection(lane)
		local perp = lanePerp(lane)
		local center = dir * WALL_RADIUS
		local wideX = (lane == "north" or lane == "south")
		for _, side in ipairs({ -1, 1 }) do
			local pos = center + perp * (side * WALL_CENTER)
			local seg = makePart({
				Name = "Wall_" .. lane .. "_" .. (side < 0 and "L" or "R"),
				Size = wideX and Vector3.new(WALL_LEN, 14, 4) or Vector3.new(4, 14, WALL_LEN),
				Position = Vector3.new(pos.X, 7, pos.Z),
				Material = Enum.Material.Brick,
				BrickColor = BrickColor.new("Dark stone grey"),
				CanCollide = true,
			})
			seg.Parent = decor
		end
	end
end

-- 성문 양옆 탑: 높이 22 원기둥 + 꼭대기 흉벽(뚜껑 + 톱니 4개). 성벽 위에 선다.
local function buildTowers(decor)
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		local dir = laneDirection(lane)
		local perp = lanePerp(lane)
		local center = dir * WALL_RADIUS
		for _, side in ipairs({ -1, 1 }) do
			local base = center + perp * (side * 14)
			local tag = lane .. (side < 0 and "L" or "R")
			local tower = makeCylinder({
				Name = "Tower_" .. tag,
				Position = Vector3.new(base.X, 11, base.Z),
				Material = Enum.Material.Slate,
				BrickColor = BrickColor.new("Dark stone grey"),
				CanCollide = true,
			}, 6, 22)
			tower.Parent = decor
			local cap = makeCylinder({
				Name = "TowerCap_" .. tag,
				Position = Vector3.new(base.X, 22.5, base.Z),
				Material = Enum.Material.Slate,
				BrickColor = BrickColor.new("Medium stone grey"),
			}, 8, 1)
			cap.Parent = decor
			-- 흉벽 톱니 4개 (뚜껑 가장자리).
			for _, off in ipairs({ Vector3.new(2.5, 0, 0), Vector3.new(-2.5, 0, 0), Vector3.new(0, 0, 2.5), Vector3.new(0, 0, -2.5) }) do
				local tooth = makePart({
					Name = "TowerTooth_" .. tag,
					Size = Vector3.new(1.5, 2, 1.5),
					Position = Vector3.new(base.X + off.X, 24, base.Z + off.Z),
					Material = Enum.Material.Slate,
					BrickColor = BrickColor.new("Medium stone grey"),
				})
				tooth.Parent = decor
			end
		end
	end
end

-- 성문: 재질만 WoodPlanks로 (방향 색 유지). 문틀(기둥 2 + 가로대)은 Decor에.
local function applyGateMaterial(gates)
	if not gates then
		return
	end
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		local gate = gates:FindFirstChild(lane)
		if gate and gate:IsA("BasePart") then
			gate.Material = Enum.Material.WoodPlanks
		end
	end
end

local function buildGateFrames(decor, gates)
	if not gates then
		return
	end
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		if gates:FindFirstChild(lane) then
			local dir = laneDirection(lane)
			local perp = lanePerp(lane)
			local center = dir * WALL_RADIUS
			local wideX = (lane == "north" or lane == "south")
			-- 구멍 가장자리에 서는 나무 기둥 2개 (성벽 끝과 겹쳐 문설주처럼 보인다).
			for _, side in ipairs({ -1, 1 }) do
				local ppos = center + perp * (side * 11)
				local post = makePart({
					Name = "GatePost_" .. lane .. "_" .. (side < 0 and "L" or "R"),
					Size = Vector3.new(2, 14, 2),
					Position = Vector3.new(ppos.X, 7, ppos.Z),
					Material = Enum.Material.Wood,
					BrickColor = BrickColor.new("Reddish brown"),
				})
				post.Parent = decor
			end
			-- 위 가로대 (성벽 위로 지나간다. 충돌 없음).
			local lintel = makePart({
				Name = "GateLintel_" .. lane,
				Size = wideX and Vector3.new(24, 2, 2) or Vector3.new(2, 2, 24),
				Position = Vector3.new(center.X, 15, center.Z),
				Material = Enum.Material.Wood,
				BrickColor = BrickColor.new("Reddish brown"),
			})
			lintel.Parent = decor
		end
	end
end

-- 길: 각 성문에서 스폰 패드까지 폭 10 흙길 (얇고 충돌 없음).
local function buildRoads(decor)
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		local dir = laneDirection(lane)
		local mid = dir * 135 -- 성문(60)과 스폰(210)의 중간
		local wideX = (lane == "north" or lane == "south")
		local road = makePart({
			Name = "Road_" .. lane,
			Size = wideX and Vector3.new(10, 0.2, 150) or Vector3.new(150, 0.2, 10),
			Position = Vector3.new(mid.X, 0.1, mid.Z),
			Material = Enum.Material.Ground,
			BrickColor = BrickColor.new("Brown"),
		})
		road.Parent = decor
	end
end

-- 바깥: 성 밖 길 양옆에 바위와 죽은 나무.
-- 길 위(웨이포인트 직선 양옆 6 이내)에는 두지 않는다: 옆 간격 12 이상.
local OUTSIDE_SPOTS = {
	{ along = 80, side = 14 }, { along = 120, side = -16 }, { along = 160, side = 18 },
	{ along = 100, side = 22, tree = true }, { along = 180, side = -24, tree = true },
}

local function buildOutside(decor)
	local rockSizes = { Vector3.new(4, 3, 5), Vector3.new(6, 4, 4), Vector3.new(3, 5, 3) }
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		local dir = laneDirection(lane)
		local perp = lanePerp(lane)
		for i, spot in ipairs(OUTSIDE_SPOTS) do
			local pos = dir * spot.along + perp * spot.side
			if spot.tree then
				-- 죽은 나무: 줄기 + 기울어진 가지.
				local trunk = makeCylinder({
					Name = "DeadTree_" .. lane .. "_" .. i,
					Position = Vector3.new(pos.X, 5, pos.Z),
					Material = Enum.Material.Wood,
					BrickColor = BrickColor.new("Dark brown"),
					CanCollide = true,
				}, 2, 10)
				trunk.Parent = decor
				local branch = makePart({
					Name = "DeadBranch_" .. lane .. "_" .. i,
					Size = Vector3.new(1, 5, 1),
					Material = Enum.Material.Wood,
					BrickColor = BrickColor.new("Dark brown"),
					CanCollide = true,
				})
				branch.CFrame = CFrame.new(Vector3.new(pos.X, 9, pos.Z)) * CFrame.Angles(0, 0, 0.6)
				branch.Parent = decor
			else
				local rock = makePart({
					Name = "Rock_" .. lane .. "_" .. i,
					Size = rockSizes[((i - 1) % #rockSizes) + 1],
					Position = Vector3.new(pos.X, 1.5, pos.Z),
					Material = Enum.Material.Rock,
					BrickColor = BrickColor.new("Medium stone grey"),
					CanCollide = true,
				})
				rock.Parent = decor
			end
		end
	end
end

-- 등불: 기존 Lantern 파트는 그대로 둔다(위치·크기·Neon·PointLight·Health).
-- Decor에 돌 받침대 3단 + 꼭대기 금속 고리 + Fire 하나를 붙인다.
-- 체력이 낮아지면 Fire.Size가 작아진다(최소 2).
local LANTERN_FIRE_BASE_SIZE = 8
local LANTERN_FIRE_MIN_SIZE = 2

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local function buildLantern(decor, lantern)
	if not lantern or not lantern:IsA("BasePart") then
		return
	end
	for i, spec in ipairs({ { d = 12, y = 0.5 }, { d = 9, y = 1.5 }, { d = 6, y = 2.5 } }) do
		local step = makeCylinder({
			Name = "LanternBase_" .. i,
			Position = Vector3.new(0, spec.y, 0),
			Material = Enum.Material.Slate,
			BrickColor = BrickColor.new("Dark stone grey"),
		}, spec.d, 1)
		step.Parent = decor
	end
	-- 꼭대기 금속 고리 (얇은 원판) + 그 위 Fire.
	local ring = makeCylinder({
		Name = "LanternRing",
		Position = Vector3.new(0, 20.5, 0),
		Material = Enum.Material.Metal,
		BrickColor = BrickColor.new("Bright yellow"),
	}, 3, 1)
	ring.Parent = decor
	local fire = Instance.new("Fire")
	fire.Name = "LanternFire"
	fire.Size = LANTERN_FIRE_BASE_SIZE
	fire.Heat = 9
	fire.Parent = ring
	local function updateFire()
		local health = lantern:GetAttribute("Health")
		if typeof(health) ~= "number" then
			health = Config.LanternMaxHealth
		end
		local frac = math.clamp(health / Config.LanternMaxHealth, 0, 1)
		fire.Size = math.max(LANTERN_FIRE_MIN_SIZE, LANTERN_FIRE_BASE_SIZE * frac)
	end
	updateFire()
	lantern:GetAttributeChangedSignal("Health"):Connect(updateFire)
end

-- 밤 분위기: 서버에서 한 번 정한다. 적·플레이어가 잘 보이게 너무 어둡지 않게.
local function applyLighting()
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 19.5 -- 해 질 녘
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.fromRGB(40, 45, 70) -- 어두운 남색
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 45, 70)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.3
	atmo.Color = Color3.fromRGB(50, 30, 80) -- 어두운 보라
end

-- 성벽 횃불: 탑마다 주황 PointLight(범위 18) 하나씩, 합계 8개.
-- 불꽃은 Neon 파트로 (파티클 예산을 아끼기 위해 Fire 대신).
local function buildTorches(decor)
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		local dir = laneDirection(lane)
		local perp = lanePerp(lane)
		local center = dir * WALL_RADIUS
		for _, side in ipairs({ -1, 1 }) do
			local base = center + perp * (side * 14)
			local tag = lane .. (side < 0 and "L" or "R")
			local tip = makePart({
				Name = "Torch_" .. tag,
				Size = Vector3.new(1, 2, 1),
				Position = Vector3.new(base.X, 24, base.Z),
				Material = Enum.Material.Neon,
				BrickColor = BrickColor.new("Bright orange"),
			})
			tip.Parent = decor
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 140, 40)
			glow.Range = 18
			glow.Parent = tip
		end
	end
end

-- Decor 아래 실제 수를 센다(파트·광원·파티클).
local function countDecor(decor)
	local parts, lights, particles = 0, 0, 0
	for _, inst in ipairs(decor:GetDescendants()) do
		if inst:IsA("BasePart") then
			parts += 1
		elseif inst:IsA("Light") then
			lights += 1
		elseif inst:IsA("Fire") or inst:IsA("ParticleEmitter") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
			particles += 1
		end
	end
	return parts, lights, particles
end

-- map(workspace.Map)에 장식을 만든다. 파트·광원·파티클 수를 돌려준다.
function MapDecor.build(map)
	local decor = map:FindFirstChild("Decor")
	if decor then
		return countDecor(decor)
	end
	decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map
	applyBaseplate()
	buildPlaza(decor)
	buildWalls(decor)
	buildTowers(decor)
	local gates = map:FindFirstChild("Gates")
	applyGateMaterial(gates)
	buildGateFrames(decor, gates)
	buildRoads(decor)
	buildOutside(decor)
	buildLantern(decor, map:FindFirstChild("Lantern"))
	applyLighting()
	buildTorches(decor)
	return countDecor(decor)
end

return MapDecor
