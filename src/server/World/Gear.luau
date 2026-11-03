-- 지원대·NPC 직업 장비 (단일 기준: docs/tasks/day14c-fix.md 6단계).
-- R15 모델에 직업 장비를 붙인다. 외부 에셋 금지: Part + WeldConstraint만 쓴다
-- (Figures.attach: 용접, 충돌·쿼리·접촉 끔, 질량 없음).
-- Gear.equip(model, kind): 해당 신체 부위(Head, UpperTorso, LeftHand, RightHand)에
-- 용접한다. 부위가 없으면 그 장비만 건너뛴다.
local Figures = require(script.Parent:WaitForChild("Figures"))

local Gear = {}

local function baseOf(model, name)
	local part = model:FindFirstChild(name)
	if part ~= nil and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function add(base, opts)
	if base == nil then
		return nil
	end
	local copied = table.clone(opts)
	local offset = copied.Offset
	copied.Offset = nil
	copied.CFrame = base.CFrame * (offset or CFrame.new())
	return Figures.attach(base, copied)
end

local METAL_DARK = BrickColor.new("Dark stone grey")
local METAL_LIGHT = BrickColor.new("Medium stone grey")
local WOOD = BrickColor.new("Reddish brown")

local builders = {}

-- guardian: 금속 투구(챙 + 앞 가리개), 어깨 보호대 2,
-- 왼손 둥근 방패(Cylinder, 파란 테두리), 오른손 검(날 + 가드).
function builders.guardian(model)
	local head = baseOf(model, "Head")
	if head then
		local hx, hy, hz = head.Size.X, head.Size.Y, head.Size.Z
		add(head, {
			Name = "Helm", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, hx * 1.15, hz * 1.15),
			Offset = CFrame.new(0, hy / 2 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Metal, BrickColor = METAL_DARK,
		})
		add(head, {
			Name = "Visor", Size = Vector3.new(1, 0.35, 0.25),
			Offset = CFrame.new(0, 0.1, -(hz / 2 + 0.1)),
			Material = Enum.Material.Metal, BrickColor = METAL_DARK,
		})
	end
	local torso = baseOf(model, "UpperTorso")
	if torso then
		local tx, ty, tz = torso.Size.X, torso.Size.Y, torso.Size.Z
		for _, side in ipairs({ -1, 1 }) do
			add(torso, {
				Name = side < 0 and "PauldronL" or "PauldronR",
				Size = Vector3.new(0.8, 0.4, 1.2),
				Offset = CFrame.new(side * (tx / 2 + 0.15), ty / 2 - 0.3, 0),
				Material = Enum.Material.Metal, BrickColor = METAL_LIGHT,
			})
		end
	end
	local handL = baseOf(model, "LeftHand")
	if handL then
		local hx = handL.Size.X
		add(handL, {
			Name = "ShieldRim", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 1.8, 1.8),
			Offset = CFrame.new(-(hx / 2 + 0.3), 0, 0),
			BrickColor = BrickColor.new("Bright blue"),
		})
		add(handL, {
			Name = "Shield", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 1.6, 1.6),
			Offset = CFrame.new(-(hx / 2 + 0.2), 0, 0),
			Material = Enum.Material.Metal, BrickColor = METAL_LIGHT,
		})
	end
	local handR = baseOf(model, "RightHand")
	if handR then
		local hy = handR.Size.Y
		add(handR, {
			Name = "Sword", Size = Vector3.new(0.22, 1.6, 0.22),
			Offset = CFrame.new(0, -(hy / 2 + 0.75), 0),
			Material = Enum.Material.Metal, BrickColor = METAL_LIGHT,
		})
		add(handR, {
			Name = "SwordGuard", Size = Vector3.new(0.7, 0.18, 0.3),
			Offset = CFrame.new(0, -(hy / 2 + 0.05), 0),
			Material = Enum.Material.Metal, BrickColor = METAL_DARK,
		})
	end
end

-- ranger: 초록 두건(머리 뒤), 등의 화살통(Cylinder + 깃 3개), 왼손 활(가는 블록 3개).
function builders.ranger(model)
	local head = baseOf(model, "Head")
	if head then
		add(head, {
			Name = "Hood", Size = Vector3.new(1.3, 1.5, 0.5),
			Offset = CFrame.new(0, 0.3, head.Size.Z / 2 + 0.2),
			BrickColor = BrickColor.new("Dark green"),
		})
	end
	local torso = baseOf(model, "UpperTorso")
	if torso then
		local tz = torso.Size.Z
		add(torso, {
			Name = "Quiver", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.8, 0.6, 0.6),
			Offset = CFrame.new(0.5, 0.2, tz / 2 + 0.3) * CFrame.Angles(0, 0, math.rad(90)),
			BrickColor = WOOD,
		})
		for _, dx in ipairs({ -0.2, 0, 0.2 }) do
			add(torso, {
				Name = "Fletch", Size = Vector3.new(0.15, 0.4, 0.15),
				Offset = CFrame.new(0.5 + dx, 1.3, tz / 2 + 0.3),
				BrickColor = BrickColor.new("White"),
			})
		end
	end
	local handL = baseOf(model, "LeftHand")
	if handL then
		local hx = handL.Size.X
		add(handL, {
			Name = "BowMid", Size = Vector3.new(0.18, 1.1, 0.18),
			Offset = CFrame.new(-(hx / 2 + 0.2), 0, 0),
			BrickColor = WOOD,
		})
		add(handL, {
			Name = "BowTop", Size = Vector3.new(0.18, 0.9, 0.18),
			Offset = CFrame.new(-(hx / 2 + 0.35), 0.85, 0) * CFrame.Angles(0, 0, math.rad(25)),
			BrickColor = WOOD,
		})
		add(handL, {
			Name = "BowBottom", Size = Vector3.new(0.18, 0.9, 0.18),
			Offset = CFrame.new(-(hx / 2 + 0.35), -0.85, 0) * CFrame.Angles(0, 0, math.rad(-25)),
			BrickColor = WOOD,
		})
	end
