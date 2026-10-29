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

-- 5. 피해를 준 지원대(UserId 음수)는 tracker에 먼저 들어가도
-- roster의 support=true가 요약 players 항목에 남는다.
do
	local MatchStats = require(
		SupportFolder.Parent:WaitForChild("Director"):WaitForChild("MatchStats")
	)
	local tracker = MatchStats.new()
	MatchStats.recordDamage(tracker, { UserId = -1, role = "guardian" }, 50)
	local summary = MatchStats.buildSummary(tracker, 1, 100, {
		tactic = "focus_weak_lane",
		event = "none",
	}, {
		{ userId = -1, role = "guardian", support = true },
	}, 1, 3, "coop")
	local found = nil
	for _, entry in ipairs(summary.players) do
		if entry.role == "guardian" and entry.damage == 50 then
			found = entry
		end
	end
	check("support_flag_kept_for_damager", found ~= nil and found.support == true)
end

-- 6. 목표까지 거리 > 4 → 이동 중(방향 돌리기 안 함).
do
	check(
		"moving_when_far",
		SupportSquad.isMovingToGoal(Vector3.new(0, 3, 0), Vector3.new(10, 3, 0)) == true
	)
end

-- 7. 거리 ≤ 4 → 도착(경계 4 포함).
do
	check(
		"arrived_when_close",
		SupportSquad.isMovingToGoal(Vector3.new(0, 3, 0), Vector3.new(4, 3, 0)) == false
			and SupportSquad.isMovingToGoal(Vector3.new(1, 3, 1), Vector3.new(1, 3, 1)) == false
			and SupportSquad.isMovingToGoal(nil, Vector3.new(0, 3, 0)) == false
	)
end

-- 8. 직업 이름표가 한국어(고정 표).
do
	check(
		"role_ko_labels",
		SupportSquad.koreanRoleName("guardian") == "수호자"
			and SupportSquad.koreanRoleName("ranger") == "궁수"
			and SupportSquad.koreanRoleName("cleric") == "사제"
			and SupportSquad.koreanRoleName("arcanist") == "비전술사"
	)
end

-- 9. 인원 n명이면 생성 자리 n개가 서로 4스터드 이상.
-- 처음 생성 자리(spawnOffsets 1~4명)와 맡은 성문 쪽 자리(4성문) 모두 본다.
do
	local ok = true
	for n = 1, 4 do
		local slots = SupportSquad.spawnOffsets(n)
		if #slots ~= n then
			ok = false
		end
		for i = 1, #slots do
			for j = i + 1, #slots do
				if (slots[i] - slots[j]).Magnitude < 4 then
					ok = false
				end
			end
		end
	end
	local spots = {}
	for _, lane in ipairs({ "north", "south", "east", "west" }) do
		table.insert(spots, SupportSquad.laneSpawnOffset(lane))
	end
	for i = 1, #spots do
		for j = i + 1, #spots do
			if (spots[i] - spots[j]).Magnitude < 4 then
				ok = false
			end
		end
	end
	check("spawn_slots_separated", ok)
end

-- 10. 사거리 120(ranger)·80(arcanist) 직업 → 봇 사거리 45.
do
	check(
		"bot_range_capped",
		SupportSquad.BOT_RANGED_CAP == 45
			and SupportSquad.botRange("ranger") == 45
			and SupportSquad.botRange("arcanist") == 45
	)
end

-- 11. 맡은 성문 north, 적이 south에만 있음 → 대상 없음.
do
	local picked = SupportSquad.chooseTarget(
		Vector3.new(0, 3, -13),
		45,
		"north",
		Vector3.new(0, 10, 0),
		{
			{ pos = Vector3.new(28, 3, 18), lane = "south" },
			{ pos = Vector3.new(25, 3, -25), lane = "south" },
		}
	)
	check("lane_filter_no_target", picked == nil)
end

-- 12. 맡은 성문에 적이 없고 등불 10스터드 안에 적 있음 → 그 적.
do
	local near = { pos = Vector3.new(10, 3, 0), lane = "south" }
	local picked = SupportSquad.chooseTarget(
		Vector3.new(0, 3, -13),
		45,
		"north",
		Vector3.new(0, 10, 0),
		{ near }
	)
	check("lantern_defense_picks_close_enemy", picked == near)
end

return results
