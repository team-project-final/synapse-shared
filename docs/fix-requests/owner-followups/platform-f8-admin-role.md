## 배경 / 근거

W4 성공기준 #3(관리자 신고 + 모더레이션 API)과 W5 관리자 모더레이션 E2E가 **platform의 ADMIN role 발급 메커니즘 부재**로 차단된다(버그 **F8**). engagement 모더레이션 API는 `ADMIN` 권한을 요구하지만, platform은 사용자에게 ADMIN role을 발급하는 경로 자체가 없다.

- 출처: synapse-shared `docs/reports/E2E_W5_DAY2.md` §3 (F8) · `docs/designs/D-004_USER_IDENTITY_MODEL.md` §5(F8은 식별자와 별개 트랙)
- 연관 E2E 이슈: platform-svc #62 ([W5 E2E] 알림+인증+결제 라이브 E2E) — 본 건이 모더레이션 leg를 차단

## 현재 상태 (실측 2026-06-10, origin/main)

1. **role이 코드 상수에 하드코딩** — `src/main/java/com/synapse/platform/auth/AuthRoles.java`. 로그인/가입 시 모든 사용자에 고정 role만 부여, ADMIN 승격 경로 없음.
2. **users 테이블에 roles 컬럼 부재** — `src/main/resources/db/`(flyway)에 roles/user_roles 스키마 없음(grep 0건). 즉 role을 영속화할 자리가 없다.
3. **명명 불일치** — platform은 `ROLE_ADMIN` 관례(Spring Security), engagement 모더레이션은 `ADMIN`을 기대 → JWT authorities/claim 매핑 규칙 불일치.

영향: 관리자 계정을 만들 수 없어 engagement 신고/모더레이션 API(ADMIN 전용)를 E2E로 검증 불가 → W4-3·W5 모더레이션 데모 차단.

## 정확한 변경 지점 (제안)

1. **role 영속화 스키마** — flyway 신규 마이그레이션:
   - 옵션 A: `users.roles`(text[]/varchar, 콤마구분) 컬럼 추가.
   - 옵션 B(권장): `user_roles(user_id FK, role)` 테이블 + 다대다. 멀티 role 확장 용이.
2. **role 발급 로직** — `auth/service/EmailPasswordAuthService`(가입), `CustomOAuth2UserService`/`CustomOidcUserService`(소셜)에서 기본 role 부여 + **ADMIN 승격 경로**(시드 관리자 계정 또는 관리자 전용 승격 API). 최소 데모용으로 **시드 admin 1계정**(flyway seed 또는 부트스트랩)도 허용.
3. **JWT claim** — `auth/service/JwtTokenProvider`가 사용자 role을 `roles`(또는 `authorities`) claim에 실어 발급.
4. **명명 규칙 정합** — platform↔engagement 간 role 문자열 계약 합의: `ROLE_ADMIN`(Spring 관례) ↔ engagement `ADMIN` 매핑을 어느 쪽에서 정규화할지 결정하고 문서화(EVENT/AUTH 계약). engagement `CurrentUser`/권한체크와 정합.

> **합의 필요**: role 모델·승격 정책·명명 계약은 platform·engagement 공동 결정. D-004(식별자)와 같은 인증 합의 세션에서 함께 확정 권고.

## 검증 (DoD)

- [ ] 시드/승격으로 ADMIN role 보유 사용자 생성 가능
- [ ] 해당 사용자 JWT에 ADMIN role claim 포함(디코드 확인)
- [ ] 그 JWT로 engagement 모더레이션 API 호출 → **200**(현재는 권한 부족으로 차단)
- [ ] 일반 사용자 JWT로는 모더레이션 API **403**
- [ ] W5 관리자 모더레이션 E2E(신고→모더레이션) PASS

## 참조
- synapse-shared `docs/reports/E2E_W5_DAY2.md` §3 (F8)
- synapse-shared `docs/designs/D-004_USER_IDENTITY_MODEL.md` §5
- platform-svc #62 (W5 E2E)
- synapse-shared `docs/project-management/HANDOFF_W5_DAY3.md` §0(이월 owner 합의)
