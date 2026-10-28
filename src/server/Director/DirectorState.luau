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
--   intermissionEndsAt, filterFn(테스트용).
--   phase가 "result"면 고정 문구만 쓴다(필터 불필요):
--   result("victory"|"defeat"), wavesCompleted, lanternHealthPct를 함께 담는다.
function DirectorState.buildState(args)
	local displayName, displayNote
	if args.phase == "result" then
		if args.result == "victory" then
			displayName = "승리!"
		else
			displayName = "등불이 꺼졌다…"
		end
		displayNote = string.format(
			"%d웨이브 중 %d웨이브 생존 · 등불 체력 %d%%",
			Config.TotalWaves,
			args.wavesCompleted or 0,
			args.lanternHealthPct or 0
		)
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
	}
	if args.phase == "result" then
		state.result = args.result
		state.waves_completed = args.wavesCompleted or 0
		state.lantern_health_pct = args.lanternHealthPct or 0
	end
	if args.plan ~= nil then
		state.plan = args.plan
		state.lanes = DirectorState.lanesOf(args.plan)
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
