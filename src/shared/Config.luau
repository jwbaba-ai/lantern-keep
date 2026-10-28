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
	MatchStartWaitSeconds = 20, -- 웨이브 1 전 로비 대기 상한(초). 지나도 0명이면 자동 테스트로 진행
	LanternMaxHealth = 100,
	MinEnemies = 4,
	MaxEnemies = 30,
	BloodMoonMinWave = 6,

	-- Party scaling (day4 0-1.5): 검증 통과 뒤 적용 직전에 적 수·체력을 줄인다.
	PartyCountScale = { 0.5, 0.7, 0.85, 1.0 }, -- 1~4인 적 수 배율 (올림, 최소 1)
	PartyHealthScale = { 0.6, 0.8, 0.9, 1.0 }, -- 1~4인 적 체력 배율
	FogEndDuringEvent = 120, -- fog 이벤트 중 Lighting.FogEnd

	Lanes = { "north", "south", "east", "west" },
	EnemyTypes = { "Grunt", "Runner", "Brute", "Archer", "Shaman" },
	Tactics = { "focus_weak_lane", "split_push", "flank", "siege" },
	Events = { "none", "fog", "elite_spawn", "reinforcement_delay", "blood_moon" },
}
