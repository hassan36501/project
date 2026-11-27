# Legder — Final Report, Proof Summary & Test Results

## 1. Project Summary

Legder is a bounded, crash-safe key-value storage engine written in Ada/SPARK with no heap allocation and no access types. Every operation writes a fixed 512-byte CRC32-protected record to a write-ahead log (`Legder.Log`) and synchronizes storage (`Sync`) **before** updating the in-memory index (`Legder.Store`).

### Key Deliverables Implemented

- **Sorted Array Index (`Legder` / `Legder.Store`):** Replaced the linear-scan placeholder with a sorted array and binary search (`Find`, `Insert_At`), backed by a lexicographic `"<"` operator on live `Key` bytes. The `Append -> Sync -> Apply` commit order is unchanged.
- **File-Backed Block Device (`devices/file/`):** Implemented `Read`, `Write`, and `Sync` over a 1024-block (512 KiB) file with `16#FF#` erased-block semantics and real OS durability (`fsync` on POSIX, `_commit` on Windows via `fsync_shim.c`), plus `file_demo`, `crash_writer`, and `crash_test.sh`.
- **Extended Test Suite & Reference Oracle (`tests/src/tests.adb`):** Added tests for wrong sequence numbers, deleting absent keys, maximum-size records (32-byte key, 256-byte value), dropped unsynced writes, and a `Ref_Map` oracle comparing `Legder.Store` against a reference key-value map across insertions, overwrites, deletions, and reopen.
- **SPARK Contracts & Ghost Model:** Added buffer-safety invariants (R2), field-level round-trip ghost helpers (R1), recovery prefix loop invariant (L1), and store ghost model (`Has_Key`, `Get_Value`) with `Post` contracts on `Put`, `Delete`, and `Get` (S1).
- **Compaction Design Note (`compaction_design.md`):** Documented a two-region compaction architecture with alternating ping-pong headers and power-loss analysis before, during, and after the atomic switch.
- **Hardware Target (Scope Note):** Physical board bring-up (SD over SPI or internal flash) was not implemented because no physical target board/driver was available in this environment.

---

## 2. SPARK Proof Summary

Executed with GNATprove 16.1.0 (`gnatprove -P legder.gpr`):

- **Flow Analysis (`--mode=flow --checks-as-errors=on`):** **Passed** (`Success: all checks proved (22 checks)`).
- **Full Proof (`--mode=all --level=1`):**

| Property | Status | Details & Remaining Obligations |
|---|---|---|
| **R2** — Record buffer index safety | **Proved** | All array index and range checks in `Legder.Record_Format` (`Encode` / `Decode`) discharged using offset `Assert`s and loop invariants. |
| **R1** — Record round trip | **Partial** | Documented field-level equality decision (excluding padding/ignored fields). `Encode` postcondition `Block_Valid_Structure (B)` has 1 unproved obligation: `Get_U32 (B, Off_Magic) = Magic` (requires frame/value postconditions on `Put_U32`). |
| **L1** — Recovery prefix | **Partial** | Added `Seq = Sequence (I)` loop invariant in `Legder.Log.Open` and documented `Scan`'s single-writer assumption. Generic body proof requires instantiation. |
| **S1** — Store logical meaning | **Partial** | Added `Has_Key` / `Get_Value` ghost functions and `Post` contracts on `Put`, `Delete`, `Get`. `Open` postcondition and generic body proof remain open. |

*(Pre-existing note: `Legder.RAM_Device` reports 2 `N_Writes + 1` / `N_Syncs + 1` overflow check warnings under `--mode=all`.)*

---

## 3. Test Results

All Ada builds compile with `-gnat2022 -gnata -gnatwa -gnatwe -gnatVa -gnatyg -gnatyM100`.

| Suite / Command | Result | What Was Verified |
|---|---|---|
| `tests/bin/tests.exe` | **PASS** (`all tests passed`) | CRC32 vectors, record encode/decode & corruption rejection, log recovery, torn writes, stale blocks, wrong sequence, delete absent key, max-size record, `Drop_Unsynced`, capacity refusal, and `Test_Reference_Map` oracle |
| `showcase/bin/showcase.exe` | **PASS** (`showcase ok`) | Write, reopen, `Tear_Next_Write` crash simulation, recovery of committed prefix, reuse of torn block, final reopen |
| `devices/file/bin/file_demo.exe` | **PASS** (`file demo ok`) | File device write, close, reopen/recovery, and S3 256-entry table capacity refusal over a 1024-block file |
| `devices/file/crash_test.sh` | **CI / Bash** | Repeatable `SIGKILL` mid-write test followed by `file_demo` recovery check (targets Linux/Git Bash; `SIGKILL` tests process crash, not physical power cut) |

---

## 4. How to Run the Demonstration

### Build & Run All Checks (Windows PowerShell with Alire Toolchain)

```powershell
$env:PATH = "C:\Users\AKRAM\AppData\Local\alire\cache\toolchains\gnat_native_16.1.0_bbd69633\bin;C:\Users\AKRAM\AppData\Local\alire\cache\toolchains\gprbuild_26.0.1_68a6817f\bin;C:\Users\AKRAM\AppData\Local\alire\cache\releases\gnatprove_16.1.0_f3c62ad9\bin;" + $env:PATH

gprbuild -P legder.gpr -p
gprbuild -P tests\legder_tests.gpr -p; .\tests\bin\tests.exe
gprbuild -P showcase\legder_showcase.gpr -p; .\showcase\bin\showcase.exe
gprbuild -P devices\file\legder_file_demo.gpr -p; .\devices\file\bin\file_demo.exe
gnatprove -P legder.gpr --mode=flow --checks-as-errors=on
gnatprove -P legder.gpr --mode=all --level=1
```

### Build & Run on Linux / CI (Alire)

```sh
alr -n build
(cd tests && alr -n build && ./bin/tests)
(cd showcase && alr -n build && alr -n run)
(cd devices/file && alr -n build && ./bin/file_demo && bash ./crash_test.sh)
alr -n exec -- gnatprove -P legder.gpr --mode=flow --checks-as-errors=on
```
