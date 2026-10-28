-- 이미지 에셋 ID (단일 기준: docs/tasks/day6.md 4단계).
-- 업로드는 사람이 크리에이터 허브에서 하고, 받은 ID를 직접 채운다
-- (순서는 docs/tasks/day6-upload.md 참고).
-- 값이 0이면 그 그림 없이 지금처럼 글자만 보여 준다.
-- 오류나 빈 사각형이 보이면 안 된다.
local AssetIds = {
	PortraitBram = 0,
	PortraitMira = 0,
	BannerDirector = 0,
	BannerFog = 0,
	BannerElite = 0,
	BannerReinforcement = 0,
	BannerBloodMoon = 0,
}

-- id가 0이면 그림을 숨기라는 뜻: nil을 돌려준다.
-- 0이 아니면 rbxassetid:// 문자열을 돌려준다.
function AssetIds.imageOrNil(key)
	local id = AssetIds[key]
	if type(id) == "number" and id ~= 0 then
		return "rbxassetid://" .. tostring(id)
	end
	return nil
end

return AssetIds
