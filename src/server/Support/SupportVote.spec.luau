-- SupportVote 다수결 확인 (단일 기준: docs/tasks/day8b-support.md 2단계).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Support["SupportVote.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다. 시드를 고정한 Random.new(1)을 쓴다.
local SupportFolder = script.Parent
local SupportVote = require(SupportFolder:WaitForChild("SupportVote"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[SupportVote.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

-- 1. 2:1 → 다수 선택.
do
	local res = SupportVote.tally({ "coop", "coop", "solo" }, Random.new(1))
	check(
		"majority_wins",
		res.choice == "coop" and res.tie == false and res.counts.coop == 2 and res.counts.solo == 1
	)
end

-- 2. 1:1 → tie=true, 결과가 동률 선택지 중 하나, 같은 시드면 같은 결과.
do
	local a = SupportVote.tally({ "solo", "coop" }, Random.new(1))
	local b = SupportVote.tally({ "solo", "coop" }, Random.new(1))
	local inTie = a.choice == "solo" or a.choice == "coop"
	check("tie_break_from_tied", a.tie == true and inTie and #a.tied == 2 and a.choice == b.choice)
end

-- 3. 표 없음 → none.
do
	local res = SupportVote.tally({}, Random.new(1))
	check("no_votes_none", res.choice == "none" and res.tie == false)
end

-- 4. none 2표 : coop 1표 → none.
do
	local res = SupportVote.tally({ "none", "none", "coop" }, Random.new(1))
	check("none_majority_wins", res.choice == "none" and res.tie == false and res.counts.none == 2)
end

-- 5. 1인(투표 1표) → 그 표.
do
	local res = SupportVote.tally({ "solo" }, Random.new(1))
	check("single_vote_wins", res.choice == "solo" and res.tie == false)
end

return results
