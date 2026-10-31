-- 공격 성문 강조 (단일 기준: docs/tasks/day4.md 3단계).
-- 다음 웨이브가 정해지면 대기 시간 동안 적이 오는 성문을 깜빡인다.
-- 적 수가 많을수록 빠르게 깜빡인다. 웨이브가 시작되면 원래대로 되돌린다.
-- 맵 파트 이름·구조는 MapBuilder가 만든 것을 그대로 쓴다 (Map/Gates/<lane>).
local GateHighlight = {}

-- 성문 기본 투명도 (색이 비치는 철창문). 깜빡임이 꺼지면 이 값으로 돌아간다.
GateHighlight.BASE_TRANSPARENCY = 0.8

local generation = 0

local function setGateTransparency(map, lane, value)
	local gates = map:FindFirstChild("Gates")
	local gate = gates and gates:FindFirstChild(lane)
	if gate and gate:IsA("BasePart") then
		gate.Transparency = value
	end
end

local function blinkLoop(map, lane, count, token, isFirst)
	-- 첫 출발 성문은 더 빠르고 밝게 깜빡여 순서가 보이게 한다.
	local interval = math.clamp(1.0 - 0.08 * count, 0.25, 1.0)
	if isFirst then
		interval = math.max(0.25, interval * 0.7)
	end
	local onTransparency = isFirst and 0.1 or 0.35
	local gates = map:FindFirstChild("Gates")
	local gate = gates and gates:FindFirstChild(lane)
	while token == generation do
		if gate == nil or gate.Parent == nil then
			return
		end
		gate.Transparency = onTransparency
		task.wait(interval)
		if token ~= generation then
			break
		end
		if gate.Parent == nil then
			return
		end
		gate.Transparency = GateHighlight.BASE_TRANSPARENCY
		task.wait(interval)
	end
end

-- 대기 시작: lanes(성문별 적 수)에 따라 깜빡임을 시작한다.
-- firstLane(첫 출발 성문)이 있으면 그 성문을 가장 밝게 깜빡인다.
-- 없으면 기존처럼 적 수에 따라서만 깜빡인다.
function GateHighlight.start(map, lanes, firstLane)
	GateHighlight.stop(map)
	local token = generation
	for lane, count in pairs(lanes) do
		if count > 0 then
			task.spawn(blinkLoop, map, lane, count, token, lane == firstLane)
		end
	end
end

-- 웨이브 시작: 깜빡임을 멈추고 모든 성문을 원래대로 되돌린다.
function GateHighlight.stop(map)
	generation += 1
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		setGateTransparency(map, lane, GateHighlight.BASE_TRANSPARENCY)
	end
end

return GateHighlight
