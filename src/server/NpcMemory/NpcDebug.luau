-- 디버그: 가짜 경기 기록으로 경기 종료 처리를 한 번 실행한다.
-- 7웨이브를 다 돌지 않고도 기억 저장 → 다음 판 대사를 확인하기 위한 것이다.
-- 실행법(Studio 명령줄):
--   require(game.ServerScriptService.Server.NpcMemory["NpcDebug"]).debugEndMatch()
-- 가짜 기록: 웨이브 3 북문 돌파, cleric 부활 2회, 패배.
-- 실제 경기 종료와 같은 MemoryStore.finishAndSave를 쓰므로 저장·요약·로그가 같다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcFolder = script.Parent
local MatchRecord = require(NpcFolder:WaitForChild("MatchRecord"))
local MemoryStore = require(NpcFolder:WaitForChild("MemoryStore"))
local NpcClient = require(NpcFolder:WaitForChild("NpcClient"))

local NpcDebug = {}

-- 디버그: 남은 웨이브를 건너뛰고 지금 판을 즉시 승리로 끝낸다.
-- 결과 화면 -> 기억 저장 -> 다음 판 시작을 빠르게 확인하기 위한 것이다.
-- 실제 경기 흐름 코드는 그대로 쓰고, "남은 웨이브 건너뛰기" 플래그만 둔다.
-- 실행법(Studio 명령줄):
--   require(game.ServerScriptService.Server.NpcMemory["NpcDebug"]).debugFastMatch()
function NpcDebug.debugFastMatch()
	ReplicatedStorage:SetAttribute("DebugFastMatch", true)
	print("[Npc] debugFastMatch: 남은 웨이브를 건너뛰고 승리로 끝낸다")
end

function NpcDebug.debugEndMatch()
	local userIds = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(userIds, player.UserId)
	end
	table.sort(userIds)
	if #userIds == 0 then
		userIds = { 101, 202 }
	end
	local record = MatchRecord.new(userIds)
	local perPlayer = {}
	for i, id in ipairs(userIds) do
		if #userIds == 1 then
			-- 혼자 테스트: cleric 부활 2회를 그 플레이어에 붙인다.
			perPlayer[i] =
				{ userId = id, role = "cleric", damage = 400, deaths = 0, revives_given = 2 }
		elseif i == 1 then
			perPlayer[i] =
				{ userId = id, role = "guardian", damage = 1500, deaths = 1, revives_given = 0 }
		elseif i == 2 then
			perPlayer[i] =
				{ userId = id, role = "cleric", damage = 400, deaths = 0, revives_given = 2 }
		else
			perPlayer[i] =
				{ userId = id, role = "ranger", damage = 800, deaths = 0, revives_given = 0 }
		end
	end
	MatchRecord.recordWave(
		record,
		{ wave = 3, breached_lane = "north", lantern_health_pct = 40, revives = 2 },
		perPlayer
	)
	local ok, err = pcall(function()
		MemoryStore.finishAndSave(record, "defeat", 3, userIds, function(previous, events)
			return NpcClient.summarize(previous, events)
		end, 1, 3)
	end)
	if not ok then
		warn("[Npc] debugEndMatch 실패: " .. tostring(err))
	end
end

return NpcDebug
