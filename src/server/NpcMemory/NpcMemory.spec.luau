-- NPC 기억·대사 검사 (단일 기준: docs/tasks/day5.md 6단계).
-- 실행법(Studio 명령줄): require(game.ServerScriptService.Server.NpcMemory["NpcMemory.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다. 모델·DataStore 없이 실행된다.
local NpcFolder = script.Parent
local MatchRecord = require(NpcFolder:WaitForChild("MatchRecord"))
local MemoryStore = require(NpcFolder:WaitForChild("MemoryStore"))
local NpcSpeech = require(NpcFolder:WaitForChild("NpcSpeech"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[NpcMemory.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

-- 1. 파티 키 정렬: userId 오름차순 결합.
do
	check("party_key_sorted", MemoryStore.partyKey({ 9, 3, 7 }) == "party_3_7_9")
end

-- 2. MatchRecord 슬롯: userId 오름차순으로 P1부터.
do
	local record = MatchRecord.new({ 50, 10 })
	check("slots_by_userid_order", record.slots[10] == "P1" and record.slots[50] == "P2")
end

-- 3. events 10개 상한: 12개를 넣으면 10개 남고 오래된 2개가 버려진다.
do
	local saved = { events = {} }
	for i = 1, 12 do
		MemoryStore.pushEvent(saved, { waves_completed = i })
	end
	check(
		"events_cap_10",
		#saved.events == 10
			and saved.events[1].waves_completed == 3
			and saved.events[10].waves_completed == 12
	)
end

local function goodResponse()
	return {
		bram_memory = "P1이 북문을 지켰다.",
		mira_memory = "P2가 두 번 살렸다.",
		bram_lines = { "등불 곁에 서라.", "첫 고비는 넘겼다.", "버텨라." },
		mira_lines = { "함께 싸워요!", "무사해서 다행이에요.", "조금만 더 힘내요!" },
	}
end

-- 4. 검증기: 정상 통과.
do
	local ok, _ = MemoryStore.validate(goodResponse(), 2)
	check("validate_ok", ok == true)
end

-- 5. 검증기: 줄 수 틀림 거부.
do
	local res = goodResponse()
	res.bram_lines = { "한 줄", "두 줄" }
	local ok, _ = MemoryStore.validate(res, 2)
	check("validate_wrong_count_rejected", ok == false)
end

-- 6. 검증기: 80자 초과 거부.
do
	local res = goodResponse()
	res.mira_lines[1] = string.rep("가", 81)
	local ok, _ = MemoryStore.validate(res, 2)
	check("validate_too_long_rejected", ok == false)
end

-- 7. 검증기: 없는 P 토큰 거부 (2인 파티에 P3).
do
	local res = goodResponse()
	res.bram_lines[1] = "P3이 북문을 지켰다."
	local ok, _ = MemoryStore.validate(res, 2)
	check("validate_bad_ptoken_rejected", ok == false)
end

-- 8. 필터 실패 시 기본 대사.
do
	local failingFilter = function(_text)
		error("no filter available")
	end
	local text, isAI =
		NpcSpeech.resolveLine("P1이 잘 싸웠다.", "기본 대사", failingFilter, { P1 = "Bob" }, 1)
	check("filter_failure_uses_default", text == "기본 대사" and isAI == false)
end

-- 9. 이름 치환이 필터 뒤에 일어남: 필터가 받은 원문에는 P1이 그대로 있고,
-- 결과에는 DisplayName이 들어간다.
do
	local seen = nil
	local spyFilter = function(text)
		seen = text
		return text
	end
	local text, isAI =
		NpcSpeech.resolveLine("P1이 북문을 지켰다.", "기본 대사", spyFilter, { P1 = "Bob" }, 1)
	check(
		"substitute_after_filter",
		seen == "P1이 북문을 지켰다." and text == "Bob이 북문을 지켰다." and isAI == true
	)
end

-- 10. 요약 실패 시 이전 기억 유지 + 사건은 저장.
do
	local saved = { events = {}, bram_memory = "옛 기억", bram_lines = { "a", "b", "c" } }
	local failingSummarize = function(_previous, _events)
		error("no model")
	end
	local out, source = MemoryStore.finishMatch(saved, { result = "defeat" }, 2, failingSummarize)
	check(
		"fallback_keeps_memory",
		source == "fallback" and out.bram_memory == "옛 기억" and #out.events == 1
	)
end

-- 11. 중간 입장자는 슬롯이 없고, 키는 시작 명단 기준.
do
	local record = MatchRecord.new({ 10, 20 })
	MatchRecord.recordWave(
		record,
		{ wave = 1, breached_lane = "north", lantern_health_pct = 90, revives = 0 },
		{
			{ userId = 10, role = "guardian", damage = 100, deaths = 0, revives_given = 0 },
			{ userId = 30, role = "ranger", damage = 50, deaths = 0, revives_given = 0 },
		}
	)
	check(
		"late_joiner_no_slot",
		record.slots[30] == nil
			and record.players[30] == nil
			and record.slots[10] == "P1"
			and MemoryStore.partyKey({ 10, 20 }) == "party_10_20"
	)
end

-- 12. event next_day: 승리 Day 1 → 2, 패배 Day 3 → 3.
do
	local win = MatchRecord.new({ 10, 20 })
	MatchRecord.finish(win, "victory", 3, 1, 3, "none")
	local lose = MatchRecord.new({ 10, 20 })
	MatchRecord.finish(lose, "defeat", 1, 3, 7, "coop")
	check(
		"event_next_day",
		MatchRecord.toEvent(win).next_day == 2 and MatchRecord.toEvent(lose).next_day == 3
	)
end

-- 13. 현재 Day 2, 대사 "Day 1을 지켜내자" → 기본 대사(안전망 동작).
do
	local mismatch = NpcSpeech.dayMismatch("다시 Day 1을 지켜내자!", 2)
	local line, isAI = "다시 Day 1을 지켜내자!", true
	if mismatch then
		line, isAI = "기본 대사", false
	end
	check("day_mismatch_uses_default", mismatch == true and line == "기본 대사" and isAI == false)
end

-- 14. 현재 Day 2, 대사 "Day 2도 함께" → AI 대사 그대로.
do
	local mismatch = NpcSpeech.dayMismatch("Day 2도 함께 싸워요!", 2)
	check("day_match_keeps_ai", mismatch == false)
end

return results
