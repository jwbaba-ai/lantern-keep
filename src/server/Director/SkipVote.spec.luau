-- SkipVote 동의 규칙 확인 (단일 기준: docs/tasks/day14g.md 1단계).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Director["SkipVote.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다.
local DirectorFolder = script.Parent
local SkipVote = require(DirectorFolder:WaitForChild("SkipVote"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[SkipVote.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

-- 인원별 needed: 0→0, 1→1, 2→2, 3→2, 4→3.
do
	local got = {
		SkipVote.needed(0),
		SkipVote.needed(1),
		SkipVote.needed(2),
		SkipVote.needed(3),
		SkipVote.needed(4),
	}
	check(
		"needed_by_count",
		got[1] == 0 and got[2] == 1 and got[3] == 2 and got[4] == 2 and got[5] == 3
	)
end

-- 1명 1표 통과.
do
	check("solo_passes", SkipVote.passed(1, 1) == true)
end

-- 2명 1표 불통과.
do
	check("duo_one_fails", SkipVote.passed(1, 2) == false)
end

-- 3명 2표 통과.
do
	check("trio_two_passes", SkipVote.passed(2, 3) == true)
end

-- 4명 2표 불통과.
do
	check("quad_two_fails", SkipVote.passed(2, 4) == false)
end

-- 0명 불통과.
do
	check("empty_fails", SkipVote.passed(0, 0) == false)
end

return results
