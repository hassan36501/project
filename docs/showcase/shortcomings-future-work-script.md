# Shortcomings and future work video script

**Limit:** 3 minutes. Target about 2 minutes 15 seconds.

## Recording script

Legder is a prototype, and we want to be clear about what it does not yet establish.

First, the log is append-only. When the device fills, another append fails. We have a compaction design note, but compaction is not implemented. Next, we should implement the two-region switch and add fault-injection tests for failures throughout that switch.

Second, the file-backed device is for desktop testing. The repository does not include a board-specific SD or flash driver, and we have not demonstrated recovery after a physical power cut on hardware. A next step is to select a board and verify what its write and sync operations actually guarantee.

Third, CI runs tests and GNATprove flow analysis. It does not complete the deductive proof goals for record bounds, record round trip, log recovery, or the store's logical meaning. Passing tests and flow analysis are not the same as those proofs. Their status is listed in `docs/proof-status.md`.

The current version commits one operation at a time; it does not offer multi-operation transactions, concurrency, wear levelling, or bad-block handling. Its crash behavior also depends on the device honoring its write and sync contract.

**Draft responsible AI disclosure:** ChatGPT assisted with CI troubleshooting and drafting project documentation. Before publishing, the team must confirm its full AI use and review the technical suggestions against repository source, tests, course guidance, and actual GitHub Actions results. We do not describe unproved goals as proved.

Our technical sources are the project README, architecture and plan, Ada/SPARK source and tests, the compaction design note, and the linked GitHub Actions run. Course deliverables guidance supplied to the team is the source for video and submission rules. **[Before recording, confirm whether other team members used additional AI tools and update this disclosure if needed.]**

## Shot checklist

- Show one shortcoming at a time, with its matching next step.
- Show the proof-status table; do not present a passing flow check as a completed deductive proof.
- End with the AI-use/source statement above.
