-- CombatService 조준·쿨다운 판정 확인 (단일 기준: docs/tasks/day4.md 0-1.1).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Combat["CombatService.spec"])
-- require 한 줄로 아래 4건을 PASS/FAIL로 출력한다.
local CombatFolder = script.Parent
local CombatService = require(CombatFolder:WaitForChild("CombatService"))

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

return results
