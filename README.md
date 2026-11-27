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

## Implemented components and current limits

```
src/legder.ads                Byte, Block, Key, Value, Sequence, CRC          done
src/legder-record_format.ads  the on-disk record, Encode/Decode with CRC     done
src/legder-log.ads            generic WAL: Open (recover), Append, Scan      done
src/legder-store.ads          generic KV store on the log                    implemented; sorted-array index
src/legder-ram_device.ads     in-memory device with crash injection          done
devices/file/                 file-backed block device and test/showcase     implemented
showcase/                     RAM-device write, crash, and recovery demo      implemented
tests/                        record, log, store, index, and model tests       implemented
```

The store uses a sorted fixed-size array with binary-search lookup. The
log is append-only and has no compaction: once its device is full, an
append fails. The file device is a desktop implementation; this
repository does not currently include a board-specific device or a
hardware power-loss demonstration. The RAM crash simulator and the
file-device tests cover different scenarios and should not be treated
as proof of physical-device durability.

The current CI workflow builds the library, runs the test and showcase
programs, runs file-device tests, installs GNATprove, and runs SPARK
flow analysis. A successful flow analysis does not mean that the
deductive proof milestones R1, R2, L1, or S1 have been discharged. See
[`docs/proof-status.md`](docs/proof-status.md) for the recorded status
and required follow-up.

Read `ARCHITECTURE.md` before touching anything.

## Development goals

1. **Prove the record format.** Run `Legder.Record_Format` under
   `gnatprove --mode=all`: index safety (R2) and, if you can, the
   round trip (R1). First real proof, small package.
2. **Hardware device.** Implement Read/Write/Sync over a selected SD or
   flash target and demonstrate recovery on that hardware. The desktop
   file device exists; the hardware target remains future work.
3. **Compaction.** The design is documented in
   [`docs/compaction-design.md`](docs/compaction-design.md), but the
   implementation is future work and is not part of the current scope.
4. **Prove S1.** State the store's meaning as a ghost functional map
   and prove Put, Delete and Open against it. The year's headline.

## Build

Three [Alire](https://alire.ada.dev) crates; showcase and tests pin
the library by path.

```
alr build                       # library
cd showcase && alr build && alr run
cd tests && alr build && ./bin/tests
alr with gnatprove && alr exec -- gnatprove -P legder.gpr --mode=flow
```

For the desktop file-device checks, see the `File device tests` step in
`.github/workflows/ci.yml` for the commands and temporary working
directory setup.

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
