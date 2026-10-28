-- 게임 전체 설정값 (단일 기준). 키는 여기에 넣지 않습니다.
return {
	-- Director (Muse Spark)
	ApiUrl = "https://api.meta.ai/v1/chat/completions",
	SecretName = "meta_api_key", -- Creator Dashboard > Secrets (도메인 api.meta.ai) / Studio: Local Secrets
	DirectorModel = "muse-spark-1.3",
	ReasoningEffort = "low",
	MaxCompletionTokens = 2000,
	RequestTimeoutSeconds = 15,

	-- Match
	AutoKillWhenNoPlayers = true, -- 플레이어가 없으면(자동 테스트) 체력 비례 타이머로 적 처치
	TotalWaves = 7,
	IntermissionSeconds = 20,
	LanternMaxHealth = 100,
	MinEnemies = 4,
	MaxEnemies = 30,
	BloodMoonMinWave = 6,

	Lanes = { "north", "south", "east", "west" },
	EnemyTypes = { "Grunt", "Runner", "Brute", "Archer", "Shaman" },
	Tactics = { "focus_weak_lane", "split_push", "flank", "siege" },
	Events = { "none", "fog", "elite_spawn", "reinforcement_delay", "blood_moon" },
}
