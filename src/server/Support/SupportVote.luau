-- 지원대 투표 다수결 (단일 기준: docs/tasks/day8b-support.md 2단계).
-- 선택지는 solo, coop, none(요청 안 함) 셋이다. 고르지 않은 사람은 표를 세지 않는다.
-- 이 모듈은 순수 함수만 둔다. 투표 보관·알림은 SupportService가 맡는다.
local SupportVote = {
	CHOICES = { "solo", "coop", "none" },
}

local function isChoice(value)
	return value == "solo" or value == "coop" or value == "none"
end

-- votes: 선택지 문자열 배열. 잘못된 값은 무시한다.
-- rng: Random. 동률이면 동률인 선택지 중에서 하나를 뽑는다.
-- 돌려값: { choice, counts, tie, tied, reason }.
-- 가장 많은 표를 받은 선택지가 결과다. 표가 하나도 없으면 none이다.
function SupportVote.tally(votes, rng)
	local counts = { solo = 0, coop = 0, none = 0 }
	local total = 0
	for _, vote in ipairs(votes or {}) do
		if isChoice(vote) then
			counts[vote] += 1
			total += 1
		end
	end
	if total == 0 then
		return { choice = "none", counts = counts, tie = false, tied = {}, reason = "no_votes" }
	end
	local best = 0
	for _, choice in ipairs(SupportVote.CHOICES) do
		if counts[choice] > best then
			best = counts[choice]
		end
	end
	local tied = {}
	for _, choice in ipairs(SupportVote.CHOICES) do
		if counts[choice] == best then
			table.insert(tied, choice)
		end
	end
	if #tied == 1 then
		return { choice = tied[1], counts = counts, tie = false, tied = {}, reason = "majority" }
	end
	local pick = rng:NextInteger(1, #tied)
	return { choice = tied[pick], counts = counts, tie = true, tied = tied, reason = "tie_break" }
end

return SupportVote
