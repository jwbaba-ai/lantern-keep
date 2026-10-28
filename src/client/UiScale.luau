-- 휴대폰 화면 공용 배율 (단일 기준: docs/tasks/day7.md 1-1단계).
-- 화면 짧은 변을 기준으로 배율을 돌려준다:
-- 배율 = math.clamp(짧은 변 / 720, 0.55, 1).
-- iPhone 가로 화면(약 844x390)에서는 짧은 변 390 → 0.55가 된다.
local Workspace = game:GetService("Workspace")

local UiScale = {}

-- 지금 화면의 배율. 카메라가 아직 없으면 1(PC 기본 크기)이다.
function UiScale.factor()
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local size = camera.ViewportSize
	local short = math.min(size.X, size.Y)
	return math.clamp(short / 720, 0.55, 1)
end

-- 화면 크기(회전 포함)가 바뀔 때마다 callback(새 배율)을 부른다.
-- 처음에도 한 번 불러 호출한 쪽이 초기값을 잡게 한다.
function UiScale.watch(callback)
	local function hook(camera)
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			callback(UiScale.factor())
		end)
	end
	local camera = Workspace.CurrentCamera
	if camera then
		hook(camera)
		callback(UiScale.factor())
	else
		local conn = nil
		conn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			local now = Workspace.CurrentCamera
			if now then
				conn:Disconnect()
				hook(now)
				callback(UiScale.factor())
			end
		end)
		callback(1)
	end
end

return UiScale
