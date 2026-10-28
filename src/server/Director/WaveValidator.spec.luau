-- WaveValidator 예시 입력 5개와 기대 결과 (Studio에서 사람이 실행 확인용).
-- 실행법(Studio 명령줄): local V = require(경로.WaveValidator); local S = require(경로["WaveValidator.spec"]);
--   for _, c in ipairs(S) do local ok, clean, errs = V.validate(c.input, c.wave)
--     print(c.name, ok == c.expectOk and "PASS" or "FAIL", "errors=" .. #errs) end
--
-- | # | 입력 요약 | wave | 기대 ok | 기대 cleanPlan / errors |
-- |---|---|---|---|---|
-- | 1 | 정상 plan, 총합 12, event none | 3 | true | 그대로 통과, errors 0건 |
-- | 2 | 정상 plan + event blood_moon | 3 | true | event가 none으로 교체, errors 1건 |
-- | 3 | 총합 40 (최대 30 초과) | 5 | true | 비율 유지하며 총합 30으로 감량, errors 1건 |
-- | 4 | 총합 2 (최소 4 미만) | 2 | true | 비율 유지하며 총합 4로 증량, errors 1건 |
-- | 5 | type이 목록에 없음 ("Dragon") | 4 | false | cleanPlan nil, errors 1건(이상) |
return {
	{
		name = "case1_normal",
		wave = 3,
		expectOk = true,
		input = {
			wave_name = "Embers at the North Gate",
			enemies = {
				{ type = "Grunt", count = 5, lane = "north" },
				{ type = "Runner", count = 2, lane = "north" },
				{ type = "Grunt", count = 3, lane = "south" },
				{ type = "Archer", count = 2, lane = "east" },
			},
			tactic = "focus_weak_lane",
			event = "none",
			director_note = "They scent weakness at the breached north gate.",
		},
	},
	{
		name = "case2_early_blood_moon",
		wave = 3,
		expectOk = true, -- 통과하되 event는 none으로 교체된다
		input = {
			wave_name = "Red Moon Too Soon",
			enemies = {
				{ type = "Grunt", count = 6, lane = "north" },
				{ type = "Runner", count = 4, lane = "south" },
			},
			tactic = "split_push",
			event = "blood_moon",
			director_note = "A premature red moon rises.",
		},
	},
	{
		name = "case3_too_many",
		wave = 5,
		expectOk = true, -- 통과하되 총합 30으로 감량된다
		input = {
			wave_name = "Too Many Mouths",
			enemies = {
				{ type = "Grunt", count = 20, lane = "north" },
				{ type = "Runner", count = 12, lane = "south" },
				{ type = "Brute", count = 8, lane = "east" },
			},
			tactic = "siege",
			event = "none",
			director_note = "Far more than the keep can chew.",
		},
	},
	{
		name = "case4_too_few",
		wave = 2,
		expectOk = true, -- 통과하되 총합 4로 증량된다
		input = {
			wave_name = "Lonely Scouts",
			enemies = {
				{ type = "Grunt", count = 1, lane = "north" },
				{ type = "Runner", count = 1, lane = "south" },
			},
			tactic = "flank",
			event = "none",
			director_note = "Barely a patrol.",
		},
	},
	{
		name = "case5_bad_type",
		wave = 4,
		expectOk = false, -- cleanPlan은 nil, 대체 웨이브를 쓴다
		input = {
			wave_name = "Here Be Dragons",
			enemies = {
				{ type = "Dragon", count = 5, lane = "north" },
				{ type = "Grunt", count = 5, lane = "south" },
			},
			tactic = "siege",
			event = "none",
			director_note = "Something that should not exist.",
		},
	},
}
