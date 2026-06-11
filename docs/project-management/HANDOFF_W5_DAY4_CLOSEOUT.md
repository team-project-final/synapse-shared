# 핸드오프 — W5 Day4 종료(closeout) → Day5 진입점

> **작성**: 2026-06-11 (W5 Day4 종료) · **다음 세션 진입점** · **Day5**: 06-12(금, 발표 준비) · **발표**: 06-15(월, 코드 동결)
> **상위**: [HANDOFF_HUB](./HANDOFF_HUB.md) · [HANDOFF_W5_DAY3_CLOSEOUT](./HANDOFF_W5_DAY3_CLOSEOUT.md) · [STAGING_BRINGUP_W5_DAY4](../reports/STAGING_BRINGUP_W5_DAY4.md) · [W5_PLAN](./W5_PLAN.md)

---

## 1. 한 줄 현황

Day4 **staging 완전 가동** 달성 — gitops bring-up이 bastion IAM 결함으로 중단된 것을 team-lead가 로컬 우회 복구, 이후 owner 이미지·태그 정합으로 **ArgoCD 16/16 Synced/Healthy(dev 9 + staging 7)** + ES nori green + Observability 스택 + **P0 회귀 PASS**. 남은 건 **24h 사인오프(06-12 17:15, 메트릭 갭 선결)** 와 **Day5 발표 자료**.

## 2. 이번 세션(Day4) 완료

