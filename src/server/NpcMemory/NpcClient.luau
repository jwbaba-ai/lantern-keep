-- 경기 뒤 기억 요약을 Muse Spark에 1회 요청한다. 실패하면 nil을 돌려주고,
-- 호출한 쪽이 기억 요약 없이 사건만 저장하고 다음 판은 기본 대사로 진행한다.
-- 모델·Secret·URL은 Config 기존 키를 재사용하고,
-- 응답 형식은 NpcMemorySchema(strict)다. userId와 이름은 보내지 않는다.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NpcMemorySchema = require(Shared:WaitForChild("NpcMemorySchema"))
local PROMPT = script.Parent:WaitForChild("prompt").Value

local NpcClient = {}

-- 게임 Config는 그대로 쓰고, 요약에만 넉넉한 지역 상수를 둔다.
local NPC_REASONING_EFFORT = "minimal"
local NPC_MAX_COMPLETION_TOKENS = 4000
local NPC_TIMEOUT_SECONDS = 40

-- previous: { bram_memory, mira_memory } (첫 판이면 비어 있음).
-- events: 최근 경기 사건 배열(MatchRecord.toEvent 결과).
function NpcClient.summarize(previous, events)
	local started = os.clock()
	local statusCode = nil
	local finishReason = nil
	local ok, result = pcall(function()
		local auth = HttpService:GetSecret(Config.SecretName):AddPrefix("Bearer ")
		local payload = {
			model = Config.DirectorModel,
			reasoning_effort = NPC_REASONING_EFFORT,
			max_completion_tokens = NPC_MAX_COMPLETION_TOKENS,
			messages = {
				{ role = "system", content = PROMPT },
				{ role = "user", content = HttpService:JSONEncode({ previous = previous, events = events }) },
			},
			response_format = {
				type = "json_schema",
				json_schema = { name = "npc_memory", strict = true, schema = NpcMemorySchema },
			},
		}
		local res = HttpService:RequestAsync({
			Url = Config.ApiUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json", ["Authorization"] = auth },
			Body = HttpService:JSONEncode(payload),
			Timeout = NPC_TIMEOUT_SECONDS,
		})
		statusCode = res.StatusCode
		assert(res.Success, "HTTP " .. tostring(res.StatusCode))
		local body = HttpService:JSONDecode(res.Body)
		local choice = body.choices[1]
		finishReason = choice.finish_reason
		return HttpService:JSONDecode(choice.message.content)
	end)
	local elapsed = os.clock() - started
	if ok then
		print(string.format("[Npc] summarize ok %.1fs", elapsed))
		return result
	end
	warn(string.format(
		"[Npc] 요약 요청 실패(status=%s finish=%s %.1fs), 사건만 저장: %s",
		tostring(statusCode),
		tostring(finishReason),
		elapsed,
		tostring(result)
	))
	return nil
end

return NpcClient
