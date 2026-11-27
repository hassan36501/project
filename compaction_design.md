# Legder Compaction Design Note

## 1. Problem Statement

Legder's current write-ahead log (`Legder.Log`) is strictly append-only across `0 .. Block_Count`. Every `Put` and `Delete` appends a new 512-byte record at `Head`. Once `Head > Block_Count`, `Is_Full` becomes true and all subsequent `Put` and `Delete` operations fail—even if most keys have been overwritten or deleted and only a small number of live keys remain in `Legder.Store`.

Compaction reclaims space by writing a fresh log containing only the current live key-value pairs, discarding obsolete overwrites and tombstones (`Delete` records), and then recycling the old log space.

---

## 2. Two-Region Design

To keep crash safety intact during compaction, the device is divided into two equal data regions plus a small metadata header:

```text
+------------------+---------------------------+---------------------------+
| Header (Blk 0-1) | Region A (Blocks 2 .. M)  | Region B (Blocks M+1 .. N)|
| Active + Epoch   | Active or Standby WAL     | Standby or Active WAL     |
+------------------+---------------------------+---------------------------+
```

- **Region A** and **Region B** each have capacity for at least `Max_Entries` (256) records so either region can hold a full live table.
- At any point, exactly one region is **authoritative** (the active WAL receiving normal `Put`/`Delete` appends).
- The other region is **standby** (free to be overwritten during the next compaction).

### Compaction Lifecycle

```text
  [Normal Writes to Active Region]
                 |
       (Active region near full)
                 v
  [Write live entries to Standby Region]  (Seq = 1 .. Live_Count)
                 |
         [Sync Standby Region]
                 v
  [Write Switch Marker (Header) + Sync]   <-- Atomic commit point
                 |
                 v
  [Standby becomes Active; Old Active becomes Standby]
```

1. **Trigger:** When the active region approaches capacity (e.g., `Head` reaches a high-water mark or `Append` reports full), compaction begins.
2. **Copy live state:** Iterate through the sorted in-memory table (`Table (1 .. Live)`). Encode each live `(K, V)` pair as a `Put` record with fresh consecutive sequence numbers `1, 2, ..., Live`, and write them sequentially into the standby region.
3. **Sync data:** Call `Sync` to guarantee all records in the standby region are durable before touching the switch marker.
4. **Atomic switch:** Write a single 512-byte header block identifying the new authoritative region and incremented `Epoch`, protected by a CRC32 checksum, and call `Sync`.

---

## 3. The Switch Mechanism

Two standard mechanisms can identify the authoritative region:

| Mechanism | How it works | Trade-offs |
|---|---|---|
| **A. Dedicated Header Block (or Ping-Pong Header Pair)** | Block 0 (or Blocks 0 and 1 alternating) stores `{Magic, Epoch, Active_Region, CRC}`. Switching writes one header block and calls `Sync`. | Simple, O(1) lookup on `Open`. Using two alternating header blocks (0 and 1) prevents a torn header write from destroying the previous valid header. |
| **B. Region Epoch in First Record** | Each region's first record carries an `Epoch` counter. On `Open`, read block 0 of both regions and pick the one with the higher valid `Epoch`. | Avoids a separate header block, but requires scanning or validating the new region before trusting its epoch; if the new region is only partially written, an epoch in block 0 could be misleading unless written *last*. |

**Recommended choice:** **Two alternating header blocks (Block 0 and Block 1)** with `(Magic, Epoch, Active_Region, CRC)`. Because a block write is atomic or torn (caught by CRC), writing to the *older* header slot ensures at least one valid header block always survives a crash.

---

## 4. Power Failure Analysis

Assume the fault model: a single block write may be torn (detected by CRC), writes before `Sync` are durable, and writes after `Sync` may vanish.

1. **Power fails BEFORE the switch (during standby region write):**
   - The alternating header still points to the old active region with the old `Epoch`.
   - The partially written standby region is ignored completely on `Open`.
   - **Result:** Recovery scans the old active region and restores the exact pre-compaction state. Zero data loss.

2. **Power fails DURING the switch (while writing the new header block):**
   - The new header block is either absent, torn (fails CRC), or fully written.
   - Because we wrote to the *other* header slot (e.g., Block 1 while Block 0 holds the previous valid header):
     - If the new header is torn/absent: Block 0 is still valid and has the highest valid `Epoch`. Recovery uses the old active region.
     - If the new header is fully written and valid: all standby records were already `Sync`ed in step 3, so the new region is complete and consistent. Recovery uses the new region.
   - **Result:** Either the old state or the identical compacted new state is recovered. Never a half-compacted mix.

3. **Power fails AFTER the switch (`Sync` returned):**
   - The new header block is durable and has the higher `Epoch`.
   - Recovery selects the new region and scans its `1 .. Live` records.
   - **Result:** Recovery restores the exact compacted state. The old region is now safe to reuse as standby.

---

## 5. Changes to Recovery (`Legder.Log.Open`)

Currently, `Legder.Log.Open` starts unconditionally at block `0` and expects `Seq = 1`. With two-region compaction:

1. **Read headers:** Read Block 0 and Block 1, decode both, and validate their CRCs.
2. **Select region:** Pick the valid header with the highest `Epoch`. If neither is valid (freshly erased device), initialize `Active_Region = A`, `Epoch = 1`, `Head = 0`.
3. **Scan active region:** Scan consecutive blocks starting at the selected region's base offset (`Base_A` or `Base_B`), checking `Valid` and `Seq = previous + 1` starting from `1`, stopping at the first invalid block or sequence gap.
4. **Replay:** `Legder.Store.Open` replays the accepted prefix as before.

---

## 6. Invariants Preserved

- **Log-before-table:** Normal `Put`/`Delete` operations still follow `Encode -> Write -> Sync -> Apply`.
- **Logical equivalence:** Compaction is a logical no-op on `Model (S)` — the map of live keys to values before and after compaction is identical.
- **Prefix property:** Within the authoritative region, the accepted records form a contiguous valid prefix `Seq = 1 .. K`.

---

## 7. Remaining Work for Implementation

- **Region sizing:** Partition `Block_Count` into 2 header blocks + two equal regions `(Block_Count - 1) / 2` blocks each (requires `Block_Count >= 2 * Max_Entries + 2`).
- **Compaction trigger:** Decide whether to compact proactively (e.g., at 80% region capacity) or on-demand when `Is_Full` is reached during `Put`/`Delete`.
- **Testing:** Extend `RAM_Device` fault-injection tests to tear blocks during standby copy, during header switch, and after header switch.
- **SPARK proof:** Extend L1 to prove that `Open` selects the valid header with maximum `Epoch` and scans only that region's valid prefix.
