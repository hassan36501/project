# legder

A crash-safe transactional storage engine you can prove correct.
Fixed block device underneath, write-ahead log in the middle, a
bounded key-value store on top. Ada/SPARK, no heap, no access types.

GNAT Academic Program capstone project. Proposal title: *Legder:
Embedded Transactional Storage Engine*.

## What it is

Every embedded product that keeps settings, counters or logs across
power cycles has one of these, usually hand-rolled and usually wrong
the first three times. The failure is always the same: power goes at
the wrong moment and the device comes back with half a record.

legder's claim is small and provable: **after any crash, what you read
back is exactly the set of operations that had been acknowledged, in
order, and nothing else.**

The mechanism:

- One record per device block. A block write is atomic or torn; a
  torn block fails its CRC.
- Every record carries the next sequence number. Recovery reads
  blocks in order and stops at the first block that is not a valid
  record with sequence = previous + 1.
- Put and Delete write the record and sync *before* touching the
  in-memory table. The table is always a replay of the log.

## What is in the repository

```
src/legder.ads                Byte, Block, Key ("=" & "<"), Value, Sequence, CRC
src/legder-record_format.ads  the on-disk record, Encode/Decode with CRC, R1/R2 annotations
src/legder-log.ads            generic WAL: Open (recover), Append, Scan, L1 invariant
src/legder-store.ads          generic KV store: sorted array + binary search, ghost model
src/legder-ram_device.ads     in-memory device with crash injection
devices/file/                 file-backed block device (fsync/_commit), file_demo, crash_test.sh
showcase/                     write, tear a block, recover, check (RAM acceptance test)
tests/                        unit tests incl. CRC vectors, crash cases, reference map oracle
compaction_design.md          two-region log compaction design note
FINAL_REPORT.md               proof summary, test results, and demonstration guide
```

Everything compiles with warnings as errors, the crash and reference-map tests pass, and the store uses a sorted array with binary search while preserving the `Append -> Sync -> Apply` commit order.

Read `ARCHITECTURE.md` before touching anything.

## Build

Alire crates (`legder`, `showcase`, `tests`, `devices/file`); `showcase`, `tests`, and `devices/file` pin the library by path.

```
alr build                       # library
cd showcase && alr build && alr run
cd tests && alr build && ./bin/tests
cd devices/file && alr build && ./bin/file_demo
alr with gnatprove && alr exec -- gnatprove -P legder.gpr --mode=flow --checks-as-errors=on
```

Contracts are checked at runtime in every build (`-gnata`).

## Rules of the road

- Warnings are errors, style checks on, CI on every push.
- `src/` is SPARK. Devices other than RAM live in `devices/<name>/`
  and are the only place `SPARK_Mode => Off` is allowed.
- Never write to the table before the log has synced. That is the
  invariant. A change that breaks it is wrong however fast it is.
- The fault model is: one block may be torn, writes before the last
  Sync are durable, writes after it may vanish. A device that cannot
  promise that is not a legder device; put a translation layer under it.

See `CONTRIBUTING.md` for the fork workflow.

## Contact

Olivier Henley, GAP Coordinator, AdaCore. Weekly meeting, plus the
project Discord.

## License

Apache-2.0. See `LICENSE`.
