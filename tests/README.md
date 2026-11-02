# IceWarp Health Agent — tests/

Unit tests for the pure-logic helpers. They source the agent's own libraries,
so they exercise the real code, not a copy.

## Run

    ./tests/run_tests.sh

The runner is plain Bash and needs no test framework. It prints one line per
case (`ok` / `FAIL`) and exits non-zero on the first failure. It is designed to
run on a machine that has `bash`, `awk` and `date` — the same toolset the
agent itself requires — and **no** IceWarp `tool.sh`, no live DNS and no
network access.

## Cases

| File | What it covers |
|------|----------------|
| `test_norm_date.sh` | `norm_date` for ISO, IceWarp D-M-YY, Windows M/D/YYYY, and the unparseable cases that must not be silently turned into a date |
| `test_json_value.sh` | `_json_value` / `_json_force_string` coercion: numbers, booleans, nulls, escaped strings and the identifier keys (`*.name`, license, `*.ip`) |
| `test_health_rollup.sh` | `evaluate_health` pillar roll-ups and `health.summary.*` from a sample `DATA[]` set |
| `test_starttls.sh` | fake-SMTP STARTTLS host selection: `MAIL_HOSTNAME` wins, otherwise the primary domain's MX target, never the first mail domain |

## Fixtures

`fixtures/` holds canned `DATA[]` snapshots (one per case) so a test is
self-contained and repeatable. Add a new case by dropping a fixture file in
`fixtures/` and a `test_*.sh` in this directory.