end

-- cleric: 흰 로브 자락(몸통 아래 앞뒤 판) + 후드, 오른손 지팡이 + 끝 초록 Neon 공.
function builders.cleric(model)
	local torso = baseOf(model, "UpperTorso")
	if torso then
		local ty, tz = torso.Size.Y, torso.Size.Z
		for _, side in ipairs({ -1, 1 }) do
			add(torso, {
				Name = side < 0 and "RobeFront" or "RobeBack",
				Size = Vector3.new(1.6, 1.8, 0.25),
				Offset = CFrame.new(0, -(ty / 2 + 0.8), side * (tz / 2 + 0.05)),
				BrickColor = BrickColor.new("White"),
			})
		end
	end
	local head = baseOf(model, "Head")
	if head then
		add(head, {
			Name = "Hood", Size = Vector3.new(1.3, 1.4, 0.45),
			Offset = CFrame.new(0, 0.3, head.Size.Z / 2 + 0.2),
			BrickColor = BrickColor.new("White"),
		})
	end
	local handR = baseOf(model, "RightHand")
	if handR then
		add(handR, {
			Name = "Staff", Size = Vector3.new(0.22, 3.4, 0.22),
			Offset = CFrame.new(0, 1.0, 0),
			BrickColor = WOOD,
		})
		add(handR, {
			Name = "StaffTip", Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.55, 0.55, 0.55),
			Offset = CFrame.new(0, 2.9, 0),
			Material = Enum.Material.Neon, BrickColor = BrickColor.new("Bright green"),
		})
	end
end

-- arcanist: 보라 고깔모자(Cylinder 챙 + 좁아지는 블록 2단), 오른손 지팡이 + 끝 보라 Neon 공.
function builders.arcanist(model)
	local head = baseOf(model, "Head")
	if head then
		local hy = head.Size.Y
		add(head, {
			Name = "HatBrim", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 2.2, 2.2),
			Offset = CFrame.new(0, hy / 2 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			BrickColor = BrickColor.new("Bright violet"),
		})
		add(head, {
			Name = "HatLow", Size = Vector3.new(1.2, 0.8, 1.2),
			Offset = CFrame.new(0, hy / 2 + 0.6, 0),
			BrickColor = BrickColor.new("Bright violet"),
		})
		add(head, {
			Name = "HatTop", Size = Vector3.new(0.7, 0.8, 0.7),
			Offset = CFrame.new(0, hy / 2 + 1.4, 0),
			BrickColor = BrickColor.new("Dark indigo"),
		})
	end
	local handR = baseOf(model, "RightHand")
	if handR then
		add(handR, {
			Name = "Staff", Size = Vector3.new(0.22, 3, 0.22),
			Offset = CFrame.new(0, 0.9, 0),
			BrickColor = WOOD,
		})
		add(handR, {
			Name = "StaffTip", Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.55, 0.55, 0.55),
			Offset = CFrame.new(0, 2.6, 0),
			Material = Enum.Material.Neon, BrickColor = BrickColor.new("Bright violet"),
		})
	end
end

-- bram: guardian 장비 + 등의 진홍 망토 + 회색 수염.
function builders.bram(model)
	builders.guardian(model)
	local torso = baseOf(model, "UpperTorso")
	if torso then
		add(torso, {
			Name = "Cloak", Size = Vector3.new(1.9, 3, 0.25),
			Offset = CFrame.new(0, -0.5, torso.Size.Z / 2 + 0.15),
			BrickColor = BrickColor.new("Crimson"),
		})
	end
	local head = baseOf(model, "Head")
	if head then
		add(head, {
			Name = "Beard", Size = Vector3.new(0.8, 0.8, 0.3),
			Offset = CFrame.new(0, -(head.Size.Y / 2 + 0.2), -(head.Size.Z / 2 + 0.1)),
			BrickColor = METAL_LIGHT,
		})
	end
end

-- mira: cleric 장비 + 등의 초록 망토 + 머리 위 작은 화관(Neon 연두 공 3개).
function builders.mira(model)
	builders.cleric(model)
	local torso = baseOf(model, "UpperTorso")
	if torso then
		add(torso, {
			Name = "Cloak", Size = Vector3.new(1.9, 3, 0.25),
			Offset = CFrame.new(0, -0.5, torso.Size.Z / 2 + 0.15),
			BrickColor = BrickColor.new("Dark green"),
		})
	end
	local head = baseOf(model, "Head")
	if head then
		local hy = head.Size.Y
		for _, dx in ipairs({ -0.4, 0, 0.4 }) do
			add(head, {
				Name = "Flower", Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.3, 0.3, 0.3),
				Offset = CFrame.new(dx, hy / 2 + 0.25, 0),
				Material = Enum.Material.Neon, BrickColor = BrickColor.new("Lime green"),
			})
		end
	end
end

-- R15 모델에 직업 장비를 붙인다. 모르는 kind는 아무것도 하지 않는다.
function Gear.equip(model, kind)
	if model == nil then
		return
	end
	local build = builders[kind]
	if build then
		build(model)
	end
end

return Gear
