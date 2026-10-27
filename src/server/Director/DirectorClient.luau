-- Muse Spark에 다음 웨이브를 요청하는 모듈. 실패하면 nil을 돌려주고, 호출한 쪽이 대체 웨이브를 쓴다.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WaveSchema = require(Shared:WaitForChild("WaveSchema"))
local PROMPT = script.Parent:WaitForChild("prompt").Value

local DirectorClient = {}

function DirectorClient.requestNextWave(matchSummary)
	local ok, result = pcall(function()
		local auth = HttpService:GetSecret(Config.SecretName):AddPrefix("Bearer ")
		local payload = {
			model = Config.DirectorModel,
			reasoning_effort = Config.ReasoningEffort,
			max_completion_tokens = Config.MaxCompletionTokens,
			messages = {
				{ role = "system", content = PROMPT },
				{ role = "user", content = HttpService:JSONEncode(matchSummary) },
			},
			response_format = {
				type = "json_schema",
				json_schema = { name = "wave_plan", strict = true, schema = WaveSchema },
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
	warn("[Director] 요청 실패, 대체 웨이브 사용: " .. tostring(result))
	return nil
end

return DirectorClient
