#!/usr/bin/env python3
"""Flyway migration guard.

검사 항목:
  1) 동일 버전 토큰을 쓰는 마이그레이션 파일이 2개 이상이면 실패(중복 버전).
  2) (base-ref 제공 시) 이번 변경에서 '추가'된 마이그레이션은 14자리 타임스탬프 버전이어야 함.
  3) (base-ref 제공 시) 이미 머지된 마이그레이션 파일의 수정/삭제는 실패(불변성).
"""
import os
import re

VERSION_RE = re.compile(r"^V(.+?)__.*\.sql$")


def parse_version(filename):
    """Flyway versioned 마이그레이션 파일명에서 버전 토큰을 반환. 아니면 None."""
    base = os.path.basename(filename)
    m = VERSION_RE.match(base)
    if not m:
        return None
    return m.group(1)
