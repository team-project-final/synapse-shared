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
