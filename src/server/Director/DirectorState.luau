-- 화면·세계에 보낼 웨이브 상태 (단일 기준: docs/tasks/day4.md 1단계).
-- ReplicatedStorage.DirectorState(JSON)에 기존 wave·source·plan을 유지하고
-- phase·display_wave·display_name·display_note·lanes·intermission_ends_at를 더한다.
-- AI 글자(wave_name, director_note)는 서버에서 TextService 필터를 거친 뒤에만
-- 담는다. 클라이언트는 원문을 받지 않는다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FallbackWaves = require(Shared:WaitForChild("FallbackWaves"))

local DirectorState = {
	-- 디렉터 응답 전 대기 중에 보여 주는 고정 문구 (필터 불필요).
	DESIGNING_TEXT = "디렉터가 다음 웨이브를 설계하는 중…",
}

-- plan.enemies를 성문별 적 수로 합친다.
function DirectorState.lanesOf(plan)
	local lanes = { north = 0, south = 0, east = 0, west = 0 }
	for _, e in ipairs(plan.enemies) do
		if lanes[e.lane] ~= nil then
			lanes[e.lane] += e.count
		end
	end
	return lanes
end

-- 성문별 출발 순서 (순수 함수, day9 성문별 시간 차).
-- 성문 순서는 적 수 내림차순, 동점이면 Config.Lanes 순이다.
-- i번째 성문은 (i-1) x 간격초 뒤에 출발한다.
-- 간격은 plan.tactic이 split_push면 splitStagger, 아니면 laneStagger다.
-- 돌려값: { { lane, count, start_at } } 배열 (적 0인 성문 제외).
function DirectorState.laneStartTimes(plan, laneStagger, splitStagger)
	local counts = DirectorState.lanesOf(plan)
	local ordered = {}
	local laneIndex = {}
	for i, lane in ipairs(Config.Lanes) do
		laneIndex[lane] = i
		if counts[lane] > 0 then
			table.insert(ordered, lane)
		end
	end
	table.sort(ordered, function(a, b)
		if counts[a] ~= counts[b] then
			return counts[a] > counts[b]
		end
		return laneIndex[a] < laneIndex[b]
	end)
	local gap = laneStagger
	if type(plan) == "table" and plan.tactic == "split_push" then
		gap = splitStagger
	end
	local out = {}
	for i, lane in ipairs(ordered) do
		table.insert(out, { lane = lane, count = counts[lane], start_at = (i - 1) * gap })
	end
	return out
end

-- 필터가 없을 때 쓸 같은 웨이브 번호의 FallbackWaves 글자.
function DirectorState.fallbackName(waveNumber)
	local fb = FallbackWaves[waveNumber]
	return fb and fb.wave_name or ""
end

function DirectorState.fallbackNote(waveNumber)
	local fb = FallbackWaves[waveNumber]
	return fb and fb.director_note or ""
end

-- 실제 TextService 필터. 실패하면 에러를 던지고, 호출한 쪽이 대체 글자를 쓴다.
local function realFilter(text)
	local players = Players:GetPlayers()
	assert(#players > 0, "no players for filter")
	local filtered = TextService:FilterStringAsync(text, players[1].UserId)
	return filtered:GetNonChatStringForBroadcastAsync()
end

-- text를 필터하고, 플레이어가 없거나 실패하면 fallback을 돌려준다.
-- filterFn은 테스트 주입용 (nil이면 실제 필터를 쓴다).
function DirectorState.filterOrFallback(text, fallback, filterFn)
	local filter = filterFn or realFilter
	local ok, out = pcall(filter, text)
	if ok and type(out) == "string" and out ~= "" then
		return out
	end
	return fallback
end

-- 화면용 상태 테이블을 만든다.
-- args: phase("wave"|"intermission"|"lobby"|"result"), displayWave, source,
--   plan(설계 중이면 nil), waveName·directorNote(설계 중이면 nil → 고정 문구),
--   intermissionEndsAt, filterFn(테스트용),
--   day(이번 판 Day 번호), totalWaves(이번 판 웨이브 수), boss(보스 웨이브면 true).
--   phase가 "result"면 고정 문구만 쓴다(필터 불필요):
--   result("victory"|"defeat"), wavesCompleted, lanternHealthPct를 함께 담는다.
function DirectorState.buildState(args)
	local day = args.day or 1
	local totalWaves = args.totalWaves or Config.TotalWaves
	local displayName, displayNote
	if args.phase == "result" then
		if args.result == "victory" then
			displayName = string.format("Day %d 승리!", day)
			displayNote = string.format(
				"%d웨이브 모두 막아냄 · 등불 체력 %d%%",
				totalWaves,
				args.lanternHealthPct or 0
			)
		else
			displayName = "등불이 꺼졌다…"
			displayNote = string.format(
				"%d웨이브 중 %d웨이브 생존",
				totalWaves,
				args.wavesCompleted or 0
			)
		end
	elseif args.phase == "lobby" then
		-- 로비 고정 문구는 서버 코드에 적힌 글자라 필터 없이 그대로 쓴다.
		-- 로비 시작 시점에는 플레이어가 0명이라 필터가 항상 실패한다.
		displayName = args.waveName or ""
		displayNote = args.directorNote or ""
	elseif args.waveName == nil then
		displayName = DirectorState.DESIGNING_TEXT
		displayNote = ""
	else
		displayName = DirectorState.filterOrFallback(
			args.waveName,
			DirectorState.fallbackName(args.displayWave),
			args.filterFn
		)
		displayNote = DirectorState.filterOrFallback(
			args.directorNote or "",
			DirectorState.fallbackNote(args.displayWave),
			args.filterFn
		)
	end
	local state = {
		wave = args.displayWave,
		source = args.source,
		phase = args.phase,
		display_wave = args.displayWave,
		display_name = displayName,
		display_note = displayNote,
		lanes = { north = 0, south = 0, east = 0, west = 0 },
		intermission_ends_at = args.intermissionEndsAt or 0,
		day = day,
		total_waves = totalWaves,
		boss = args.boss == true,
	}
	if args.phase == "result" then
		state.result = args.result
		state.waves_completed = args.wavesCompleted or 0
		state.lantern_health_pct = args.lanternHealthPct or 0
	end
	if args.plan ~= nil then
		state.plan = args.plan
		state.lanes = DirectorState.lanesOf(args.plan)
		-- 성문별 출발 순서·시각 (배너 셋째 줄·성문 강조가 같은 순서를 쓴다).
		state.lane_order = DirectorState.laneStartTimes(
			args.plan,
			Config.LaneStaggerSeconds or 8,
			Config.SplitPushStaggerSeconds or 3
		)
	end
	return state
end

-- 상태 JSON을 DirectorState 값에 쓰고 로그를 남긴다.
function DirectorState.publish(stateValue, args)
	local data = DirectorState.buildState(args)
	local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
	if ok then
		stateValue.Value = json
	end
	print(string.format(
		"[Director] state phase=%s wave=%d source=%s",
		data.phase,
		data.display_wave,
		data.source
	))
	return data
end

return DirectorState