| 영역 | 결과 |
|---|---|
| **staging bring-up 복구** | bastion `synapse-dev-bastion-role` `eks:DescribeCluster` 결여로 ArgoCD 부트스트랩 전 중단 → 로컬 SSM 터널 + `bring-up.sh --from tunnel`로 멱등 재개(argocd→eso→...→observability) |
| **ES nori** | CrashLoop(데이터 디렉터리 권한) → 파드 재생성으로 fsGroup+OnRootMismatch chown → **green + analysis-nori** |
| **서비스 ECR 레포 7종** | 전부 부재였음 → team-lead admin 선생성(MUTABLE, scanOnPush) → owner CI push 가능화 |
| **앱 Health** | owner 이미지 push + staging 태그 정합([gitops#191](https://github.com/team-project-final/synapse-gitops/issues/191)) → **dev 9/9 + staging 7/7 Healthy** |
| **Observability** | prometheus·alertmanager·grafana·loki·promtail + ServiceMonitor 2·PrometheusRule 1·대시보드 2 |
| **P0 회귀(FR-ALL-302)** | **PASS** — C(컨슈머 poison ERROR 0) + B(라이브 가입→engagement 무poison 소비+audit) |
| 문서 | [STAGING_BRINGUP_W5_DAY4](../reports/STAGING_BRINGUP_W5_DAY4.md)(§1~10) + 본 핸드오프 |

## 3. 24h 안정 사인오프 — **06-12 17:15 KST 이후**

- **앵커**(의미 있는 24h 시작 = dev+staging 전 서비스 Healthy 확정): **2026-06-11 ~17:15 KST**.
- **워크로드는 이미 안정**(16/16 Healthy, 재시작 0, ES green) — 앵커 스냅샷 PASS.
- ⚠️ **클린 사인오프 선결 = 알림/메트릭 갭**(아래 §4 메트릭): firing이 `Watchdog`만 남아야 함.
- **할 일(06-12 17:15 이후)**: 24h 재점검 — Alertmanager firing 확인 + 파드 재시작/Degraded 0 확인 → 사인오프.

## 4. 미해결 이슈 레지스터 (다음 세션)

| 영역 | 이슈 |
|---|---|
| **메트릭 갭(24h 선결)** | `/actuator/prometheus` 5/6 실패: [platform#101](https://github.com/team-project-final/synapse-platform-svc/issues/101)(500)·[engagement#45](https://github.com/team-project-final/synapse-engagement-svc/issues/45)(401)·[knowledge#82](https://github.com/team-project-final/synapse-knowledge-svc/issues/82)(500)·[learning#85](https://github.com/team-project-final/synapse-learning-svc/issues/85)(card 500 + ai 404 Python) · EKS 알림 룰 false-positive + learning-ai 경로 = [gitops#194](https://github.com/team-project-final/synapse-gitops/issues/194) |
| **staging window** | [gitops#183](https://github.com/team-project-final/synapse-gitops/issues/183) — Day4용 유지 결정, **24h 종료 후 `bring-up.sh --destroy`** |
| **bring-up 무인화** | [gitops#182](https://github.com/team-project-final/synapse-gitops/issues/182) — bastion IAM(eks:DescribeCluster) + 서비스 ECR 레포 terraform 관리화. **미해소 시 재기동마다 수동 우회** |
| **기능검색(P3)** | [gitops#174](https://github.com/team-project-final/synapse-gitops/issues/174)(nori 환경 done, 기능 owner) · knowledge 인덱서(knowledge#71) |
| **스키마 정렬** | [learning#81](https://github.com/team-project-final/synapse-learning-svc/issues/81) — ReviewCompleted 정본 정렬(platform#87 DLT 근본수정) |
| **Actions Node20** | engagement#40·knowledge#77·learning#82·platform#97 (engagement#40은 ecr-login 깨짐 = 이미지 push 선행 차단) |
| (이월) | P6 AI 체인·커버리지 80%·F8 ADMIN role 등 — [HANDOFF_W5_DAY3_CLOSEOUT §4](./HANDOFF_W5_DAY3_CLOSEOUT.md) |

## 5. Day5 우선순위 (06-12, team-lead)

1. **[team-lead] 발표 슬라이드(15~20) + 데모 스크립트(5분)** (FR-TL-305) — 아키텍처·E2E·SLA·staging 복구 스토리 포함.
2. **⚠️ [결정] 데모 접근 경로** — **현재 ingress/ALB 없음**(LoadBalancer 0). 데모를 ① in-cluster port-forward(현 방식) ② ingress/ALB 프로비저닝(gitops) 중 택1. **사전 결정 필요**.
3. **[team-lead] 시연 환경 사전 점검** — staging 계정/시드/깨진 링크 0. (앱 Healthy하나 외부노출 미정)
4. **[전체] 리허설 1회 이상** + 회고 → 보완.
5. **[team-lead] 24h 사인오프**(06-12 17:15 이후, §3).
6. **코드 동결 준비** — 06-15 발표 전 P0 hotfix만.

## 6. 환경·접근 메모 (필수)

- **EKS synapse-dev 가동 중**(Day4용 유지, gitops#183). 비용: 4×t3.large + MSK + RDS×2 + NAT. **24h 종료 후 `bash scripts/bring-up.sh --destroy`**(gitops, orphan LB 선정리 포함).
- **private 엔드포인트** → 로컬 kubectl은 **SSM 터널 필수**:
  ```bash
  HOST=$(aws eks describe-cluster --name synapse-dev --region ap-northeast-2 --query cluster.endpoint --output text | sed 's#https://##')
  aws ssm start-session --target i-02747399a09279217 --region ap-northeast-2 \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$HOST\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"8443\"]}"
  # kubeconfig: server=https://localhost:8443, tls-server-name=$HOST (또는 gitops scripts/lib/eks-tunnel.sh = 6443)
  ```
  ⚠️ SSM 세션은 **유휴 시 끊김** → 재수립 빈번.
- **재기동**(destroy 후): gitops `bash scripts/bring-up.sh`(터널 자동) — 단 bastion IAM(#182) 전엔 무인 불가, team-lead 로컬 구동: `bring-up.sh --from tunnel`(tfvars 시크릿 `TF_VAR_rds_password`/`redis_auth_token` 주입).
- 가입 트리거(P0 회귀용): in-cluster `POST http://platform-svc/api/v1/auth/signup {email,password}`.

## 7. 핵심 참조
- Day4 상세: [STAGING_BRINGUP_W5_DAY4](../reports/STAGING_BRINGUP_W5_DAY4.md) · SLA: [SLA_VERIFICATION_W5](../reports/SLA_VERIFICATION_W5.md) · 일정: [W5_PLAN](./W5_PLAN.md)
- owner 후속: [owner-followups/README](../fix-requests/owner-followups/README.md) · 허브: [HANDOFF_HUB](./HANDOFF_HUB.md)
