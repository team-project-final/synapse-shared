# Runbook — synapse-shared 라이브러리 발행 (v0.1.0)

> **목적**: 이벤트 계약(Avro 스키마) 라이브러리 `com.synapse:synapse-shared`를 GitHub Packages에 발행해, 각 서비스가 `implementation` 의존으로 소비할 수 있게 한다.
> **대상**: @team-lead (org 권한 보유자) · **관련**: [EVENT_CONTRACT_STANDARD §6](../guides/EVENT_CONTRACT_STANDARD.md), [D-002 §7](../designs/D-002_SCHEMA_FAMILY_DECISION.md)
> **좌표**: `com.synapse:synapse-shared:0.1.0` · **레지스트리**: `https://maven.pkg.github.com/team-project-final/synapse-shared`

---

## 0. 사전 조건 (1회)
1. **org에서 GitHub Packages 활성화** (team-project-final → Settings → Packages 허용).
2. 발행 워크플로(`.github/workflows/publish.yml`)는 이미 레포에 있음 — `packages: write` 권한으로 동작.
3. 발행은 **`v*` 태그 push** 또는 **수동 실행**으로 트리거.

---

## 1. 발행 (방법 A — 태그 push, 권장)
```bash
# main이 최신인지 확인 후
git tag v0.1.0
git push origin v0.1.0
```
→ `publish.yml`이 자동 실행되어 `com.synapse:synapse-shared:0.1.0` 발행. Actions 탭에서 결과 확인.

## 1-B. 발행 (방법 B — 수동 실행)
GitHub → Actions → **"Publish shared library (GitHub Packages)"** → Run workflow → `version`에 `0.1.0` 입력 → Run.

## 1-C. 발행 (방법 C — 로컬, 디버깅용)
```bash
export GITHUB_ACTOR=<your-github-id>
export GITHUB_TOKEN=<PAT: write:packages>
./gradlew publishMavenPublicationToGitHubPackagesRepository -PreleaseVersion=0.1.0
```
> 로컬에서 인증 없이 산출물만 확인: `./gradlew publishToMavenLocal` → `~/.m2`에 `synapse-shared-0.1.0.jar`.

---

## 2. 발행 확인
- GitHub → 레포 → **Packages**에 `synapse-shared` 0.1.0 표시.
- 또는 소비 테스트(아래 §3 설정 후) `./gradlew dependencies | grep synapse-shared`.

---

## 3. 소비 측 설정 (각 서비스 — Java)
> ⚠️ GitHub Packages는 **공개 패키지라도 인증 필요**(GH 제약). 각 서비스/CI에 `read:packages` 토큰 필요.

`build.gradle.kts`:
```kotlin
repositories {
    mavenCentral()
    maven { url = uri("https://packages.confluent.io/maven/") }
    maven {
        url = uri("https://maven.pkg.github.com/team-project-final/synapse-shared")
        credentials {
            username = providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_ACTOR")
            password = providers.gradleProperty("gpr.token").orNull ?: System.getenv("GITHUB_TOKEN")
        }
    }
}
dependencies {
    implementation("com.synapse:synapse-shared:0.1.0")   // 생성된 Avro 클래스(UserRegistered, NoteCreated, ...) 포함
}
```
인증값(택1):
- 로컬: `~/.gradle/gradle.properties`에 `gpr.user=<id>` / `gpr.token=<PAT read:packages>`
- CI: 워크플로 env `GITHUB_ACTOR` + `GITHUB_TOKEN`(또는 org secret PAT)

> 의존으로 전환하면 §3 **벤더링(.avsc 복사)은 제거**. Python(learning-ai)은 라이브러리 불필요 — Schema Registry에서 직접 소비.

---

## 4. 버전 정책
- GitHub Packages 릴리스 버전은 **불변(immutable)** — 같은 `0.1.0` 재발행 불가(409).
- 스키마 변경 시 **버전 bump**: `v0.1.1`, `v0.2.0` ... 태그로 재발행. 소비 측 의존 버전도 갱신.
- 개발 중 잦은 갱신이 필요하면 `-PreleaseVersion=0.1.1-SNAPSHOT`(SNAPSHOT은 덮어쓰기 허용).

---

## 5. 트러블슈팅
| 증상 | 원인 | 해결 |
|------|------|------|
| `403 Forbidden` (발행) | 토큰 권한 부족 | 토큰에 `write:packages` 부여 / 워크플로 `permissions: packages: write` 확인 |
| `409 Conflict` | 동일 버전 이미 존재 | 버전 bump(§4) |
| `401/403` (소비) | `read:packages` 토큰 없음 | gradle.properties/env에 PAT 설정(§3) |
| org에 Packages 안 보임 | org Packages 비활성 | org Settings에서 활성화(§0-1) |
| 발행은 됐는데 클래스 없음 | jar에 generateAvroJava 누락 | `./gradlew jar` 후 `unzip -l build/libs/*.jar | grep com/synapse` 확인(현재는 포함 검증됨) |

---

## 6. 검증된 사실 (2026-05-29)
- `./gradlew publishToMavenLocal` → `synapse-shared-0.1.0.jar`에 생성 Avro 클래스 전부 포함(UserRegistered/NoteCreated/NoteUpdated/ReviewCompleted/CardReviewDue/LevelUp/BadgeEarned/NotificationSend/CloudEventEnvelope 등).
- 발행 태스크 `publishMavenPublicationToGitHubPackagesRepository` 정상 생성 확인.
- **2026-06-02 발행 완료**: `v0.1.0` 태그 push → publish.yml run 26792658024 성공 → `com.synapse:synapse-shared:0.1.0` GitHub Packages 등록. org Packages 정상 동작 확인.
- **잔여**: 각 서비스 소비 설정 배선(§3, `read:packages` 토큰). 비차단 경고: publish.yml 액션 Node.js 20 deprecation(2026-06-16 이후) → `actions/checkout`/`setup-java` 버전 업 권장.
