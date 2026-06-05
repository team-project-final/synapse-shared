# 12. Flyway 마이그레이션 버전 규칙

> 적용일(cutover): 2026-06-05 · 적용 대상: 모든 Java 서비스(platform/knowledge/learning/engagement)

## 규칙

1. **신규 마이그레이션 버전 = 14자리 타임스탬프**
   - 형식: `V<yyyyMMddHHmmss>__<설명>.sql` (예: `V20260605120000__add_user_status.sql`)
   - 버전 토큰은 **순수 14자리 숫자**. 문자(`T` 등)·구분기호 금지(Flyway 버전 파서 호환).
   - 타임스탬프는 기존 정수(max 32)보다 항상 크므로 Flyway가 자연히 뒤로 정렬 → 기존 파일 재번호 불필요.

2. **기존 정수 `Vn` 파일은 변경·재번호·삭제·이동 금지** (checksum 안정성). rename/move도 위반으로 간주한다.

3. **Flyway 설정 표준(application.yml `spring.flyway`)**
   - `out-of-order: true` (늦게 머지된 더 이른 타임스탬프 적용 허용)
   - `baseline-on-migrate`: 서비스 현실대로 **명시**(learning=true, 그 외=false)
   - `locations`: 서비스 현행 유지(engagement 멀티 location 허용 — 타임스탬프로 충돌 자동 방지)

4. **CI 가드(차단)**: 모든 PR에서 `Flyway Guard`(synapse-shared의 재사용 workflow)가 실행되어 아래를 위반하면 **fail**:
   - 동일 버전 토큰 2개 이상(중복 버전)
   - 추가된 마이그레이션이 14자리 타임스탬프가 아님
   - 이미 머지된 마이그레이션 파일의 수정/삭제/이동

## 새 마이그레이션 만들 때

타임스탬프는 생성 시각으로 직접 기입한다. 예시 생성 명령:

```bash
echo "V$(date +%Y%m%d%H%M%S)__describe_change.sql"
```
