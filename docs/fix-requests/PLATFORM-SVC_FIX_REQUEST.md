# 수정 요청: platform-svc CrashLoopBackOff

> **작성일**: 2026-05-21
> **작성자**: @team-lead (인프라/GitOps)
> **대상**: platform-svc 담당자
> **우선순위**: High — dev 환경 배포 차단 중
> **관련 PR**: synapse-gitops#35 (probe delay 수정)

---

## 증상

EKS `synapse-dev` namespace에서 `platform-svc` Pod가 **CrashLoopBackOff** 상태.

```
상태: Progressing (ArgoCD)
Pod:  CrashLoopBackOff → restart 반복
```

## 근본 원인

DB(RDS PostgreSQL) 연결은 성공하나, 애플리케이션 기동 시 **`mfa_credentials` 테이블이 존재하지 않아** 크래시 발생.

- Spring Boot의 JPA/Hibernate가 기동 시 `mfa_credentials` 테이블을 참조하는데 해당 테이블이 DB에 없음
- 인프라 레벨(SG, RDS 접근, ExternalSecret)은 모두 정상 — **앱 코드 레벨 문제**

## 인프라 측 이미 해결한 사항

| 항목 | 상태 |
|------|:----:|
| EKS Security Group → RDS/MSK/Redis/OpenSearch 접근 | ✅ |
| ExternalSecret → SecretSynced (DB 접속 정보 주입) | ✅ |
| liveness probe initialDelaySeconds 30s → 90s | ✅ (gitops PR #35) |
| Pod가 DB에 TCP 연결 성공 | ✅ |

## 요청 수정 사항

아래 중 하나를 선택하여 수정해주세요:

### 방법 A: Flyway Migration 추가 (권장)

`mfa_credentials` 테이블을 생성하는 Flyway migration 스크립트를 추가합니다.

```
src/main/resources/db/migration/V{N}__create_mfa_credentials.sql
```

```sql
CREATE TABLE IF NOT EXISTS mfa_credentials (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id),
    secret_key      VARCHAR(255) NOT NULL,
    enabled         BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mfa_credentials_user_id ON mfa_credentials(user_id);
```

> 테이블 스키마는 실제 엔티티 클래스에 맞게 조정 필요합니다.

### 방법 B: ddl-auto 설정 변경

`application.yml` (또는 dev 프로필)에서:

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: update  # 또는 create (dev 환경 한정)
```

> ⚠️ `ddl-auto: update`는 dev 환경에서만 사용하세요. staging/prod에서는 Flyway가 안전합니다.

### 방법 C: MFA 기능 비활성화 (임시)

MFA가 MVP 범위 밖이라면 dev 프로필에서 해당 기능을 비활성화:

```yaml
# application-dev.yml
app:
  mfa:
    enabled: false
```

## 검증 방법

수정 후 아래 순서로 확인:

1. 로컬에서 `docker compose up platform-svc` → 정상 기동 확인
2. PR 생성 → CI 통과
3. main 머지 → ArgoCD 자동 배포
4. `kubectl get pods -n synapse-dev -l app.kubernetes.io/name=platform-svc` → Running, restarts 0
5. `curl http://<platform-svc>:8081/actuator/health` → `{"status":"UP"}`

## 기한

**W3 시작 전(05-25)까지** 수정 완료 요청합니다.
3/5 서비스는 이미 Healthy이며, 5/5 달성 후 staging 배포 + E2E 검증 진행 예정입니다.

---

*문의: @team-lead / synapse-shared 레포 이슈*
