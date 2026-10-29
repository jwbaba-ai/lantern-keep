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
	return countDecor(decor)
end

return MapDecor
