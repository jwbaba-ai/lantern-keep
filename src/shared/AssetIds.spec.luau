-- AssetIds 검사 (단일 기준: docs/tasks/day6.md 6단계).
-- 실행법(Studio 명령줄): require(... Shared["AssetIds.spec"])
-- require 한 줄로 아래를 PASS/FAIL로 출력한다. 모델·DataStore 없이 실행된다.
local AssetIds = require(script.Parent:WaitForChild("AssetIds"))

local results = {}

local function check(name, pass)
	table.insert(results, { name = name, pass = pass })
	print(string.format("[AssetIds.spec] %s: %s", name, pass and "PASS" or "FAIL"))
end

local KEYS = {
	"PortraitBram",
	"PortraitMira",
	"BannerDirector",
	"BannerFog",
	"BannerElite",
	"BannerReinforcement",
	"BannerBloodMoon",
	"PortraitWarlord",
	"BannerBoss",
}

-- 1. 모든 키가 존재하고 숫자다.
do
	local ok = true
	for _, key in ipairs(KEYS) do
		if type(AssetIds[key]) ~= "number" then
			ok = false
		end
	end
	check("all_keys_numeric", ok)
end

-- 2. 값이 0이면 imageOrNil이 nil을 돌려준다 (그림 숨기기).
do
	local ok = true
	for _, key in ipairs(KEYS) do
		if AssetIds[key] == 0 and AssetIds.imageOrNil(key) ~= nil then
			ok = false
		end
	end
	check("zero_hides_image", ok)
end

-- 3. 없는 키도 nil을 돌려준다.
do
	check("missing_key_nil", AssetIds.imageOrNil("NoSuchKey") == nil)
end

-- 4. day8 새 키 2개가 있고 숫자다 (업로드 전 0이면 그림 숨기기).
do
	check(
		"day8_boss_keys",
		type(AssetIds.PortraitWarlord) == "number"
			and type(AssetIds.BannerBoss) == "number"
	)
end

return results
