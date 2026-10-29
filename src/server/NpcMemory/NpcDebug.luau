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

-- 디버그: 다음 판의 Day를 n으로 정한다.
-- DirectorService가 다음 판 시작 때 읽고 한 번만 쓴다.
-- debugFastMatch()와 함께 쓰면 Day 5 보스를 빨리 볼 수 있다.
-- 실행법(Studio 명령줄):
--   require(game.ServerScriptService.Server.NpcMemory["NpcDebug"]).debugSetDay(5)
function NpcDebug.debugSetDay(n)
	assert(type(n) == "number" and n >= 1 and math.floor(n) == n, "debugSetDay: n은 1 이상의 정수")
	ReplicatedStorage:SetAttribute("DebugDay", n)
	print("[Npc] debugSetDay: 다음 판 Day=" .. n)
end

-- 디버그: 다음 로비의 투표 결과를 choice로 정한다.
-- 투표를 무시하고, 로그에 forced를 표시한다.
-- 사람이 0명이면 지원대 4명만으로 실제 전투를 진행한다.
-- 실행법(Studio 명령줄):
--   require(game.ServerScriptService.Server.NpcMemory["NpcDebug"]).debugSupport("coop")
function NpcDebug.debugSupport(choice)
	assert(choice == "solo" or choice == "coop" or choice == "none", "debugSupport: choice는 solo|coop|none")
	ReplicatedStorage:SetAttribute("DebugSupport", choice)
	print("[Npc] debugSupport: 다음 로비 투표 결과를 " .. choice .. "로 정한다 (forced)")
end

-- 디버그: 지원대별 역할·맡은 성문·피해·사망을 한 줄씩 출력한다.
-- 실행법(Studio 명령줄):
--   require(game.ServerScriptService.Server.NpcMemory["NpcDebug"]).debugSupportReport()
function NpcDebug.debugSupportReport()
	local SupportSquad = require(
		NpcFolder.Parent:WaitForChild("Support"):WaitForChild("SupportSquad")
	)
	local bots = SupportSquad.reportBots()
	print(string.format("[Support] report choice=%s bots=%d", SupportSquad.getChoice(), #bots))
	for _, bot in ipairs(bots) do
		print(string.format(
			"[Support] %s role=%s lane=%s damage=%d deaths=%d",
			bot.Name,
			bot.role,
			bot.lane or "-",
			bot.damage or 0,
			bot.deaths or 0
		))
	end
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
