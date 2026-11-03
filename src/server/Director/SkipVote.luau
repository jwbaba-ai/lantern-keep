-- 대기 건너뛰기 동의 규칙 (순수 함수, 단일 기준: docs/tasks/day14g.md 1단계).
-- 사람 플레이어 수에 따른 필요한 동의 수. 지원대 봇은 세지 않는다.
local SkipVote = {}

-- 0명 → 0, 1명 → 1, 2명 → 2, 3명 → 2, 4명 → 3.
-- 일반식: n <= 2면 n, 아니면 math.ceil(n * 2 / 3).
function SkipVote.needed(playerCount)
	if playerCount <= 0 then
		return 0
	end
	if playerCount <= 2 then
		return playerCount
	end
	return math.ceil(playerCount * 2 / 3)
end

-- 사람 1명 이상이고 동의 수가 needed 이상이면 true.
function SkipVote.passed(voteCount, playerCount)
	if playerCount < 1 then
		return false
	end
	return voteCount >= SkipVote.needed(playerCount)
end

return SkipVote
