import flyway_guard as fg


def test_parse_version_integer():
    assert fg.parse_version("V28__allow_multiple_refresh_tokens.sql") == "28"


def test_parse_version_with_path():
    assert fg.parse_version("a/b/V20260605120000__rename.sql") == "20260605120000"


def test_parse_version_repeatable_is_none():
    assert fg.parse_version("R__refresh_view.sql") is None


def test_parse_version_non_migration_is_none():
    assert fg.parse_version("notes.sql") is None


def test_find_duplicates_flags_repeated_version():
    paths = ["a/V28__x.sql", "b/V28__y.sql", "c/V29__z.sql"]
    assert fg.find_duplicates(paths) == {"28": ["a/V28__x.sql", "b/V28__y.sql"]}


def test_find_duplicates_empty_when_unique():
    paths = ["a/V1__x.sql", "b/V2__y.sql"]
    assert fg.find_duplicates(paths) == {}


def test_find_duplicates_ignores_non_migrations():
    paths = ["a/V1__x.sql", "b/README.md", "c/R__view.sql"]
    assert fg.find_duplicates(paths) == {}


def test_is_timestamp_version_true_for_14_digits():
    assert fg.is_timestamp_version("20260605120000") is True


def test_is_timestamp_version_false_for_integer():
    assert fg.is_timestamp_version("28") is False


def test_is_timestamp_version_false_for_wrong_length():
    assert fg.is_timestamp_version("202606051200") is False  # 12자리


def test_is_timestamp_version_false_for_non_digits():
    assert fg.is_timestamp_version("2026060512000X") is False


def _make_migration(root, rel, content="-- sql\n"):
    import os
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


def test_main_passes_on_unique(tmp_path):
    _make_migration(str(tmp_path), "src/main/resources/db/migration/V1__a.sql")
    _make_migration(str(tmp_path), "src/main/resources/db/migration/V2__b.sql")
    assert fg.main(["--root", str(tmp_path)]) == 0


def test_main_fails_on_duplicate(tmp_path):
    _make_migration(str(tmp_path), "src/main/resources/db/migration/V28__a.sql")
    _make_migration(str(tmp_path), "src/main/resources/db/migration/V28__b.sql")
    assert fg.main(["--root", str(tmp_path)]) == 1


def test_main_ignores_build_dir(tmp_path):
    _make_migration(str(tmp_path), "src/main/resources/db/migration/V1__a.sql")
    _make_migration(str(tmp_path), "build/resources/main/db/migration/V1__a.sql")
    assert fg.main(["--root", str(tmp_path)]) == 0


import subprocess


def _git(root, *args):
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "-C", root, *args],
        check=True, capture_output=True,
    )


def _init_repo_with_base(tmp_path):
    root = str(tmp_path)
    _git(root, "init", "-q")
    _make_migration(root, "src/main/resources/db/migration/V1__base.sql")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "base")
    base = subprocess.run(
        ["git", "-C", root, "rev-parse", "HEAD"], capture_output=True, text=True
    ).stdout.strip()
    return root, base


def test_main_fails_when_new_migration_not_timestamp(tmp_path):
    root, base = _init_repo_with_base(tmp_path)
    _make_migration(root, "src/main/resources/db/migration/V2__bad.sql")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "add bad")
    assert fg.main(["--root", root, "--base-ref", base]) == 1


def test_main_passes_when_new_migration_is_timestamp(tmp_path):
    root, base = _init_repo_with_base(tmp_path)
    _make_migration(root, "src/main/resources/db/migration/V20260605120000__ok.sql")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "add ok")
    assert fg.main(["--root", root, "--base-ref", base]) == 0


def test_main_fails_when_merged_migration_modified(tmp_path):
    root, base = _init_repo_with_base(tmp_path)
    _make_migration(root, "src/main/resources/db/migration/V1__base.sql", content="-- changed\n")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "mutate base")
    assert fg.main(["--root", root, "--base-ref", base]) == 1
