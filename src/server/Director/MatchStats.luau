-- 웨이브 통계를 모아 디렉터 요청용 경기 요약(MatchStats)을 만든다.
-- 요약 형태는 fixtures/match_summaries/*.json과 같은 필드 구조다
-- (wave, lantern_health_pct, breached_lane, revives, players, previous_wave).
-- players에는 { role, damage, deaths }를 실제 값으로 채운다.
-- breached_lane 정의(3일차): 그 웨이브에서 등불에 가장 많이 도달한 레인.
-- 없으면 nil이다 (JSON으로 보내면 키가 빠지며, 디렉터에게는 null과 같다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MatchStats = {}

function MatchStats.new()
	return {
		spawned = 0,
		arrived = 0,
		killed = 0,
		breaches = {}, -- [lane] = 등불에 도달한 수
		revives = 0,
		damage = {}, -- [userId] = 그 웨이브에 준 피해 합
		deaths = {}, -- [userId] = 그 웨이브 사망 수
		roles = {}, -- [userId] = 기록 시점의 직업
	}
end

function MatchStats.recordSpawn(tracker, _lane)
	tracker.spawned += 1
end

function MatchStats.recordResolved(tracker, lane, how)
	if how == "arrived" then
		tracker.arrived += 1
		tracker.breaches[lane] = (tracker.breaches[lane] or 0) + 1
	else
		tracker.killed += 1
	end
end

-- 공격자가 준 피해를 기록한다 (처치 여부와 무관하게 준 만큼 쌓는다).
function MatchStats.recordDamage(tracker, player, amount)
	local id = player.UserId
	tracker.damage[id] = (tracker.damage[id] or 0) + amount
	tracker.roles[id] = tracker.roles[id] or player:GetAttribute("Class")
end

function MatchStats.recordDeath(tracker, player)
	local id = player.UserId
	tracker.deaths[id] = (tracker.deaths[id] or 0) + 1
	tracker.roles[id] = tracker.roles[id] or player:GetAttribute("Class")
end

function MatchStats.recordRevive(tracker)
	tracker.revives += 1
end

-- roster: { { userId, role } } — 가만히 있던 플레이어도 요약에 넣기 위한 명단.
-- waveNumber: 막 끝난 웨이브 번호. previousWave: { tactic, event }.
function MatchStats.buildSummary(tracker, waveNumber, lanternHealthPct, previousWave, roster)
	local breachedLane = nil
	local best = 0
	for _, lane in ipairs(Config.Lanes) do
		local n = tracker.breaches[lane] or 0
		if n > best then
			breachedLane = lane
			best = n
		end
	end

	local seen = {}
	local players = {}
	local function addPlayer(userId, role)
		if seen[userId] or role == nil then
			return
		end
		seen[userId] = true
		table.insert(players, {
			role = role,
			damage = tracker.damage[userId] or 0,
			deaths = tracker.deaths[userId] or 0,
		})
	end
	for userId, role in pairs(tracker.roles) do
		addPlayer(userId, role)
	end
	if roster then
		for _, entry in ipairs(roster) do
			addPlayer(entry.userId, entry.role)
		end
	end
	table.sort(players, function(a, b)
		return a.role < b.role
	end)

	return {
		wave = waveNumber,
		lantern_health_pct = lanternHealthPct,
		breached_lane = breachedLane,
		revives = tracker.revives,
		players = players,
		previous_wave = {
			tactic = previousWave.tactic,
			event = previousWave.event,
		},
	}
end

return MatchStats
