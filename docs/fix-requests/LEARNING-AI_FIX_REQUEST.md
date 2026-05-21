# 수정 요청: learning-ai CrashLoopBackOff

> **작성일**: 2026-05-21
> **작성자**: @team-lead (인프라/GitOps)
> **대상**: learning-ai 담당자
> **우선순위**: High — dev 환경 배포 차단 중

---

## 증상

EKS `synapse-dev` namespace에서 `learning-ai` Pod가 **restart 반복** 상태.

```
상태: Progressing (ArgoCD)
Pod:  uvicorn 기동 후 종료 → restart 반복
```

## 근본 원인

Python uvicorn 서버가 기동 후 곧 종료됨. **서비스 코드 레벨 문제**로 판단됩니다.

가능한 원인 (확인 필요):
1. **Import error** — 필수 패키지 미설치 또는 버전 불일치
2. **환경변수 누락** — 필수 설정값이 없어 기동 실패
3. **DB/외부 서비스 연결 실패** — 연결 재시도 없이 즉시 종료
4. **포트 충돌 또는 바인딩 실패** — 컨테이너 내 포트 설정 불일치

## 인프라 측 이미 해결한 사항

| 항목 | 상태 |
|------|:----:|
| EKS Security Group → RDS/MSK/Redis/OpenSearch 접근 | ✅ |
| ExternalSecret → SecretSynced (시크릿 주입) | ✅ |
| liveness probe initialDelaySeconds 30s → 90s | ✅ (gitops PR #35) |
| ECR 이미지 pull 성공 | ✅ |

## 디버깅 가이드

### 1단계: 로그 확인

```bash
# EKS에서 직접 확인
kubectl logs -n synapse-dev -l app.kubernetes.io/name=learning-ai --tail=100

# 이전 크래시 로그
kubectl logs -n synapse-dev -l app.kubernetes.io/name=learning-ai --previous
```

### 2단계: 로컬 재현

```bash
# synapse-shared Docker Compose로 로컬 실행
cd synapse-shared
cp .env.example .env
docker compose up learning-ai

# 또는 서비스 레포에서 직접
cd synapse-learning-ai
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8085
```

### 3단계: 필수 환경변수 체크

ExternalSecret을 통해 주입되는 환경변수 목록:

| 변수 | 소스 |
|------|------|
| `DATABASE_URL` | AWS Secrets Manager |
| `KAFKA_BROKERS` | ConfigMap |
| `REDIS_HOST` | ConfigMap |
| `OPENAI_API_KEY` (해당시) | AWS Secrets Manager |

`kubectl exec` 또는 `kubectl describe pod`로 환경변수 주입 여부를 확인하세요.

### 4단계: Dockerfile 확인

```bash
# 컨테이너 내부 진입
kubectl exec -it -n synapse-dev <pod-name> -- /bin/sh

# Python 의존성 확인
pip list
python -c "from app.main import app; print('OK')"
```

## 요청 수정 사항

1. 위 디버깅 가이드를 따라 **크래시 원인 확인**
2. 원인에 따라 수정:
   - Import error → `requirements.txt` 또는 `pyproject.toml` 업데이트
   - 환경변수 → `application.yml` 또는 코드에서 기본값/fallback 추가
   - DB 연결 → retry 로직 또는 graceful startup 추가
3. 로컬에서 `docker compose up learning-ai` → health 엔드포인트 정상 응답 확인
4. PR 생성 → CI 통과 → main 머지

## 검증 방법

수정 후:

1. 로컬: `curl http://localhost:8085/health` → `{"status":"ok"}` 또는 유사 응답
2. EKS: ArgoCD 자동 배포 후 `kubectl get pods -n synapse-dev -l app.kubernetes.io/name=learning-ai` → Running, restarts 0
3. `bash scripts/verify-service-health.sh --env eks` → learning-ai PASS

## 기한

**W3 시작 전(05-25)까지** 수정 완료 요청합니다.
3/5 서비스는 이미 Healthy이며, 5/5 달성 후 staging 배포 + E2E 검증 진행 예정입니다.

---

*문의: @team-lead / synapse-shared 레포 이슈*
