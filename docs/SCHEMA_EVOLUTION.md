# Schema Evolution Guide

## Backward Compatibility Rules

All Avro schema changes MUST maintain **backward compatibility** — new schema
can read data written by the old schema.

### Allowed Changes

| Change | Safe? | Notes |
|---|---|---|
| Add field with default | Yes | New readers get default for old data |
| Remove field with default | Yes | Old readers ignore missing field |
| Add enum symbol at end | Yes | Existing readers ignore new values |
| Widen numeric type | Yes | e.g. `int` → `long` |

### Forbidden Actions

- **Never** remove a field that has no default value
- **Never** rename a field (add new + deprecate old instead)
- **Never** change a field's type incompatibly (e.g. `string` → `int`)
- **Never** reorder enum symbols
- **Never** change a field's default value semantics

## PR Procedure

1. Create a feature branch from `main`
2. Modify `.avsc` files under `src/main/avro/`
3. Run `./gradlew build` to verify schema compilation
4. Open a PR with:
   - Before/after schema diff
   - Compatibility justification
   - List of affected consumers
5. Require at least **1 approval** from a schema owner
6. CI will run schema compatibility check automatically

## Schema Registry

Schemas are registered in Confluent Schema Registry with
`BACKWARD` compatibility mode. The CI pipeline validates
compatibility before merge.
