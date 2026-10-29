-- 지원대 투표 서비스 (단일 기준: docs/tasks/day8b-support.md 3단계).
-- 로비에서 플레이어의 지원대 선택을 받는다. 지원대는 모델을 호출하지 않는다.
-- RemoteEvent Remotes/SupportVote(인자: 문자열 solo|coop|none).
-- 서버는 phase == "lobby"일 때만 받고, 세 선택지 중 하나만 받는다.
-- 0.5초 안의 연속 입력은 무시한다. 플레이어가 나가면 그 표를 지운다.
-- 이전 판에 낸 표는 다음 로비에 그대로 남는다. 처음 들어온 플레이어는 표가 없다.
-- 상태는 ReplicatedStorage.SupportState(JSON)로 알린다:
-- { votes = { { name = DisplayName, choice } }, counts, result, tie, tied }.
-- 로비가 끝나는 집계·알림·생성은 SupportSquad.finalizeLobby가 맡는다
-- (DirectorService가 로비 종료 시점에 동기 호출한다).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VOTE_DEBOUNCE = 0.5 -- 같은 플레이어의 연속 입력 무시 간격(초)

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local voteEvent = remotes:FindFirstChild("SupportVote")
if not voteEvent then
	voteEvent = Instance.new("RemoteEvent")
	voteEvent.Name = "SupportVote"
	voteEvent.Parent = remotes
end

local state = ReplicatedStorage:FindFirstChild("SupportState")
if not state then
	state = Instance.new("StringValue")
	state.Name = "SupportState"
	state.Parent = ReplicatedStorage
end

local function isChoice(value)
	return value == "solo" or value == "coop" or value == "none"
end

-- votes: [userId] = { choice, name = DisplayName }.
-- DisplayName은 화면 표시용이다. 저장하거나 모델에 보내지 않는다.
local votes = {}
local lastVoteAt = {} -- [userId] = os.clock()
local lobbyPhase = false

local function publish()
	local list = {}
	local counts = { solo = 0, coop = 0, none = 0 }
	for userId, vote in pairs(votes) do
		if isChoice(vote.choice) then
			counts[vote.choice] += 1
			table.insert(list, { name = vote.name, choice = vote.choice, userId = userId })
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	local shown = {}
	for _, entry in ipairs(list) do
		table.insert(shown, { name = entry.name, choice = entry.choice })
	end
	-- 집계 결과(result·tie·tied·announce)는 finalizeLobby가 같은 값에 덧붙인다.
	-- 여기서는 표 목록·개수만 갱신하고 집계 필드는 그대로 둔다.
	local ok, current = pcall(HttpService.JSONDecode, HttpService, state.Value)
	local data
	if ok and type(current) == "table" then
		data = current
	else
		data = { result = "none", tie = false, tied = {}, announce = "", announce_until = 0 }
	end
	data.votes = shown
	data.counts = counts
	local okEncode, json = pcall(HttpService.JSONEncode, HttpService, data)
	if okEncode then
		state.Value = json
	end
end

-- 새 로비가 시작되면 집계 표시만 지운다. 표는 그대로 남는다.
local function resetTally()
	local ok, current = pcall(HttpService.JSONDecode, HttpService, state.Value)
	local data
	if ok and type(current) == "table" then
		data = current
	else
		data = {}
	end
	data.result = "none"
	data.tie = false
	data.tied = {}
	data.announce = ""
	data.announce_until = 0
	local okEncode, json = pcall(HttpService.JSONEncode, HttpService, data)
	if okEncode then
		state.Value = json
	end
	publish()
end

voteEvent.OnServerEvent:Connect(function(player, choice)
	if not lobbyPhase then
		return
	end
	if not isChoice(choice) then
		return
	end
	local now = os.clock()
	local last = lastVoteAt[player.UserId]
	if last and now - last < VOTE_DEBOUNCE then
		return
	end
	lastVoteAt[player.UserId] = now
	votes[player.UserId] = { choice = choice, name = player.DisplayName }
	publish()
end)

Players.PlayerRemoving:Connect(function(player)
	votes[player.UserId] = nil
	lastVoteAt[player.UserId] = nil
	publish()
end)

-- 로비 단계 추적: DirectorService가 쓰는 DirectorState를 읽는다.
local directorState = ReplicatedStorage:WaitForChild("DirectorState")
local function onDirectorState()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, directorState.Value)
	if not ok or type(data) ~= "table" then
		return
	end
	local inLobby = data.phase == "lobby"
	if inLobby and not lobbyPhase then
		lobbyPhase = true
		resetTally()
	elseif not inLobby then
		lobbyPhase = false
	end
end
directorState.Changed:Connect(onDirectorState)
if directorState.Value ~= "" then
	onDirectorState()
else
	lobbyPhase = true
end
publish()
