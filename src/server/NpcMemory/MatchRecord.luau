-- 경기 기록 누적 (단일 기준: docs/tasks/day5.md 3단계).
-- DirectorService가 웨이브마다 만드는 MatchStats 요약을 받아 쌓는다.
-- 웨이브별: wave, breached_lane, lantern_health_pct, revives.
-- 플레이어별 누적: { slot, role, damage, deaths, revives_given }.
-- P1~P4 슬롯은 로비 종료 시점 명단(userId 오름차순)으로 붙인다.
-- 중간에 들어온 플레이어는 슬롯이 없고 기록에 넣지 않는다.
-- 이름·userId는 toEvent에서 뺀다.
local MatchRecord = {}

-- userIds 배열로 새 기록을 시작하고 슬롯을 배정한다.
function MatchRecord.new(userIds)
	local sorted = {}
	for _, id in ipairs(userIds or {}) do
		table.insert(sorted, id)
	end
	table.sort(sorted)
	local record = { waves = {}, players = {}, slots = {}, result = nil, waves_completed = 0 }
	for i, id in ipairs(sorted) do
		local slot = "P" .. i
		record.slots[id] = slot
		record.players[id] = { slot = slot, role = nil, damage = 0, deaths = 0, revives_given = 0 }
	end
	return record
end

-- tracker에서 웨이브별 플레이어 실적을 뽑는다.
-- roster: { { userId, role } } — MatchStats.buildSummary에 넘긴 그 명단.
function MatchRecord.perPlayerFromTracker(tracker, roster)
	local out = {}
	for _, entry in ipairs(roster or {}) do
		local id = entry.userId
		local revivesBy = tracker.revivesBy or {}
		table.insert(out, {
			userId = id,
			role = entry.role or tracker.roles[id],
			damage = tracker.damage[id] or 0,
			deaths = tracker.deaths[id] or 0,
			revives_given = revivesBy[id] or 0,
		})
	end
	return out
end

-- summary: MatchStats.buildSummary 결과.
-- perPlayer: perPlayerFromTracker 결과.
function MatchRecord.recordWave(record, summary, perPlayer)
	table.insert(record.waves, {
		wave = summary.wave,
		breached_lane = summary.breached_lane,
		lantern_health_pct = summary.lantern_health_pct,
		revives = summary.revives,
	})
	for _, entry in ipairs(perPlayer or {}) do
		-- 시작 명단에 없는 userId(중간 입장자)는 기록하지 않는다.
		local agg = record.players[entry.userId]
		if agg ~= nil then
			agg.role = entry.role or agg.role
			agg.damage += (entry.damage or 0)
			agg.deaths += (entry.deaths or 0)
			agg.revives_given += (entry.revives_given or 0)
		end
	end
end

function MatchRecord.finish(record, result, wavesCompleted, day, totalWaves, supportSquad)
	record.result = result
	record.waves_completed = wavesCompleted
	record.day = day
	record.total_waves = totalWaves
	-- 지원대 유형. 지원대 개별 기록은 저장하지 않는다.
	record.support_squad = supportSquad or "none"
end

-- 모델·DataStore에 넣는 userId·이름 없는 사건 요약.
function MatchRecord.toEvent(record)
	local waves = {}
	for _, w in ipairs(record.waves) do
		table.insert(waves, {
			wave = w.wave,
			breached_lane = w.breached_lane,
			lantern_health_pct = w.lantern_health_pct,
			revives = w.revives,
		})
	end
	local players = {}
	for _, agg in pairs(record.players) do
		table.insert(players, {
			slot = agg.slot,
			role = agg.role,
			damage = agg.damage,
			deaths = agg.deaths,
			revives_given = agg.revives_given,
		})
	end
	table.sort(players, function(a, b)
		return a.slot < b.slot
	end)
	-- 대사는 끝난 판이 아니라 다음 판 시작 때 나온다. 모델이 다음 판 Day 번호를
	-- 쓰게 next_day를 같이 넘긴다. 승리면 day + 1, 패배면 day다.
	local day = record.day or 1
	local nextDay = day
	if record.result == "victory" then
		nextDay = day + 1
	end
	return {
		result = record.result,
		waves_completed = record.waves_completed,
		day = record.day,
		next_day = nextDay,
		total_waves = record.total_waves,
		support_squad = record.support_squad or "none",
		waves = waves,
		players = players,
	}
end

return MatchRecord
