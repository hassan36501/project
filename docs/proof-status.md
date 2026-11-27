# Verification and proof status

Last reviewed: 2026-11-27

## Verified CI run

GitHub Actions run [CI #21](https://github.com/hassan36501/project/actions/runs/46051110227)
for commit `d2428db` completed successfully. It built the library, ran
the test and RAM showcase programs, ran the file-device tests, installed
GNATprove, and completed the workflow's SPARK flow-analysis step.

This verifies the checks present in that workflow at that commit. The
SPARK step runs `alr -n gnatprove --mode=flow --checks-as-errors=on`;
it is not a `--mode=prove` or `--mode=all` run. Therefore this CI result
must not be reported as discharging the formal proof goals below.

## Formal goals

| Goal | Meaning in the project plan | Status established by available evidence |
|---|---|---|
| R2 | Prove record encode/decode buffer index safety | **Not established.** CI runs flow analysis only; no deductive proof result was reviewed. |
| R1 | Prove meaningful-field round-trip behavior for encode/decode | **Not established.** No deductive proof result was reviewed. |
| L1 | Prove recovery accepts only the valid consecutive log prefix | **Not established.** No deductive proof result was reviewed. |
| L2/L3 | Model and prove device durability/crash behavior | **Not established; outside the stated Fall 2026 scope.** RAM/file tests are tests, not a device-model proof. |
| S1 | Prove `Put`, `Delete`, and `Open` preserve the store's logical map | **Not established.** The executable reference-model tests are useful validation but are not a formal proof. |

“Not established” means this repository review and the recorded CI run
do not provide the proof evidence needed to mark the goal complete. It
does not claim that GNATprove could not prove it. To update a row to
“proved”, run the applicable GNATprove proof mode, review the output for
the relevant units and checks, and record the exact command and result.

## Other project completion notes

- The sorted-array lookup and binary-search tests are implemented. Older
  README/architecture statements calling the index a linear-scan
  placeholder have been corrected.
- A desktop file-backed device and CI tests for it are present. CI tests
  exercise file reads/writes and persistence across program invocations;
  they do not demonstrate a real board, power cut, or hardware
  durability guarantee.
- The log remains append-only. Compaction has a design note but no
  implementation, as specified by the project plan's scope.
- The repository has no board-specific SD or flash device, so the
  hardware demonstration goal remains open.

## Reproduce the current CI checks

Use the workflow at `.github/workflows/ci.yml`. In particular, its
formal-analysis command is:

```sh
alr -n gnatprove --mode=flow --checks-as-errors=on
```

For a deductive proof status, invoke and review the corresponding
`gnatprove --mode=prove` or `--mode=all` result separately. Do not infer
proof completion from passing tests or flow analysis.
