-- 공격 자동 조준 (단일 기준: docs/tasks/day14c-fix.md 3-1단계).
-- 서버·클라이언트 공용 순수 함수. ClassCatalog(수치 단일 기준)를 읽는다.
-- candidates: { { pos = Vector3, ref = any }, ... } (살아 있는 적만 넣는다).
-- pick(classKey, rootPos, aim, candidates) -> 고른 후보 하나 또는 nil.
--   ranger: 사거리 안 후보 중 조준 방향(수평)과 이루는 각이 25도 안이면
--     각이 가장 작은 후보, 없으면 가장 가까운 후보.
--   arcanist: 사거리 안 후보 중 aim에 가장 가까운 후보.
--   guardian: Radius + 2 안의 가장 가까운 후보.
--   cleric: 언제나 nil(반경 판정 그대로).
-- 사거리 안에 후보가 없으면 nil. 길이 0인 방향은 nil 처리 없이
-- "가장 가까운 후보" 규칙으로 넘긴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassCatalog = require(Shared:WaitForChild("ClassCatalog"))

local AutoTarget = {}

local AIM_ANGLE_DEG = 25

-- 수평 벡터 사이 각도(도). 길이 0이면 nil.
local function flatAngle(a, b)
	local ma, mb = a.Magnitude, b.Magnitude
	if ma < 1e-6 or mb < 1e-6 then
		return nil
	end
	local cos = math.clamp(a:Dot(b) / (ma * mb), -1, 1)
	return math.deg(math.acos(cos))
end

local function nearestInRange(list, rootPos)
	local best, bestDist = nil, nil
	for _, c in ipairs(list) do
		local d = (c.pos - rootPos).Magnitude
		if bestDist == nil or d < bestDist then
			best, bestDist = c, d
		end
	end
	return best
end

function AutoTarget.pick(classKey, rootPos, aim, candidates)
	if classKey == "cleric" then
		return nil
	end
	local spec = ClassCatalog[classKey]
	if not spec then
		return nil
	end
	if classKey == "ranger" then
		local inRange = {}
		for _, c in ipairs(candidates) do
			if (c.pos - rootPos).Magnitude <= spec.Range then
				table.insert(inRange, c)
			end
		end
		if #inRange == 0 then
			return nil
		end
		local aimDir = Vector3.new(aim.X - rootPos.X, 0, aim.Z - rootPos.Z)
		if aimDir.Magnitude >= 0.01 then
			local best, bestAngle = nil, nil
			for _, c in ipairs(inRange) do
				local to = Vector3.new(c.pos.X - rootPos.X, 0, c.pos.Z - rootPos.Z)
				local ang = flatAngle(aimDir, to)
				if ang ~= nil and ang <= AIM_ANGLE_DEG and (bestAngle == nil or ang < bestAngle) then
					best, bestAngle = c, ang
				end
			end
			if best ~= nil then
				return best
			end
		end
		return nearestInRange(inRange, rootPos)
	elseif classKey == "arcanist" then
		local best, bestDist = nil, nil
		for _, c in ipairs(candidates) do
			if (c.pos - rootPos).Magnitude <= spec.Range then
				local d = (c.pos - aim).Magnitude
				if bestDist == nil or d < bestDist then
					best, bestDist = c, d
				end
			end
		end
		return best
	elseif classKey == "guardian" then
		local best, bestDist = nil, nil
		for _, c in ipairs(candidates) do
			local d = (c.pos - rootPos).Magnitude
			if d <= spec.Radius + 2 and (bestDist == nil or d < bestDist) then
				best, bestDist = c, d
			end
		end
		return best
	end
	return nil
end

return AutoTarget
