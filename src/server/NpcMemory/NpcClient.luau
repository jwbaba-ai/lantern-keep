-- 경기 뒤 기억 요약을 Muse Spark에 1회 요청한다. 실패하면 nil을 돌려주고,
-- 호출한 쪽이 기억 요약 없이 사건만 저장하고 다음 판은 기본 대사로 진행한다.
-- 모델·Secret·타임아웃은 Config 기존 키를 재사용하고,
-- 응답 형식은 NpcMemorySchema(strict)다. userId와 이름은 보내지 않는다.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NpcMemorySchema = require(Shared:WaitForChild("NpcMemorySchema"))
local PROMPT = script.Parent:WaitForChild("prompt").Value

local NpcClient = {}

-- previous: { bram_memory, mira_memory } (첫 판이면 비어 있음).
-- events: 최근 경기 사건 배열(MatchRecord.toEvent 결과).
function NpcClient.summarize(previous, events)
	local ok, result = pcall(function()
		local auth = HttpService:GetSecret(Config.SecretName):AddPrefix("Bearer ")
		local payload = {
			model = Config.DirectorModel,
			reasoning_effort = Config.ReasoningEffort,
			max_completion_tokens = Config.MaxCompletionTokens,
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
			Timeout = Config.RequestTimeoutSeconds,
		})
		assert(res.Success, "HTTP " .. tostring(res.StatusCode))
		local body = HttpService:JSONDecode(res.Body)
		return HttpService:JSONDecode(body.choices[1].message.content)
	end)
	if ok then
		return result
	end
	warn("[Npc] 요약 요청 실패, 사건만 저장: " .. tostring(result))
	return nil
end

return NpcClient
