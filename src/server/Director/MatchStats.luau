-- 웨이브 통계를 모아 디렉터 요청용 경기 요약(MatchStats)을 만든다.
-- 요약 형태는 fixtures/match_summaries/*.json과 같은 필드 구조다.
-- 플레이어 정보는 3일차 전투가 들어오기 전까지 빈 배열이다.
-- breached_lane 정의(2일차): 처음으로 등불에 도달한 적의 레인. 없으면 빈 문자열.
local MatchStats = {}

function MatchStats.new()
	return {
		spawned = 0,
		arrived = 0,
		killed = 0,
		firstBreach = "",
		revives = 0,
	}
end

function MatchStats.recordSpawn(tracker, _lane)
	tracker.spawned += 1
end

function MatchStats.recordResolved(tracker, lane, how)
	if how == "arrived" then
		tracker.arrived += 1
		if tracker.firstBreach == "" then
			tracker.firstBreach = lane
		end
	else
		tracker.killed += 1
	end
end

-- waveNumber: 막 끝난 웨이브 번호. previousWave: { tactic, event }.
function MatchStats.buildSummary(tracker, waveNumber, lanternHealthPct, previousWave)
	return {
		wave = waveNumber,
		lantern_health_pct = lanternHealthPct,
		breached_lane = tracker.firstBreach,
		revives = tracker.revives,
		players = {},
		previous_wave = {
			tactic = previousWave.tactic,
			event = previousWave.event,
		},
	}
end

return MatchStats
