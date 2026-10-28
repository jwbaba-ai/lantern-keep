-- 파티 인원 보정 (단일 기준: docs/tasks/day4.md 0-1.5).
-- 웨이브 계획(디렉터·대체 모두)이 검증을 통과한 뒤, 적용 직전에 적 수를 줄인다.
-- Config 값과 FallbackWaves·EnemyCatalog 수치는 바꾸지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local PartyScale = {}

-- 인원을 1~4 인덱스로 바꾼다 (0명 자동 테스트는 1인과 같다).
function PartyScale.index(partySize)
	return math.clamp(partySize or 1, 1, 4)
end

function PartyScale.countScale(partySize)
	return Config.PartyCountScale[PartyScale.index(partySize)]
end

function PartyScale.healthScale(partySize)
	return Config.PartyHealthScale[PartyScale.index(partySize)]
end

-- 계획 복사본의 적 count를 인원 배율로 줄인다 (올림, 최소 1).
-- 돌려값: scaledPlan, scaledTotal.
function PartyScale.scalePlan(plan, partySize)
	local mult = PartyScale.countScale(partySize)
	local scaled = {
		wave_name = plan.wave_name,
		enemies = {},
		tactic = plan.tactic,
		event = plan.event,
		director_note = plan.director_note,
	}
	local total = 0
	for _, e in ipairs(plan.enemies) do
		local count = math.max(1, math.ceil(e.count * mult))
		table.insert(scaled.enemies, { type = e.type, count = count, lane = e.lane })
		total += count
	end
	return scaled, total
end

return PartyScale
