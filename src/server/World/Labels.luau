-- 이름표 공용 모양 (단일 기준: docs/tasks/day12.md 3번).
-- NPC·지원대·적 이름표가 같은 함수를 쓴다. 외부 에셋 없음.
-- 크기 140x24(픽셀), 검정 배경(투명도 0.45, 둥근 모서리 6),
-- 흰색 GothamBold + 외곽선(0.3), TextScaled + 최대 18.
local Labels = {}

-- opts: text(표시 글자), maxDistance, alwaysOnTop,
--   offset(StudsOffsetWorldSpace, 기본 몸체 위 +4).
-- 돌려값: 만든 BillboardGui.
function Labels.attach(parent, adornee, opts)
	opts = opts or {}
	local tag = Instance.new("BillboardGui")
	tag.Name = "Nameplate"
	tag.Adornee = adornee
	tag.Size = UDim2.new(0, 140, 0, 24)
	tag.StudsOffsetWorldSpace = opts.offset or Vector3.new(0, 4, 0)
	tag.MaxDistance = opts.maxDistance or 60
	tag.AlwaysOnTop = opts.alwaysOnTop or false
	tag.Parent = parent
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 0.45
	bg.BorderSizePixel = 0
	bg.Parent = tag
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 1, -2)
	label.Position = UDim2.new(0, 4, 0, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Text = opts.text or ""
	label.Parent = bg
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 18
	cap.Parent = label
	return tag
end

return Labels
