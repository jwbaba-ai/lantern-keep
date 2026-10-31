-- NPC 대사 결정 (단일 기준: docs/tasks/day5.md 5단계).
-- 이름 치환은 필터를 거친 뒤에만 일어난다. 게임 서비스에 닿지 않는
-- 순수 함수라서 spec에서 모델·DataStore 없이 검사한다.
local NpcSpeech = {}

-- "P1" 등을 DisplayName으로 바꾼다. names: { P1 = "이름", ... }.
-- names에 없는 토큰은 그대로 둔다.
function NpcSpeech.substituteNames(text, names)
	return (string.gsub(text, "P(%d+)", function(num)
		local name = names["P" .. num]
		if name ~= nil then
			return name
		end
		return "P" .. num
	end))
end

-- 쓸 대사를 고른다.
-- line: 저장된 AI 대사(없으면 nil = 첫 판). defaultLine: Config 기본 대사.
-- filterFn(text): 필터된 문자열을 돌려준다. 에러를 던지면 실패로 친다.
-- names: 슬롯 → DisplayName. partySize: 현재 파티 인원.
-- 필터 실패·기억 없음·해당 플레이어가 없음 중 하나라도 해당하면
-- 기본 대사를 쓰고, AI 대사일 때만 isAI=true를 돌려준다.
-- 뜻 모를 숫자 안전망: Day·웨이브·P번호를 지운 뒤 숫자가 남으면 true다.
-- 저장된 옛 AI 대사에서 damage 같은 요약 숫자를 그대로 말하는 경우를 걸러낸다.
function NpcSpeech.hasStrayNumber(text)
	if type(text) ~= "string" then
		return false
	end
	local s = text
	s = string.gsub(s, "Day%s*%d+", "")
	s = string.gsub(s, "%d+%s*웨이브", "")
	s = string.gsub(s, "웨이브%s*%d+", "")
	s = string.gsub(s, "P%d+", "")
	return string.find(s, "%d") ~= nil
end

function NpcSpeech.resolveLine(line, defaultLine, filterFn, names, partySize)
	if type(line) ~= "string" or line == "" then
		return defaultLine, false
	end
	if NpcSpeech.hasStrayNumber(line) then
		return defaultLine, false
	end
	for num in string.gmatch(line, "P(%d+)") do
		local n = tonumber(num)
		if n == nil or n < 1 or n > (partySize or 0) then
			return defaultLine, false
		end
		if names["P" .. num] == nil then
			return defaultLine, false
		end
	end
	local ok, filtered = pcall(filterFn, line)
	if not ok or type(filtered) ~= "string" or filtered == "" then
		return defaultLine, false
	end
	return NpcSpeech.substituteNames(filtered, names), true
end

-- Day 번호 안전망. 대사에 "Day 숫자"가 있는데 그 숫자가 지금 판 Day와
-- 다르면 true다. 요약 시점(끝난 판)의 Day를 쓴 대사를 다음 판 시작 때
-- 걸러내 기본 대사로 바꾸기 위한 것이다. Day 언급이 없으면 false다.
function NpcSpeech.dayMismatch(text, currentDay)
	if type(text) ~= "string" or type(currentDay) ~= "number" then
		return false
	end
	for num in string.gmatch(text, "Day%s*(%d+)") do
		if tonumber(num) ~= currentDay then
			return true
		end
	end
	return false
end

return NpcSpeech
