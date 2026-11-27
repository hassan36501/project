# One-page poster copy and layout

**Required size:** portrait 36 x 48 inches or landscape 48 x 36 inches. This content is drafted for portrait. Replace bracketed credits and review the final layout before export/submission.

## Header

**LEGDER**<br>
Crash-aware key-value storage in Ada/SPARK

**Team:** [TEAM NAME]<br>
**Members:** [MEMBER 1] | [MEMBER 2] | [MEMBER 3] | [MEMBER 4]<br>
**Product Owner / sponsor:** [CONFIRMED NAME AND ROLE]

## Problem

Small embedded systems need to preserve settings and counters through restarts. A write interrupted at the wrong time can leave a partial record and uncertain state.

## Approach

Legder stores one operation per fixed 512-byte block. Each record has a sequence number and CRC. A Put or Delete is appended and synchronized before the in-memory table is updated. On reopening, the store scans the log in order and rebuilds its table from the valid consecutive prefix.

**Architecture:** Application -> bounded Store -> append-only Log -> 512-byte Record Format + CRC -> RAM or desktop file device.

## Demonstrated behavior

- Bounded key-value operations: Put, Delete, Get, and Count.
- Sorted fixed-size table with binary-search lookup.
- RAM device fault injection for torn and unsynchronized writes.
- Desktop file-device write, sync, reopen, and persistence checks.
- CI on Ubuntu builds the library and runs tests, showcases, file-device checks, and SPARK flow analysis.

## What the evidence means

The demo simulates a torn write in RAM; it is not a physical power cut. CI flow analysis and passing tests do not establish the remaining deductive proof goals. There is no board-specific storage driver, and log compaction is designed but not implemented.

## Next work

1. Complete and record GNATprove proof results for R1, R2, L1, and S1.
2. Select a board and validate its storage and sync guarantees.
3. Implement and fault-test log compaction.

## Footer

**Sources:** repository and course capstone deliverables guidance. **Draft AI disclosure:** ChatGPT assisted CI troubleshooting and draft documentation. Before submission, the team must confirm full AI use and review technical statements against code, tests, course guidance, and CI results.
**Repository:** https://github.com/hassan36501/project
