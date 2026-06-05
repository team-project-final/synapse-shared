#!/usr/bin/env python3
"""Flyway migration guard.

검사 항목:
  1) 동일 버전 토큰을 쓰는 마이그레이션 파일이 2개 이상이면 실패(중복 버전).
  2) (base-ref 제공 시) 이번 변경에서 '추가'된 마이그레이션은 14자리 타임스탬프 버전이어야 함.
  3) (base-ref 제공 시) 이미 머지된 마이그레이션 파일의 수정/삭제는 실패(불변성).
"""
import argparse
import os
import re
import subprocess
import sys

VERSION_RE = re.compile(r"^V(.+?)__.*\.sql$")


def parse_version(filename):
    """Flyway versioned 마이그레이션 파일명에서 버전 토큰을 반환. 아니면 None."""
    base = os.path.basename(filename)
    m = VERSION_RE.match(base)
    if not m:
        return None
    return m.group(1)


def find_duplicates(paths):
    """version 토큰 -> 정렬된 경로 리스트. 2회 이상 쓰인 버전만 포함."""
    by_version = {}
    for p in paths:
        v = parse_version(p)
        if v is None:
            continue
        by_version.setdefault(v, []).append(p)
    return {v: sorted(ps) for v, ps in by_version.items() if len(ps) > 1}


TIMESTAMP_LEN = 14


def is_timestamp_version(token):
    """14자리 숫자(yyyyMMddHHmmss)면 True."""
    return token.isdigit() and len(token) == TIMESTAMP_LEN


EXCLUDE_DIRS = {".git", "build", "out", "target", "node_modules", "_mirror", ".gradle"}


def is_migration_path(path):
    return "db/migration" in path.replace(os.sep, "/")


def scan_migrations(root):
    """root 아래 db/migration 경로의 V*.sql 마이그레이션 상대경로 목록(빌드 산출물 제외)."""
    found = []
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for f in files:
            if f.startswith("V") and f.endswith(".sql"):
                rel = os.path.relpath(os.path.join(dirpath, f), root)
                if is_migration_path(rel):
                    found.append(rel.replace(os.sep, "/"))
    return found


def changed_migrations(root, base_ref):
    """(status, path) 리스트. db/migration 경로의 V*.sql 변경만."""
    out = subprocess.check_output(
        ["git", "-C", root, "diff", "--no-renames", "--name-status", base_ref, "HEAD"],
        text=True,
    )
    result = []
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        status, path = parts[0], parts[-1]
        base = os.path.basename(path)
        if base.startswith("V") and base.endswith(".sql") and is_migration_path(path):
            result.append((status, path))
    return result


def main(argv=None):
    ap = argparse.ArgumentParser(description="Flyway migration guard")
    ap.add_argument("--root", default=".")
    ap.add_argument("--base-ref", default=None)
    args = ap.parse_args(argv)

    errors = []
    migrations = scan_migrations(args.root)
    for version, paths in sorted(find_duplicates(migrations).items()):
        errors.append(
            "[duplicate-version] version {} used by: {}".format(version, ", ".join(paths))
        )

    if args.base_ref:
        for status, path in changed_migrations(args.root, args.base_ref):
            version = parse_version(path)
            if status.startswith("A"):
                if version is not None and not is_timestamp_version(version):
                    errors.append(
                        "[non-timestamp-new] 추가된 마이그레이션은 14자리 타임스탬프 버전이어야 함: "
                        "{} (got V{})".format(path, version)
                    )
            elif status.startswith("M") or status.startswith("D"):
                errors.append(
                    "[mutated-migration] 이미 머지된 마이그레이션 변경({}): {}".format(status, path)
                )

    if errors:
        print("Flyway guard FAILED:")
        for e in errors:
            print("  - " + e)
        return 1
    print("Flyway guard OK ({} migrations, no violations).".format(len(migrations)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
