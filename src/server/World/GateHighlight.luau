-- 공격 성문 강조 (단일 기준: docs/tasks/day4.md 3단계).
-- 다음 웨이브가 정해지면 대기 시간 동안 적이 오는 성문을 깜빡인다.
-- 적 수가 많을수록 빠르게 깜빡인다. 웨이브가 시작되면 원래대로 되돌린다.
-- 맵 파트 이름·구조는 MapBuilder가 만든 것을 그대로 쓴다 (Map/Gates/<lane>).
local GateHighlight = {}

local generation = 0

local function setGateTransparency(map, lane, value)
	local gates = map:FindFirstChild("Gates")
	local gate = gates and gates:FindFirstChild(lane)
	if gate and gate:IsA("BasePart") then
		gate.Transparency = value
	end
end

local function blinkLoop(map, lane, count, token)
	local interval = math.clamp(1.0 - 0.08 * count, 0.25, 1.0)
	local gates = map:FindFirstChild("Gates")
	local gate = gates and gates:FindFirstChild(lane)
	while token == generation do
		if gate == nil or gate.Parent == nil then
			return
		end
		gate.Transparency = 0.7
		task.wait(interval)
		if token ~= generation then
			break
		end
		if gate.Parent == nil then
			return
		end
		gate.Transparency = 0
		task.wait(interval)
	end
end

-- 대기 시작: lanes(성문별 적 수)에 따라 깜빡임을 시작한다.
function GateHighlight.start(map, lanes)
	GateHighlight.stop(map)
	local token = generation
	for lane, count in pairs(lanes) do
		if count > 0 then
			task.spawn(blinkLoop, map, lane, count, token)
		end
	end
end

-- 웨이브 시작: 깜빡임을 멈추고 모든 성문을 원래대로 되돌린다.
function GateHighlight.stop(map)
	generation += 1
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		setGateTransparency(map, lane, 0)
	end
end

return GateHighlight
