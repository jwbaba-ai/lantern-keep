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
function NpcSpeech.resolveLine(line, defaultLine, filterFn, names, partySize)
	if type(line) ~= "string" or line == "" then
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

return NpcSpeech
