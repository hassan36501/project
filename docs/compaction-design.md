
# Log Compaction Design

## Purpose

The current log is append-only. Each committed operation is written to the next block, and the log becomes full when no blocks remain. Compaction reclaims space while preserving the latest value for each key.

The design uses two storage regions: **Region A** and **Region B**. At any time, one region is the active log and the other is the destination for the compacted log. The active region remains the recovery source until the new region is complete and the switch is committed.

## Storage layout

Each region contains:

- A sequence of log-record blocks.
- A region header containing its generation number and state.
- A completion marker written only after all compacted records have been written and synchronized.

The header states are `EMPTY`, `BUILDING`, and `ACTIVE`. A region is eligible for recovery only if its header and completion marker are valid. The generation number identifies which completed region is newer.

The exact block layout and header encoding will be defined in the implementation. Header and record formats must include integrity checks so incomplete writes can be rejected during recovery.

## Compaction procedure

1. Select the inactive region as the destination. Do not modify the active region.
2. Mark the destination `BUILDING` and synchronize it.
3. Read the current active log and replay its committed records in order.
4. Write one `Put` record for each live key in the reconstructed store. Deleted keys are omitted. Preserve the key-value contents; assign a valid consecutive sequence to the compacted records.
5. Synchronize the destination records.
6. Write and synchronize the destination’s completion marker and generation.
7. Mark the destination `ACTIVE` and synchronize it. This is the commit point of the switch.
8. Only after the new region is recoverably active may the old region be marked `EMPTY` or reused.

The implementation must ensure that ordinary writes cannot race with compaction. The first version can require exclusive access to the store during compaction.

## Recovery and failure cases

Recovery validates both regions and selects the newest region that has a valid `ACTIVE` state and completion marker. A region still marked `BUILDING` is incomplete and must not replace the previous active region.

- **Failure before compaction begins:** The original active region remains authoritative. Recovery opens it normally.
- **Failure while writing the destination:** The destination is incomplete and ignored. Recovery uses the original active region.
- **Failure after destination records are synchronized but before the completion marker:** The destination is still incomplete. Recovery uses the original active region.
- **Failure after the completion marker but before the switch is committed:** Recovery follows the recorded state and generation rules. The old region remains authoritative unless the destination has a valid committed `ACTIVE` state.
- **Failure after the switch is committed but before the old region is erased:** Recovery selects the new active region. The old region may remain on disk but is not selected.
- **Failure while erasing or reusing the old region:** The new active region remains authoritative. The old region is not needed for recovery.

The switch must never leave recovery with neither a valid old region nor a valid new region.

## Correctness conditions

The implementation and tests must establish that:

1. The old active region is not overwritten before the new region is committed.
2. The destination is not considered active until its records and completion metadata are synchronized.
3. Recovery selects a complete committed region, not a partially written destination.
4. The compacted contents represent the same live key-value mapping as replaying the original committed log.
5. A failed compaction does not change the logical contents of the store.

## Verification plan

Add fault-injection tests for failures before destination creation, during record copying, after record synchronization, during the switch, and while reclaiming the old region. After each simulated failure, reopen the store and compare its contents with the reference key-value model.

The compaction implementation is not considered complete until these tests pass and the recovery and switch invariants are documented alongside the implementation.
