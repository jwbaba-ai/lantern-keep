-- 파티 기억 저장·요약 (단일 기준: docs/tasks/day5.md 4단계).
-- DataStore 이름은 NpcMemory_v1, 키는 파티 userId 오름차순 결합(party_<id1>_<id2>)이다.
-- 저장 값: { events(최근 10개 경기 기록 요약), bram_memory, mira_memory,
--   bram_lines, mira_lines, updated_at }. 오래된 것부터 버린다.
-- 이 모듈은 require 때 게임 서비스에 닿지 않는다. DataStore 접근은
-- load·save·getStore·finishAndSave 안에서만 일어나고, spec은 순수 함수만 쓴다.
local MatchRecord = require(script.Parent:WaitForChild("MatchRecord"))

local MemoryStore = {
	STORE_NAME = "NpcMemory_v1",
	MAX_EVENTS = 10,
}

-- userIds 배열 → "party_<id1>_<id2>" (오름차순).
function MemoryStore.partyKey(userIds)
	local sorted = {}
	for _, id in ipairs(userIds or {}) do
		table.insert(sorted, id)
	end
	table.sort(sorted)
	local parts = {}
	for _, id in ipairs(sorted) do
		table.insert(parts, tostring(id))
	end
	return "party_" .. table.concat(parts, "_")
end

-- 모델 응답 검증: 줄 수는 각 3개, 각 줄 1~80자,
-- P 토큰은 이번 파티 인원 안에서만 허용한다.
function MemoryStore.validate(data, partySize)
	if type(data) ~= "table" then
		return false, { "응답이 object가 아니다" }
	end
	local errors = {}
	for _, key in ipairs({ "bram_lines", "mira_lines" }) do
		local lines = data[key]
		if type(lines) ~= "table" or #lines ~= 3 then
			table.insert(errors, key .. "는 3줄이어야 한다")
		else
			for i, line in ipairs(lines) do
				local len = type(line) == "string" and utf8.len(line) or nil
				if len == nil or len < 1 or len > 80 then
					table.insert(errors, key .. "[" .. i .. "]는 1~80자여야 한다")
				end
			end
		end
	end
	for _, key in ipairs({ "bram_memory", "mira_memory" }) do
		if type(data[key]) ~= "string" or data[key] == "" then
			table.insert(errors, key .. "가 비었다")
		end
	end
	local texts = {}
	if type(data.bram_memory) == "string" then
		table.insert(texts, data.bram_memory)
	end
	if type(data.mira_memory) == "string" then
		table.insert(texts, data.mira_memory)
	end
	for _, lines in ipairs({ data.bram_lines, data.mira_lines }) do
		if type(lines) == "table" then
			for _, line in ipairs(lines) do
				if type(line) == "string" then
					table.insert(texts, line)
				end
			end
		end
	end
	for _, text in ipairs(texts) do
		for num in string.gmatch(text, "P(%d+)") do
			local n = tonumber(num)
			if n == nil or n < 1 or n > (partySize or 0) then
				table.insert(errors, "P" .. num .. "는 이 파티(" .. tostring(partySize) .. "인)에 없다")
				break
			end
		end
	end
	if #errors > 0 then
		return false, errors
	end
	return true, {}
end

-- events에 새 사건을 추가하고 10개로 유지한다(오래된 것부터 버린다).
function MemoryStore.pushEvent(saved, event)
	saved.events = saved.events or {}
	table.insert(saved.events, event)
	while #saved.events > MemoryStore.MAX_EVENTS do
		table.remove(saved.events, 1)
	end
	return saved
end

function MemoryStore.getStore()
	return game:GetService("DataStoreService"):GetDataStore(MemoryStore.STORE_NAME)
end

function MemoryStore.load(store, key)
	local ok, saved = pcall(function()
		return store:GetAsync(key)
	end)
	if ok then
		return saved
	end
	warn("[Npc] 기억 불러오기 실패: " .. tostring(saved))
	return nil
end

function MemoryStore.save(store, key, saved)
	local ok, err = pcall(function()
		store:UpdateAsync(key, function()
			return saved
		end)
	end)
	if not ok then
		warn("[Npc] 기억 저장 실패: " .. tostring(err))
		return false
	end
	return true
end

-- 경기 종료 처리.
-- 1. 이번 경기 기록(event)을 events에 추가한다.
-- 2. summarizeFn(previous, events)로 Muse Spark를 1회 호출한다.
--    previous는 { bram_memory, mira_memory }(첫 판이면 둘 다 ""임).
-- 3. 검증 실패하면 이전 기억과 대사를 유지한다.
-- 돌려값: saved, source("muse"|"fallback").
function MemoryStore.finishMatch(saved, event, partySize, summarizeFn)
	saved = saved or {}
	MemoryStore.pushEvent(saved, event)
	local source = "fallback"
	-- 기억이 없는 첫 판에도 previous는 빈 문자열 테이블로 보낸다 ([] 아님).
	local ok, res = pcall(summarizeFn, {
		bram_memory = saved.bram_memory or "",
		mira_memory = saved.mira_memory or "",
	}, saved.events)
	if ok and res ~= nil then
		local valid, errs = MemoryStore.validate(res, partySize)
		if valid then
			saved.bram_memory = res.bram_memory
			saved.mira_memory = res.mira_memory
			saved.bram_lines = res.bram_lines
			saved.mira_lines = res.mira_lines
			source = "muse"
		else
			warn("[Npc] 요약 검증 실패, 이전 기억 유지: " .. table.concat(errs, " / "))
		end
	end
	saved.updated_at = os.time()
	return saved, source
end

-- 경기 기록(record)을 확정하고 파티 기억에 반영한다: 불러오기 → 추가·요약 → 저장.
-- summarizeFn(previous, events) → 응답 테이블(없으면 nil).
-- DataStore 열기 실패는 에러를 던지므로 호출한 쪽이 pcall로 감싼다.
-- day·totalWaves: 이번 판의 Day 번호와 웨이브 수. 기록 event에 함께 저장한다.
-- supportSquad: 이번 판 지원대 유형("solo"|"coop"|"none"). 기록 event에 함께 저장한다.
-- 돌려값: saved, source("muse"|"fallback"),
--   npcMemory("ai"|"summary_failed"|"save_failed", 결과 화면·다음 판 대사 상태).
--   요약·검증 실패면 "summary_failed", 요약은 됐는데 저장이 실패하면 "save_failed",
--   둘 다 되면 "ai"다.
-- DirectorService(실제 경기 종료)와 NpcDebug(가짜 기록)가 같은 함수를 쓴다.
function MemoryStore.finishAndSave(record, result, wavesCompleted, userIds, summarizeFn, day, totalWaves, supportSquad)
	MatchRecord.finish(record, result, wavesCompleted, day, totalWaves, supportSquad)
	local partySize = #(userIds or {})
	local key = MemoryStore.partyKey(userIds)
	local store = MemoryStore.getStore()
	local saved = MemoryStore.load(store, key) or {}
	local newSaved, source = MemoryStore.finishMatch(
		saved,
		MatchRecord.toEvent(record),
		partySize,
		summarizeFn
	)
	local saveOk = MemoryStore.save(store, key, newSaved)
	print(string.format("[Npc] summarize source=%s party_size=%d", source, partySize))
	print(string.format("[Npc] saved events=%d", #newSaved.events))
	local npcMemory
	if source ~= "muse" then
		npcMemory = "summary_failed"
	elseif not saveOk then
		npcMemory = "save_failed"
	else
		npcMemory = "ai"
	end
	return newSaved, source, npcMemory
end

return MemoryStore
