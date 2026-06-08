# shared W1~W4 작업 구성 미완료 검토

> **작성**: 2026-06-08 · **작성자**: @team-lead · **근거 설계**: [2026-06-08-shared-w1w4-incomplete-review-design](../superpowers/specs/2026-06-08-shared-w1w4-incomplete-review-design.md)
> **범위**: synapse-shared `WORKFLOW_team-lead_W1~W4` 적힌 항목 전수. 조치가 gitops면 이관 표시.
> **한 줄 결론**: W1~W4 미완 대부분 W5 Day1에 ✅해소 또는 🔄W5 일정 추적중. 진짜 미추적 잔여는 **TLS 전송 검증 1건뿐**(본 검토에서 ✅ 실증). 발표(06-15) 차단 리스크 없음.

## 1. 분류 방법
- ✅ 해소됨 / 🔄 W5 추적중 / 🔴 미추적 잔여 (3-state)
- 발표 리스크: 🔴높음(데모 직접 노출) / 🟡중간(Q&A·근거 공백) / ⚪낮음(문서·정책)

## 2. 정합 매트릭스
| 주차 | 항목 | 원래 상태 | 분류 | 근거 | 발표리스크 | 조치 |
|---|---|---|---|---|---|---|
| W1 | 전 Step (인프라/compose/CICD) | Done | ✅ | WORKFLOW_W1 | ⚪ | 종결 |
| W2 | MSK 9토픽 생성 | `[ ]`(gitops 이월) | ✅ | terraform `kafka-topics/`, MSK ACTIVE(06-08) | ⚪ | 종결 |
| W2 | 인증 모델(SASL/IAM vs TLS-only) | "결정 필요" | ✅ | KAFKA_AUTH_MATRIX §1 — B(TLS-only) 확정(06-02) | ⚪ | 종결(인용) |
| W2 | Kafka ACL / 민감토픽 접근제한 | `[ ]` | ✅ | 동 §1 — W5+ 백로그로 명시 종결 | ⚪ | 범위외 선언됨 |
| W2 | TLS 전송 실측 검증 | `[ ]` | ✅(본 검토) | §4 TLS 증거 | 🟡→닫힘 | 본 리포트로 종결 |
| W2 | console produce/consume(MSK) | `[ ]` | ✅ | 서비스 consumer group 활성(EKS) + 로컬 `--avro` 8/8 | ⚪ | 대체 충족 |
| W3 | gamification/note.created Producer·engagement Consumer | 🟡조건부 | ✅ | 4서비스 origin/main 머지(#40/#46/#23/learning) | ⚪ | 종결 |
| W3 | platform/engagement dev→main | 🟡조건부 | ✅ | #46/#23 머지 | ⚪ | 종결 |
| W3 | ArgoCD dev/staging 배포·검증·롤백 | `[ ]`(EKS destroy) | ✅ | W5 Day1 dev16/staging20 ALL PASS, 롤백124s(06-02) | ⚪ | 종결 |
| W3 | 서비스 단위 E2E 실행 | `[ ]` | 🔄 | W5_PLAN Day2, env 준비(shared#25) | 🟡 | W5 Day2 |
| W4 | 서비스 로직 E2E 실행(Step9.2) | `[~]` | 🔄 | W5_PLAN Day2 | 🟡 | W5 Day2 |
| W4 | SLA 성능 측정(Step10) | `[ ]` | 🔄 | WORKFLOW_W5 Step10, Day3 | ⚪ | W5 Day3 |
| W4 | Staging 최종+모니터링(Step11) | `[ ]` | ✅(부분)/🔄 | staging 5/5+Observability 기동(06-08), 24h·대시보드 Day4 | ⚪ | W5 Day4 |
| W4 | Step11.1 staging 검증 시나리오 정의 | `[ ]` | ✅ | verify-argocd-deploy.sh로 대체 | ⚪ | 종결 |
| W4 | 발표 자료·리허설(Step12) | `[ ]` | 🔄 | W5_PLAN Day5(6/12 리허설) | ⚪ | W5 Day5 |

## 3. 🔴 미추적 잔여 — 0건
설계 단계에서 5건으로 추정했으나 실측 결과:
- W2 인증/ACL(1·2·3) → KAFKA_AUTH_MATRIX §1에 **이미 결정·종결**(TLS-only, ACL은 W5+ 백로그 명시) → ✅
- TLS 전송 검증(4) → **본 검토에서 실증**(§4) → ✅
- W4 Step11.1(5) → verify-argocd-deploy.sh로 대체 → ✅

**결과: 진짜 미추적 잔여 없음.** 모든 W1~W4 미완은 해소·결정·W5추적 중 하나로 귀속됨.

## 4. TLS 전송 검증 증거 (W2 §4.5 잔여 종결)
in-cluster openssl s_client → MSK 9094 핸드셰이크 (2026-06-08, synapse-dev 네임스페이스 임시 파드):
```
BROKER=b-1.synapsedevkafka.nhfzx9.c2.kafka.ap-northeast-2.amazonaws.com:9094
issuer=C=US, O=Amazon, CN=Amazon RSA 2048 M01
subject=CN=*.synapsedevkafka.nhfzx9.c2.kafka.ap-northeast-2.amazonaws.com
notBefore=Jun  8 00:00:00 2026 GMT
notAfter=Dec 22 23:59:59 2026 GMT
Certificate will not expire
HANDSHAKE_OK
```
→ Amazon Trust Services CA 체인(`Amazon RSA 2048 M01`)으로 TLS 핸드셰이크 성공. dev MSK TLS-only 전송 실증. KAFKA_AUTH_MATRIX §1(B 채택)와 정합.

## 5. 발표 리스크 레지스터 (06-15)
| 리스크 | 등급 | 대응 |
|---|---|---|
| 서비스 로직 E2E 미실행 | 🟡 | W5 Day2 실행 — 데모 핵심 체인. owner P0 2건([AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md)) 선결 |
| TLS 전송 근거 공백 | 🟡→닫힘 | 본 리포트 §4 증거로 종결 |
| 그 외 | ⚪ | 없음 |

🔴 높음 = 없음. 발표 차단 요소 없음.

## 6. 권고
1. ✅ **TLS 전송 검증** — 본 검토에서 실행·증거 확보 완료(§4).
2. ✅ **인증 모델 종결** — 이미 KAFKA_AUTH_MATRIX §1에 TLS-only 확정. 추가 조치 불요(인용으로 충족).
3. 🔄 **나머지** — W5_PLAN Day2~5 일정에 이미 연결됨. 별도 신규 작업 없음.

## 7. 부록 — 출처
WORKFLOW_team-lead_W1~W4 · W3_EXIT_GATE · W4_EXIT_GATE · KAFKA_AUTH_MATRIX · W4_DAY1_POST_APPLY · HANDOFF_SHARED/HUB(06-08) · E2E_SMOKE_W5_DAY1 · shared#25/#26 · gitops#136.
