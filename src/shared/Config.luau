-- 게임 전체 설정값 (단일 기준). 키는 여기에 넣지 않습니다.
return {
	ApiUrl = "https://api.meta.ai/v1/chat/completions",
	SecretName = "meta_api_key", -- Creator Dashboard > Secrets (도메인 api.meta.ai)
	DirectorModel = "muse-spark-1.3",
	ReasoningEffort = "low",
	MaxCompletionTokens = 2000,
	RequestTimeoutSeconds = 20,
	MinEnemies = 4,
	MaxEnemies = 30,
}
