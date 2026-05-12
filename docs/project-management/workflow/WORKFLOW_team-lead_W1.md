# WORKFLOW: @team-lead — Week 1

> **Task 문서**: [TASK_team-lead.md](../task/TASK_team-lead.md)  
> **기간**: 2026-05-12 ~ 2026-05-16  
> **기능개발 Workflow**: [README §7](../README.md)

---

## Step 1: AWS 인프라 프로비저닝

### 1.1 TASK 시작
- [ ] Step Goal / Done When / Scope / Input 확인
- [ ] PRD_W1 해당 요구사항 확인 (인프라 프로비저닝)
- [ ] Duration 산정 확인 (2일)

### 1.2 요구사항 분석
- [ ] EKS/RDS/MSK/ElastiCache/OpenSearch 각 서비스 스펙 정의
- [ ] ArgoCD ApplicationSet 구성 요건 분석 (5서비스x3환경)
- [ ] VPC/서브넷/보안그룹 설계 요건 분석
- [ ] Instructions 초안 → TASK 문서 반영

### 1.3 Security 1차 검토 (네트워크 보안)
- [ ] VPC 내부 통신만 허용 (퍼블릭 접근 제한)
- [ ] 보안 그룹 인바운드/아웃바운드 규칙 정의
- [ ] IAM Role/Policy 최소 권한 원칙 적용
- [ ] 결과 → TASK Constraints 반영

### 1.4 인프라 아키텍처 설계
- [ ] EKS 클러스터 노드 구성 (3 node) 설계
- [ ] RDS PostgreSQL 16 (db.t3.medium) 구성 설계
- [ ] MSK Kafka 3.x (3 broker) + Schema Registry 설계
- [ ] ElastiCache Redis 7 (cache.t3.micro) 설계
- [ ] OpenSearch 8.x (1 node dev) + nori 플러그인 설계
- [ ] Duration(final) 갱신

### 1.5 Security 2차 검토
- [ ] RDS 암호화 at-rest/in-transit 설정 확인
- [ ] MSK TLS 통신 설정 확인
- [ ] ElastiCache AUTH 토큰 설정 확인
- [ ] 결과 → TASK Constraints 반영

### 1.6 N/A (인프라 — DTO/Entity 해당 없음)

### 1.7 Terraform/eksctl 구현
- [ ] EKS 클러스터 생성 (eksctl 또는 Terraform)
- [ ] RDS PostgreSQL 인스턴스 생성 + 보안 그룹 설정
- [ ] MSK 클러스터 생성 + Schema Registry 설정
- [ ] ElastiCache Redis 클러스터 생성
- [ ] OpenSearch 도메인 생성 + nori 플러그인
- [ ] ArgoCD 설치 + ApplicationSet(5서비스x3환경) 구성

### 1.8 접속 테스트
- [ ] kubectl get nodes → Ready 확인
- [ ] RDS PostgreSQL 접속 테스트
- [ ] MSK 브로커 접속 테스트
- [ ] ElastiCache Redis 접속 테스트
- [ ] OpenSearch 도메인 접속 테스트
- [ ] ArgoCD 대시보드 접근 테스트
- [ ] 팀원 접근 권한 부여 확인

### 1.9 N/A (인프라 — Controller 해당 없음)

### 1.10 N/A (인프라 — View 해당 없음)

**Step 1 Status**: [ ] Not Started / [ ] In Progress / [ ] Done

---

## Step 2: Docker Compose 4-서비스 구성

### 1.1 TASK 시작
- [ ] Step Goal / Done When / Scope / Input 확인
- [ ] PRD_W1 해당 요구사항 확인 (로컬 개발환경)
- [ ] Duration 산정 확인 (1일)

### 1.2 요구사항 분석
- [ ] 4-서비스 + infra 컨테이너 목록 확정
- [ ] Health check 기준 정의 (각 서비스별)
- [ ] .env.example 환경변수 목록 도출
- [ ] Instructions 초안 → TASK 문서 반영

### 1.3 Security 1차 검토 (네트워크 보안)
- [ ] 컨테이너 간 네트워크 격리 정책 확인
- [ ] 외부 포트 바인딩 최소화
- [ ] 시크릿 관리 (.env 파일 gitignore 확인)
- [ ] 결과 → TASK Constraints 반영

