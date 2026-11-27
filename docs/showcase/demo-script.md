# Narrated demo script

**Limit:** 3 minutes. Target 2 minutes 30 seconds. Base the recording on `showcase/src/showcase.adb`, which uses the RAM crash simulator.

## Recording sequence

### 0:00-0:15 - Strong result first

**[Show the actual end of a successful run: `showcase ok`.]**

This is the result we will explain: after a simulated torn record, Legder reopens the log, retains earlier valid data, rejects the damaged tail, and can append another record.

### 0:15-0:45 - One use case

Imagine a device storing a few settings. We open an empty store and write `alpha=1`, `beta=2`, update `alpha=11`, delete `beta`, and write `gamma=3`. These are illustrative test keys, not a deployed device configuration. Each operation is appended and synchronized before the in-memory table is updated.

### 0:45-1:20 - Normal recovery

We open the store again. Recovery scans records in sequence. The expected live values are `alpha=11` and `gamma=3`; `beta` is absent because its delete was committed. The showcase checks each result.

### 1:20-2:10 - Simulated torn write and recovery

The RAM device now deliberately corrupts the next block write. We attempt `delta=4`, reopen, and check that the invalid record is outside the recovered valid prefix. This is a **simulated torn write**, not a physical power cut. We then write `epsilon=5` at the recovered position.

### 2:10-2:30 - Final state and next step

The final reopen checks `alpha=11`, `gamma=3`, and `epsilon=5`, with `delta` absent. This demonstrates the RAM simulator's recovery scenario. Hardware testing and formal proofs remain future work.

**[Show presenter name and contribution; assign every member a confirmed contribution across the videos or live showcase.]**

## Reproduction

After installing Alire, from the `showcase` folder:

```powershell
alr -n build
alr -n run
```

Record actual output from a current run; do not fabricate a success screen.
