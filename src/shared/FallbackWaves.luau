-- 고정 대체 웨이브 1~7 (웨이브 스키마와 같은 형태).
-- 웨이브 1은 항상 이것을 쓰며, 디렉터 호출 실패 시 해당 웨이브 번호 것을 쓴다.
-- 설계 메모: 테스트 처치(EnemyFactory, 체력 비례) 때문에 Brute만 등불까지 닿는다.
-- Brute 6마리 x 15 = 90 피해이므로 대체 웨이브만으로 돌면 등불이 10으로 7웨이브를 마친다.
-- blood_moon은 대체 웨이브에 넣지 않는다 (안전망은 쉬워야 하고, 연출은 디렉터 몫).
return {
	{
		wave_name = "First Embers",
		enemies = {
			{ type = "Grunt", count = 4, lane = "north" },
			{ type = "Grunt", count = 2, lane = "south" },
		},
		tactic = "focus_weak_lane",
		event = "none",
		director_note = "Hungry grunts probe the north gate to test the keep.",
	},
	{
		wave_name = "Hungry Ranks",
		enemies = {
			{ type = "Grunt", count = 4, lane = "north" },
			{ type = "Brute", count = 1, lane = "north" },
			{ type = "Grunt", count = 3, lane = "south" },
			{ type = "Runner", count = 2, lane = "east" },
		},
		tactic = "split_push",
		event = "none",
		director_note = "A brute leads the northern ranks while runners circle east.",
	},
	{
		wave_name = "Arrows in the Dark",
		enemies = {
			{ type = "Grunt", count = 4, lane = "north" },
			{ type = "Grunt", count = 2, lane = "south" },
			{ type = "Brute", count = 1, lane = "south" },
			{ type = "Archer", count = 3, lane = "east" },
			{ type = "Runner", count = 3, lane = "west" },
		},
		tactic = "focus_weak_lane",
		event = "fog",
		director_note = "Fog rolls in as archers take the eastern wall.",
	},
	{
		wave_name = "Hammer and Howl",
		enemies = {
			{ type = "Grunt", count = 5, lane = "north" },
			{ type = "Brute", count = 1, lane = "north" },
			{ type = "Runner", count = 4, lane = "south" },
			{ type = "Grunt", count = 3, lane = "east" },
			{ type = "Archer", count = 2, lane = "west" },
			{ type = "Shaman", count = 1, lane = "west" },
		},
		tactic = "siege",
		event = "reinforcement_delay",
		director_note = "A slow siege presses every gate in staggered ranks.",
	},
	{
		wave_name = "The Shaman's Tithe",
		enemies = {
			{ type = "Grunt", count = 5, lane = "north" },
			{ type = "Brute", count = 1, lane = "north" },
			{ type = "Runner", count = 5, lane = "south" },
			{ type = "Archer", count = 3, lane = "east" },
			{ type = "Shaman", count = 1, lane = "east" },
			{ type = "Grunt", count = 4, lane = "west" },
		},
		tactic = "flank",
		event = "elite_spawn",
		director_note = "An elite flanks the keep while a shaman chants behind arrows.",
	},
	{
		wave_name = "Ashen Tide",
		enemies = {
			{ type = "Grunt", count = 6, lane = "north" },
			{ type = "Brute", count = 1, lane = "north" },
			{ type = "Runner", count = 6, lane = "south" },
			{ type = "Archer", count = 4, lane = "east" },
			{ type = "Grunt", count = 4, lane = "west" },
			{ type = "Shaman", count = 1, lane = "west" },
		},
		tactic = "split_push",
		event = "elite_spawn",
		director_note = "An elite-led tide splits to drown every gate at once.",
	},
	{
		wave_name = "Last Night of the Keep",
		enemies = {
			{ type = "Grunt", count = 7, lane = "north" },
			{ type = "Brute", count = 1, lane = "north" },
			{ type = "Runner", count = 7, lane = "south" },
			{ type = "Archer", count = 4, lane = "east" },
			{ type = "Shaman", count = 1, lane = "east" },
			{ type = "Grunt", count = 6, lane = "west" },
		},
		tactic = "siege",
		event = "elite_spawn",
		director_note = "Everything the dark has left marches on the lantern.",
	},
}
