# Day 13c 수정 — 투명 웨이포인트가 사격을 막음 (아주 짧은 작업)

먼저 `docs/devlog/2026-11-05.md` 끝의 "Claude Code Studio 확인 (day13b)" 표 3-2~3-4를 본다. 새 기능은 넣지 않는다.

## 공통 규칙
- 고칠 수 있는 파일: `src/server/World/MapBuilder.server.luau`, devlog, `docs/GAME_DESIGN.md`.
- `schemas/`, 두 `prompt.txt`, `src/shared/`는 고치지 않는다.
- 환경 설정·패키지 설치 명령과 Studio를 찾거나 실행하는 명령은 쓰지 않는다. Studio 확인은 Claude Code가 한다.
- `git push`가 인증 문제로 실패하면 다시 시도하지 말고 devlog에 적고 보고한다. Claude Code가 리뷰 후 push한다.

## 1. [높음] 웨이포인트를 사격 판정에서 빼기 — `MapBuilder.server.luau`
- 측정: 성문 한가운데의 2×2×2 투명 파트 `Lanes/<lane>/2`에 사격이 멈춘다. 지원대 궁수는 레인 축 위에 서므로 성문 밖 적을 전혀 못 맞힌다. Play 중 임시로 `CanQuery=false`로 두면 4발에 처치했다.
- 고칠 것: 웨이포인트 파트를 모두 `CanQuery = false`로 한다. 두 곳 모두 넣는다.
  - `buildMap`의 웨이포인트 `makePart` 값
  - 저장된 맵을 맞추는 아래쪽 루프: `map.Lanes/<lane>`의 자식 BasePart 전체에 `CanQuery = false`를 넣는다. 폴더가 없으면 건너뛴다.
- `DirectorService`는 웨이포인트 위치만 읽으므로 다른 파일은 고치지 않는다.

## 마무리
- `docs/GAME_DESIGN.md`의 "성문은 사격을 막지 않는다" 문장에 웨이포인트도 같다고 짧게 적는다.
- devlog에 "day13c" 절로 한 일을 적고 커밋한 뒤 `git push`(원격: origin/main)한다.

## 확인할 것 (Claude Code가 Studio MCP로)
- [ ] spec 모두 PASS, 오류·경고 없음
- [ ] 웨이포인트 12개 모두 `CanQuery=false`
- [ ] 실제 지면 높이의 궁수가 성문 축(x=0)에서 성문 밖 적을 맞힌다
- [ ] 지원대 궁수가 성문 밖 적을 맞힌다
- [ ] 적 이동과 경로가 그대로다. 웨이브 1~3 회귀: 멈춘 적 0, 시간 초과 없음
- [ ] 밸런스 참고: 웨이브 1~3 지속 시간과 등불 체력을 day13b 값(29.6 / 38.3 / 44.4초)과 비교해 적는다
