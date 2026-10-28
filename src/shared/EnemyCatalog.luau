-- 적 기준값 (단일 기준: docs/GAME_DESIGN.md 적 표).
-- 밸런스를 바꾸려면 기획 표를 먼저 고친 뒤 여기에 반영한다.
-- Health: 체력 / Speed: 스터드-초 / LanternDamage: 등불에 닿았을 때 깎는 체력.
return {
	Grunt = {
		Health = 100,
		Speed = 10,
		LanternDamage = 5,
		Color = BrickColor.new("Reddish brown"),
		Size = Vector3.new(3, 4, 3),
	},
	Runner = {
		Health = 50,
		Speed = 20,
		LanternDamage = 3,
		Color = BrickColor.new("Bright yellow"),
		Size = Vector3.new(2.5, 3, 2.5),
	},
	Brute = {
		Health = 400,
		Speed = 6,
		LanternDamage = 15,
		Color = BrickColor.new("Really black"),
		Size = Vector3.new(4.5, 5.5, 4.5),
	},
	Archer = {
		Health = 80,
		Speed = 9,
		LanternDamage = 4,
		Color = BrickColor.new("Bright green"),
		Size = Vector3.new(3, 4, 3),
	},
	Shaman = {
		Health = 120,
		Speed = 8,
		LanternDamage = 2,
		Color = BrickColor.new("Bright violet"),
		Size = Vector3.new(3, 4, 3),
	},
}
