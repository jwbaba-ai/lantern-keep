-- 외형 장식 공용 헬퍼 (단일 기준: docs/tasks/day11c.md 공통 규칙).
-- 외부 에셋 금지: Part + WeldConstraint만 쓴다.
-- 판정에 쓰는 파트는 그대로 하나다: 장식은 몸체의 자식으로 넣고,
-- 충돌·쿼리·접촉을 끄고 질량을 없애 판정에 끼지 않게 한다.
local Figures = {}

-- 몸체에 붙는 장식 파트 1개를 만든다.
-- opts: Name, Size, CFrame(월드 기준), BrickColor/Color, Material,
--   Shape(Enum.PartType, 기본 Block), Transparency(기본 0).
function Figures.attach(body, opts)
	local p = Instance.new("Part")
	p.Name = opts.Name or "Decor"
	p.Size = opts.Size
	p.CFrame = opts.CFrame or body.CFrame
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Shape = opts.Shape or Enum.PartType.Block
	if opts.Color then
		p.Color = opts.Color
	elseif opts.BrickColor then
		p.BrickColor = opts.BrickColor
	end
	if opts.Material then
		p.Material = opts.Material
	end
	if opts.Transparency then
		p.Transparency = opts.Transparency
	end
	p.Parent = body
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- 몸체 위치에서 목표를 바라보는 CFrame (수평만 본다).
-- 목표와 XZ가 같으면(길이 0) 지금 방향을 유지한다.
function Figures.faceFlatCFrame(fromPos, fromLook, targetPos)
	local flat = Vector3.new(targetPos.X - fromPos.X, 0, targetPos.Z - fromPos.Z)
	if flat.Magnitude < 0.001 then
		flat = Vector3.new(fromLook.X, 0, fromLook.Z)
		if flat.Magnitude < 0.001 then
			flat = Vector3.new(0, 0, -1)
		end
	end
	local leveled = Vector3.new(fromPos.X, fromPos.Y, fromPos.Z)
	return CFrame.lookAt(leveled, leveled + flat)
end

return Figures
