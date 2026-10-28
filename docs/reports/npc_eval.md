# NPC 출력 검증

- 실행 날짜: 2026-10-28 / 모델: muse-spark-1.3 / effort: low
- 총 호출: 9건 (fixture 3개 × 최대 3회)

## 검증 통과율

- 통과 9/9건 (100.0%)
- 규칙: 줄 수 각 3개, 각 줄 1~80자, P 토큰은 파티 인원 안에서만 (MemoryStore.validate와 같은 규칙)

## 사건 언급률

- 언급 8/9건 (88.9%)
- 기준: 입력 events의 성문 이름(영문·한글)이나 웨이브 번호가 대사 6줄 중 한 번 이상 나오면 언급함. 성공 기준 'NPC가 지난 판을 언급'의 근거다.
  - cleric_heroes.json run1: 언급함 (웨이브 7 언급)
  - cleric_heroes.json run2: 언급 없음 (언급 없음)
  - cleric_heroes.json run3: 언급함 (성문 언급: 동문)
  - first_loss.json run1: 언급함 (성문 언급: 북문)
  - first_loss.json run2: 언급함 (성문 언급: 북문)
  - first_loss.json run3: 언급함 (성문 언급: 북문)
  - second_win.json run1: 언급함 (성문 언급: 북문)
  - second_win.json run2: 언급함 (성문 언급: 남문)
  - second_win.json run3: 언급함 (성문 언급: 북문)

## 평균 토큰

- 입력 888 / 출력 1614

## 언급 성공 대사 예시

- cleric_heroes.json run1:
  - 1. Bram: 반갑다! 7웨이브 승리, 동쪽문 기억하자! / Mira: 안녕하세요! 성직자 P2 고마워요!
  - 2. Bram: 1웨이브 좋다! 수호자 P1, 버텨라! / Mira: 1웨이브 수고했어요, P3 최고예요!
  - 3. Bram: 3웨이브 돌파! 동쪽문 P2, P3 부탁한다! / Mira: 3웨이브 힘내요, P1 곁에 있을게요!
- cleric_heroes.json run3:
  - 1. Bram: 반갑다 P1 P2 P3! 7파 승리자들이여! / Mira: P2님 고마워요! 9번이나 살려주셨어요!
  - 2. Bram: 1파다! 5파 동문처럼 뚫리지 말자! / Mira: P3님 이번도 안 쓰러지고 최고예요!
  - 3. Bram: 3파다! 7파 승리까지 동문 지켜라! / Mira: P1 수호자님 힘내요! 7파까지 가요!

