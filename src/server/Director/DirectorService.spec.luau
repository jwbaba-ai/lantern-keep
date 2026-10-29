-- DirectorService 웨이브 완료 수 규칙 검사 (단일 기준: docs/tasks/day8f-fix.md 1번).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.Director["DirectorService.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다. 모델 없이 실행된다.
-- DirectorService.server.luau는 Script라 require할 수 없어서,
-- 이 spec은 같은 규칙(completedAfterWave 진리표)을 고정한다.
-- 구현을 바꾸면 여기와 본 파일을 함께 고친다.
local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[DirectorService.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

-- 본 파일과 같은 규칙: 등불이 꺼졌으면 이전 값 유지, 아니면 이번 웨이브.
local function completedAfterWave(completed, wave, lanternHp)
	if lanternHp <= 0 then
		return completed
	end
	return wave
end

-- 1. 웨이브 3 진행 후 등불 0 → 완료 2, 등불 > 0 → 완료 3.
do
	local defeat = completedAfterWave(2, 3, 0)
	local victory = completedAfterWave(2, 3, 80)
	check(
		"defeat_wave_not_counted",
		defeat == 2 and victory == 3
	)
end

return results
