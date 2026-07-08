# Test suite

Automated tests for the ODRL Policy Authorizer. Requires **SWI-Prolog**
(`swipl`) on the `PATH`.

## Layout

| File | Level | What it covers |
| --- | --- | --- |
| `unit_tests.plt` | Unit | Individual `evaluator.pl` predicates: value normalization, datetime parsing/comparison, role/country/method membership, each constraint type, and world-state accessors. |
| `integration_tests.plt` | Integration + regression | Full `evaluate_policy/5` pipeline over the 10 predefined policy/world files. Expected outcomes mirror thesis Table 4.1, so the suite also acts as a regression guard. |
| `system_tests.pl` | System (end-to-end) | Black-box HTTP checks against a running `server.pl` (`/api/health`, plus a permitted and a denied `/api/evaluate`), exercising the deployed `evaluate_policy_dict/5` path. |
| `run_tests.sh` | Runner | Runs all three stages in order and returns a non-zero exit code on any failure (CI-friendly). |

## Running

Run everything (starts and stops the server automatically):

```bash
./test/run_tests.sh
```
OR: 
swipl -g "consult('test/unit_tests.plt'), run_tests"

Run only the in-process unit + integration/regression tests:

```bash
swipl -q -g "consult('test/unit_tests.plt'), \
             consult('test/integration_tests.plt'), \
             (run_tests -> halt(0) ; halt(1))"
```

Run only the end-to-end system test (needs a server on `localhost:8080`):

```bash
swipl server.pl &          # start the server
swipl -q -g "consult('test/system_tests.pl'), (system_test -> halt(0) ; halt(1))"
```

## Notes

- All paths are resolved relative to each test file, so the suites can be run
  from any working directory.
- The `datetime_parsing:compare_same_day_is_equal` test documents the current
  date-granularity behaviour (time-of-day is not yet compared).



