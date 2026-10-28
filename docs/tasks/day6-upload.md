# day6 이미지 업로드 (사람이 할 일)

`assets/images/`의 PNG 8장 중 7장을 게임에 넣는다. 아래 순서대로 한다.

## 1. 크리에이터 허브에 업로드

크리에이터 허브(Creator Hub) → 에셋 → 이미지 업로드:

| 파일 | `AssetIds.luau` 키 |
|---|---|
| portrait_bram.png | `PortraitBram` |
| portrait_mira.png | `PortraitMira` |
| banner_director.png | `BannerDirector` |
| banner_fog.png | `BannerFog` |
| banner_elite.png | `BannerElite` |
| banner_reinforcement.png | `BannerReinforcement` |
| banner_blood_moon.png | `BannerBloodMoon` |

`thumbnail.png`은 업로드하지 않는다. 체험 대표 이미지(게임 아이콘)로 따로 등록한다.

## 2. 이미지 ID 확인·입력

업로드한 뒤 각 에셋의 숫자 ID를 복사해 `src/shared/AssetIds.luau`의
위 표 오른쪽 키에 넣는다. 지금은 전부 `0`이다.

값이 `0`인 그림은 표시되지 않고 글자만 나온다.
ID를 다 채우기 전에도 게임은 정상 동작한다.
