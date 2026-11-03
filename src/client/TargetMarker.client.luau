-- 조준 대상 표시 (단일 기준: docs/tasks/day14c-fix.md 4단계).
-- 직업 Tool을 들고 있을 때 0.1초마다 AutoTarget.pick(aim은 mouse.Hit.Position)으로
-- 고른 적 하나에 클라이언트 전용 Highlight(외곽선 노란색, 속 비움, 가려지면 숨김)를 붙인다.
-- 대상이 바뀌면 옮기고, 없거나 Tool을 내리면 지운다. Highlight는 하나만 만든다.
-- 후보는 살아 있는 적(Health > 0)만 쓴다. 효과 코드가 실패해도 전투는 멈추지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AutoTarget = require(Shared:WaitForChild("AutoTarget"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local gui = Instance.new("ScreenGui")
gui.Name = "TargetMarker"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local mark = Instance.new("Highlight")
mark.Name = "Target"
mark.FillTransparency = 1
mark.OutlineColor = Color3.fromRGB(255, 220, 60)
mark.OutlineTransparency = 0
mark.DepthMode = Enum.HighlightDepthMode.Occluded
mark.Enabled = false
mark.Parent = gui

local function clearMark()
	pcall(function()
		mark.Enabled = false
		mark.Adornee = nil
	end)
end

task.spawn(function()
	while true do
		task.wait(0.1)
		local ok = pcall(function()
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local tool = character and character:FindFirstChildOfClass("Tool")
			local classKey = player:GetAttribute("Class")
			if hrp == nil or tool == nil or not tool:GetAttribute("ClassTool") or classKey == nil then
				mark.Enabled = false
				mark.Adornee = nil
				return
			end
			local list = {}
			local folder = Workspace:FindFirstChild("Enemies")
			if folder then
				for _, body in ipairs(folder:GetChildren()) do
					if body:IsA("BasePart") and (body:GetAttribute("Health") or 0) > 0 then
						table.insert(list, { pos = body.Position, ref = body })
					end
				end
			end
			local picked = AutoTarget.pick(classKey, hrp.Position, mouse.Hit.Position, list)
			local target = picked and picked.ref or nil
			if target == nil or target.Parent == nil then
				mark.Enabled = false
				mark.Adornee = nil
			else
				mark.Adornee = target
				mark.Enabled = true
			end
		end)
		if not ok then
			clearMark()
		end
	end
end)
