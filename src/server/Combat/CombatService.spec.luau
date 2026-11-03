-- CombatService 조준·쿨다운·자동 조준 판정 확인 (단일 기준: docs/tasks/day4.md 0-1.1, day14c-fix.md 3-3).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Combat["CombatService.spec"])
-- require 한 줄로 아래 항목들을 PASS/FAIL로 출력한다.
local CombatFolder = script.Parent
local CombatService = require(CombatFolder:WaitForChild("CombatService"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AutoTarget = require(Shared:WaitForChild("AutoTarget"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[CombatService.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

local root = Vector3.new(0, 3, 0)

-- 1. guardian이 200스터드 밖 조준 → 허용 (조준 그대로).
do
	local aim = root + Vector3.new(200, 0, 0)
	check("guardian_far_aim_allowed", CombatService.resolveAim("guardian", root, aim) == aim)
end

-- 2. ranger가 500스터드 밖 조준 → 허용 (방향만 쓰므로 그대로).
do
	local aim = root + Vector3.new(500, 0, 0)
	check("ranger_far_aim_allowed", CombatService.resolveAim("ranger", root, aim) == aim)
end

-- 3. arcanist가 300스터드 밖 조준 → 조준점이 80스터드 이내로 잘림.
do
	local aim = root + Vector3.new(300, 0, 0)
	local fixed = CombatService.resolveAim("arcanist", root, aim)
	check("arcanist_aim_clamped", (fixed - root).Magnitude <= 80 + 1e-3)
end

-- 4. 쿨다운 안 재공격 → 거부.
do
	local fakeUserId = 999001
	CombatService.markAttacked(fakeUserId, 1000.0)
	-- guardian 쿨다운 0.8초: 0.5초 뒤는 거부, 1.0초 뒤는 허용.
	local rejected = not CombatService.checkCooldown("guardian", fakeUserId, 1000.5)
	local allowed = CombatService.checkCooldown("guardian", fakeUserId, 1001.0)
	check("cooldown_reattack_rejected", rejected and allowed)
end

-- 5. ranger: 조준 방향 20도인 먼 적이 40도인 가까운 적보다 먼저 골라짐.
do
	local aim = root + Vector3.new(50, 0, 0)
	local far = root + Vector3.new(math.cos(math.rad(20)) * 100, 0, math.sin(math.rad(20)) * 100)
	local near = root + Vector3.new(math.cos(math.rad(40)) * 30, 0, math.sin(math.rad(40)) * 30)
	local picked = AutoTarget.pick("ranger", root, aim, {
		{ pos = far, ref = "far" },
		{ pos = near, ref = "near" },
	})
	check("ranger_angle_beats_distance", picked ~= nil and picked.ref == "far")
end

-- 6. ranger: 25도 안에 없으면 가장 가까운 적.
do
	local aim = root + Vector3.new(50, 0, 0)
	local mid = root + Vector3.new(math.cos(math.rad(30)) * 20, 0, math.sin(math.rad(30)) * 20)
	local near = root + Vector3.new(math.cos(math.rad(40)) * 10, 0, math.sin(math.rad(40)) * 10)
	local picked = AutoTarget.pick("ranger", root, aim, {
		{ pos = mid, ref = "mid" },
		{ pos = near, ref = "near" },
	})
	check("ranger_no_angle_falls_back_to_nearest", picked ~= nil and picked.ref == "near")
end

-- 7. ranger: 사거리 밖만 있으면 nil (ranger Range 120).
do
	local aim = root + Vector3.new(50, 0, 0)
	local far = root + Vector3.new(150, 0, 0)
	local picked = AutoTarget.pick("ranger", root, aim, { { pos = far, ref = "far" } })
	check("ranger_out_of_range_nil", picked == nil)
end

-- 8. arcanist: aim에 가장 가까운 적. 사거리 밖은 제외 (arcanist Range 80).
do
	local aim = root + Vector3.new(95, 0, 0)
	local close = root + Vector3.new(10, 0, 0)
	local outOfRange = root + Vector3.new(100, 0, 0)
	local picked = AutoTarget.pick("arcanist", root, aim, {
		{ pos = close, ref = "close" },
		{ pos = outOfRange, ref = "out" },
	})
	check("arcanist_nearest_to_aim_in_range", picked ~= nil and picked.ref == "close")
end

-- 9. guardian: Radius + 2(10) 밖은 nil, 안은 가장 가까운 적.
do
	local aim = root
	local out = root + Vector3.new(12, 0, 0)
	local pickedOut = AutoTarget.pick("guardian", root, aim, { { pos = out, ref = "out" } })
	local near = root + Vector3.new(5, 0, 0)
	local pickedIn = AutoTarget.pick("guardian", root, aim, {
		{ pos = out, ref = "out" },
		{ pos = near, ref = "near" },
	})
	check(
		"guardian_radius_plus_two",
		pickedOut == nil and pickedIn ~= nil and pickedIn.ref == "near"
	)
end

-- 10. cleric: 언제나 nil.
do
	local aim = root + Vector3.new(5, 0, 0)
	local near = root + Vector3.new(3, 0, 0)
	local picked = AutoTarget.pick("cleric", root, aim, { { pos = near, ref = "near" } })
	check("cleric_always_nil", picked == nil)
end

return results
