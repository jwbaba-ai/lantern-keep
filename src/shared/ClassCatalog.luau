-- 직업 데이터 (단일 기준: docs/tasks/day3.md 1단계 표).
-- Damage/Heal: 1회 공격(치유) 수치 / Cooldown: 초 / MaxHealth: 시작 체력.
-- Range: 조준이 닿는 최대 거리(스터드) / Radius: 중심으로부터 판정 반경(스터드).
return {
	guardian = {
		DisplayName = "Guardian",
		Description = "Sturdy shield-bearer who holds the gate in melee.",
		Damage = 35,
		Cooldown = 0.8,
		MaxHealth = 200,
		Radius = 8, -- 앞쪽 반경 안의 적에게 피해
	},
	ranger = {
		DisplayName = "Ranger",
		Description = "Precise archer who snipes from afar.",
		Damage = 25,
		Cooldown = 0.6,
		MaxHealth = 100,
		Range = 120, -- 마우스 방향 레이캐스트 사거리
	},
	arcanist = {
		DisplayName = "Arcanist",
		Description = "Spellcaster whose blast scorches a whole crowd.",
		Damage = 20,
		Cooldown = 1.5,
		MaxHealth = 90,
		Range = 80, -- 마우스 위치 조준 사거리
		Radius = 10, -- 폭발 반경
	},
	cleric = {
		DisplayName = "Cleric",
		Description = "Healer who mends allies and smites foes up close.",
		Heal = 30,
		Cooldown = 2.0,
		AttackDamage = 10, -- 근접 공격 피해
		MaxHealth = 120,
		Radius = 15, -- 아군 치유 반경
		MeleeRadius = 8, -- 근접 공격 반경
	},
}
