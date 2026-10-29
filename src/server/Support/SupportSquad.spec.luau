-- SupportSquad 인원·역할 확인 (단일 기준: docs/tasks/day8b-support.md 6단계).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Support["SupportSquad.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다. 모델 없이 실행된다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local SupportFolder = script.Parent
local SupportSquad = require(SupportFolder:WaitForChild("SupportSquad"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[SupportSquad.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

-- 1. 사람 0~4명일 때 지원대 수 4,3,2,1,0.
do
	local got = {}
	for humans = 0, 4 do
		table.insert(got, SupportSquad.botCount(humans))
	end
	check(
		"bot_counts_0_to_4",
		got[1] == 4 and got[2] == 3 and got[3] == 2 and got[4] == 1 and got[5] == 0
	)
end

-- 2. 역할 순서가 Config와 같은지 (solo).
do
	local roles = SupportSquad.rolesFor("solo", 4)
	local want = Config.SupportSquads.solo.roles
	local same = #roles == #want
	for i, role in ipairs(roles) do
		if role ~= want[i] then
			same = false
		end
	end
	check("solo_roles_match_config", same)
end

-- 3. 역할 순서가 Config와 같은지 (coop).
do
	local roles = SupportSquad.rolesFor("coop", 4)
	local want = Config.SupportSquads.coop.roles
	local same = #roles == #want
	for i, role in ipairs(roles) do
		if role ~= want[i] then
			same = false
		end
	end
	check("coop_roles_match_config", same)
end

-- 4. partySize 상한 4.
do
	check(
		"party_size_capped",
		SupportSquad.partySize(4, 4) == 4
			and SupportSquad.partySize(0, 4) == 4
			and SupportSquad.partySize(1, 1) == 2
	)
end

return results
