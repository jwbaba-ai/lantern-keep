-- NPC 동료 등장·대사 (단일 기준: docs/tasks/day5.md 5단계).
-- 등불 근처에 Bram(노장 대장)과 Mira(견습 치유사)를 만든다(전투 불참).
-- 저장된 *_lines[1..3]을 순서대로 말한다: 웨이브 1 시작 직전(인사),
-- 웨이브 1 종료 후 대기, 웨이브 3 종료 후 대기.
-- 표시 전에 각 줄을 필터하고, 그다음 P1 등을 DisplayName으로 바꾼다.
-- 필터 실패·기억 없음(첫 판)·해당 플레이어 없음이면 Config 기본 대사를 쓴다.
-- 경기 시작 시 기억을 불러오지 못해도(DataStore 실패) 경기는 그대로 시작한다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local NpcFolder = script.Parent
local MemoryStore = require(NpcFolder:WaitForChild("MemoryStore"))
local NpcSpeech = require(NpcFolder:WaitForChild("NpcSpeech"))

local NPCS = {
	{ key = "bram", title = "Bram · 노장 대장", offset = Vector3.new(8, 0, 6), color = "Medium stone grey" },
	{ key = "mira", title = "Mira · 견습 치유사", offset = Vector3.new(-8, 0, 6), color = "White" },
}
local LINES_KEY = { bram = "bram_lines", mira = "mira_lines" }

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local npcSayEvent = remotes:FindFirstChild("NpcSay")
if not npcSayEvent then
	npcSayEvent = Instance.new("RemoteEvent")
	npcSayEvent.Name = "NpcSay"
	npcSayEvent.Parent = remotes
end

-- 맵이 준비될 때까지 기다렸다가 등불 근처에 NPC 몸통과 이름표를 만든다.
local map = Workspace:WaitForChild("Map")
while map:GetAttribute("Ready") ~= true do
	task.wait(0.5)
end
local lantern = map:WaitForChild("Lantern")
local npcsFolder = map:FindFirstChild("Npcs")
if not npcsFolder then
	npcsFolder = Instance.new("Folder")
	npcsFolder.Name = "Npcs"
	npcsFolder.Parent = map
end
for _, npc in ipairs(NPCS) do
	local name = npc.key == "bram" and "Bram" or "Mira"
	if not npcsFolder:FindFirstChild(name) then
		local body = Instance.new("Part")
		body.Name = name
		body.Size = Vector3.new(2, 5, 2)
		body.Position = lantern.Position + npc.offset - Vector3.new(0, 7.5, 0)
		body.Anchored = true
		body.CanCollide = false
		body.BrickColor = BrickColor.new(npc.color)
		body.Parent = npcsFolder
		local tag = Instance.new("BillboardGui")
		tag.Name = "Nameplate"
		tag.Adornee = body
		tag.Size = UDim2.new(0, 200, 0, 40)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		tag.Parent = body
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = npc.title
		label.Parent = tag
	end
end

-- 이번 판 명단(로비 종료 시점 스냅샷, userId 오름차순)과 불러온 기억 캐시.
-- 중간에 들어온 플레이어는 명단에 넣지 않는다.
local matchIds = {}
local savedCache = nil
local matchLoaded = false

local function loadForMatch()
	local ids = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(ids, player.UserId)
	end
	table.sort(ids)
	matchIds = ids
	savedCache = nil
	local storeOk, store = pcall(MemoryStore.getStore)
	if storeOk and store ~= nil then
		savedCache = MemoryStore.load(store, MemoryStore.partyKey(matchIds))
	end
	local eventCount = 0
	if savedCache and savedCache.events then
		eventCount = #savedCache.events
	end
	local hasLines = savedCache and savedCache.bram_lines ~= nil and savedCache.mira_lines ~= nil
	-- 대사 원문은 찍지 않는다.
	print(string.format("[Npc] loaded events=%d lines=%s", eventCount, hasLines and "ai" or "default"))
end

local function ensureLoaded()
	if not matchLoaded then
		matchLoaded = true
		loadForMatch()
	end
end

-- 시작 명단의 슬롯 → DisplayName. 슬롯은 userId 오름차순으로 P1부터.
local function slotNames()
	local names = {}
	for i, id in ipairs(matchIds) do
		local player = Players:GetPlayerByUserId(id)
		if player then
			names["P" .. i] = player.DisplayName
		end
	end
	return names, #matchIds
end

local function filterLine(text)
	local players = Players:GetPlayers()
	assert(#players > 0, "no players for filter")
	local filtered = TextService:FilterStringAsync(text, players[1].UserId)
	return filtered:GetNonChatStringForBroadcastAsync()
end

local function say(npcKey, lineIndex)
	ensureLoaded()
	local names, partySize = slotNames()
	local defaults = Config.NpcDefaultLines and Config.NpcDefaultLines[npcKey]
	local defaultLine = (defaults and defaults[lineIndex]) or "..."
	local saved = savedCache
	local lines = saved and saved[LINES_KEY[npcKey]]
	local text, isAI = NpcSpeech.resolveLine(
		lines and lines[lineIndex] or nil,
		defaultLine,
		filterLine,
		names,
		partySize
	)
	npcSayEvent:FireAllClients({ npc = npcKey, text = text, isAI = isAI })
end

local saidGreeting, saidAfterWave1, saidAfterWave3 = false, false, false
local state = ReplicatedStorage:WaitForChild("DirectorState")
local function onState()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, state.Value)
	if not ok or type(data) ~= "table" then
		return
	end
	if data.phase == "wave" and data.display_wave == 1 and not saidGreeting then
		saidGreeting = true
		say("bram", 1)
		say("mira", 1)
	elseif data.phase == "intermission" and data.display_wave == 2 and not saidAfterWave1 then
		saidAfterWave1 = true
		say("bram", 2)
		say("mira", 2)
	elseif data.phase == "intermission" and data.display_wave == 4 and not saidAfterWave3 then
		saidAfterWave3 = true
		say("bram", 3)
		say("mira", 3)
	end
end
state.Changed:Connect(onState)
-- 스크립트가 늦게 시작됐으면 이미 설정된 상태를 한 번 확인한다.
if state.Value ~= "" then
	onState()
end
