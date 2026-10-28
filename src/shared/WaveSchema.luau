-- 자동 생성 파일: 직접 고치지 말고 schemas/wave_plan.schema.json 수정 후
-- python tools/gen_schema_luau.py 를 실행하세요.
return {
	["type"] = "object",
	["additionalProperties"] = false,
	["required"] = { "wave_name", "enemies", "tactic", "event", "director_note" },
	["properties"] = {
		["wave_name"] = {
			["type"] = "string",
			["description"] = "Short dramatic wave name shown to players",
		},
		["enemies"] = {
			["type"] = "array",
			["items"] = {
				["type"] = "object",
				["additionalProperties"] = false,
				["required"] = { "type", "count", "lane" },
				["properties"] = {
					["type"] = {
						["type"] = "string",
						["enum"] = { "Grunt", "Runner", "Brute", "Archer", "Shaman" },
					},
					["count"] = {
						["type"] = "integer",
					},
					["lane"] = {
						["type"] = "string",
						["enum"] = { "north", "south", "east", "west" },
					},
				},
			},
		},
		["tactic"] = {
			["type"] = "string",
			["enum"] = { "focus_weak_lane", "split_push", "flank", "siege" },
		},
		["event"] = {
			["type"] = "string",
			["enum"] = { "none", "fog", "elite_spawn", "reinforcement_delay", "blood_moon" },
		},
		["director_note"] = {
			["type"] = "string",
			["description"] = "One short sentence a player could read, explaining the twist",
		},
	},
}
