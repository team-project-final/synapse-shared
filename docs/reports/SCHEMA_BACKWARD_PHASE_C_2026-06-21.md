# Schema BACKWARD 전토픽 전수 리포트 — W5 Day3

> 생성: `scripts/check-schema-backward-all.ps1` · FR-TL-302 · 9 subject 전수(미발행 cards-generated 포함)
> 정의: 호환=optional union+default 추가 / 비호환=required no-default 추가 (Avro BACKWARD)
> 레지스트리: http://localhost:8086

| Subject | avsc | compat 레벨 | 호환 프로브 | 비호환 프로브 | 결과 |
|---|---|---|---|---|---|
| platform.auth.user-registered-v1-value | src/main/avro/platform/UserRegistered.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |
| knowledge.note.note-created-v1-value | src/main/avro/knowledge/NoteCreated.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |
| knowledge.note.note-updated-v1-value | src/main/avro/knowledge/NoteUpdated.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |
| learning.card.review-completed-v1-value | src/main/avro/learning/ReviewCompleted.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |
| learning.card.review-due-v1-value | src/main/avro/learning/CardReviewDue.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |
| engagement.gamification.level-up-v1-value | src/main/avro/engagement/LevelUp.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |
| engagement.gamification.badge-earned-v1-value | src/main/avro/engagement/BadgeEarned.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |
| platform.notification.notification-send-v1-value | src/main/avro/platform/NotificationSend.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |
| learning.ai.cards-generated-v1-value | src/main/avro/learning/CardsGenerated.avsc | BACKWARD | accept ✅ | reject ✅ | PASS |

**합계**: 9/9 PASS