### 1.4 인프라 아키텍처 설계
- [ ] docker-compose.yml 서비스 구성도 작성
- [ ] 서비스 간 depends_on 의존관계 정의
- [ ] 볼륨/네트워크 설계
- [ ] Duration(final) 갱신

### 1.5 Security 2차 검토
- [ ] DB 비밀번호 환경변수 관리 확인
- [ ] Redis AUTH 설정 확인
- [ ] 민감정보 .env.example에 플레이스홀더만 기재
- [ ] 결과 → TASK Constraints 반영

### 1.6 N/A (인프라 — DTO/Entity 해당 없음)

### 1.7 Docker Compose 구현
- [ ] docker-compose.yml 작성 (platform, engagement, knowledge, learning-card, learning-ai, postgres, redis, kafka, zookeeper, schema-registry, elasticsearch)
- [ ] 각 서비스 health check 설정
- [ ] .env.example 전체 환경 변수 정리
- [ ] README에 실행 방법 문서화

### 1.8 동작 테스트
- [ ] `docker compose up` → 전체 서비스 Health OK (< 2분) 확인
- [ ] Schema Registry 접속 테스트 (http://localhost:8081)
- [ ] PostgreSQL + Redis + Kafka + ES 접속 확인
- [ ] 메모리 8GB 환경 동작 확인
- [ ] Apple Silicon(ARM) 호환 확인

### 1.9 N/A (인프라 — Controller 해당 없음)

### 1.10 N/A (인프라 — View 해당 없음)

**Step 2 Status**: [ ] Not Started / [ ] In Progress / [ ] Done

---

## Step 3: CI/CD 파이프라인 구성

### 1.1 TASK 시작
- [ ] Step Goal / Done When / Scope / Input 확인
- [ ] PRD_W1 해당 요구사항 확인 (CI/CD 파이프라인)
- [ ] Duration 산정 확인 (2일)

### 1.2 요구사항 분석
- [ ] mirror.yml 동기화 요건 분석
- [ ] ci.yml 빌드+테스트+lint 요건 분석
- [ ] deploy.yml ECR push + ArgoCD 연동 요건 분석
- [ ] Instructions 초안 → TASK 문서 반영

### 1.3 Security 1차 검토 (네트워크 보안)
- [ ] GitHub Secrets 관리 (AWS credentials, ECR URL, ArgoCD token)
- [ ] OIDC 연동 여부 검토 (GitHub Actions → AWS)
- [ ] 빌드 환경 시크릿 노출 방지
- [ ] 결과 → TASK Constraints 반영

### 1.4 인프라 아키텍처 설계
- [ ] CI/CD 파이프라인 흐름도 작성
- [ ] 트리거 조건 정의 (PR, push main)
- [ ] 환경별 배포 전략 (dev: auto, staging/prod: manual)
- [ ] Duration(final) 갱신

### 1.5 Security 2차 검토
- [ ] ECR 이미지 스캐닝 설정
- [ ] ArgoCD 토큰 최소 권한 확인
- [ ] 브랜치 보호 규칙 확인
- [ ] 결과 → TASK Constraints 반영

### 1.6 N/A (인프라 — DTO/Entity 해당 없음)

### 1.7 파이프라인 구현
- [ ] mirror.yml 작성 (on: push main → mirror sync)
- [ ] ci.yml 작성 (on: PR → gradle build + test + modulith verify)
- [ ] deploy.yml 작성 (on: push main → docker build → ECR push → gitops image tag patch)
- [ ] GitHub Secrets 설정

### 1.8 파이프라인 테스트
- [ ] dummy commit → mirror.yml 동작 확인
- [ ] PR 생성 → ci.yml 빌드+테스트 확인
- [ ] main push → deploy.yml ECR push + ArgoCD 동기화 확인
- [ ] CI 실행 시간 < 5분 확인

### 1.9 N/A (인프라 — Controller 해당 없음)

### 1.10 N/A (인프라 — View 해당 없음)

**Step 3 Status**: [ ] Not Started / [ ] In Progress / [ ] Done
