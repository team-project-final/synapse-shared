import flyway_guard as fg


def test_parse_version_integer():
    assert fg.parse_version("V28__allow_multiple_refresh_tokens.sql") == "28"


def test_parse_version_with_path():
    assert fg.parse_version("a/b/V20260605120000__rename.sql") == "20260605120000"


def test_parse_version_repeatable_is_none():
    assert fg.parse_version("R__refresh_view.sql") is None


def test_parse_version_non_migration_is_none():
    assert fg.parse_version("notes.sql") is None
