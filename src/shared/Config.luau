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
	TotalWaves = 10, -- Day별 웨이브 수의 최댓값(= FallbackWaves 개수). 한 판의 웨이브 수로는 더 이상 쓰지 않는다
	-- Day 단계 (day8): 짧게 시작해서 점점 길고 강하게. Day 6 이상은 DayWaveCounts 마지막 값(10)을 쓴다.
	DayWaveCounts = { 3, 5, 7, 9, 10 }, -- Day 1~5의 웨이브 수
	BossFromDay = 5, -- 이 Day부터 마지막 웨이브에 보스가 나온다
	DayScaleFromDay = 6, -- 이 Day부터 적 체력·수가 늘어난다
	DayHealthStep = 0.15, -- Day당 적 체력 증가분 (상한 DayHealthMax)
	DayCountStep = 0.10, -- Day당 적 수 증가분 (상한 DayCountMax)
	DayHealthMax = 2.5, -- 적 체력 배율 상한
	DayCountMax = 1.6, -- 적 수 배율 상한
	IntermissionSeconds = 20,
	MatchStartWaitSeconds = 20, -- 웨이브 1 전 로비 대기 상한(초). 지나도 0명이면 자동 테스트로 진행
	MatchRestartSeconds = 15, -- 결과 화면을 보여 주는 시간(초). 기억 저장이 더 오래 걸리면 그만큼 더 기다린다
	LanternMaxHealth = 100,
	MinEnemies = 4,
	MaxEnemies = 30,
	BloodMoonMinWave = 6,

	-- Party scaling (day4 0-1.5): 검증 통과 뒤 적용 직전에 적 수·체력을 줄인다.
	PartyCountScale = { 0.5, 0.7, 0.85, 1.0 }, -- 1~4인 적 수 배율 (올림, 최소 1)
	PartyHealthScale = { 0.6, 0.8, 0.9, 1.0 }, -- 1~4인 적 체력 배율
	FogEndDuringEvent = 120, -- fog 이벤트 중 Lighting.FogEnd

	-- NPC (day5): 기억 없음·필터 실패·해당 플레이어 없음 때 쓰는 기본 대사 (AI 고지 없음).
	NpcDefaultLines = {
		bram = {
			"등불 곁에 서라. 이번에도 막아낸다.",
			"첫 고비는 넘겼다. 방심은 금물이다.",
			"마지막 고비다. 버텨라.",
		},
		mira = {
			"오늘도 함께 싸워요! 다치지 마세요!",
			"첫 웨이브 끝! 모두 무사해서 다행이에요.",
			"조금만 더 힘내요! 제가 곁에 있을게요.",
		},
	},

	Lanes = { "north", "south", "east", "west" },
	EnemyTypes = { "Grunt", "Runner", "Brute", "Archer", "Shaman" },
	Tactics = { "focus_weak_lane", "split_push", "flank", "siege" },
	Events = { "none", "fog", "elite_spawn", "reinforcement_delay", "blood_moon" },
}
