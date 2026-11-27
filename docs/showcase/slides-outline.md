# Slide deck outline

Use this content outline for the My Showcase slides. Replace speaker placeholders with actual assignments. Keep the technical claims consistent with the repository and `../proof-status.md`.

## Slide 1 - Legder

- Crash-aware key-value storage in Ada/SPARK
- Team: [TEAM NAME]
- Members: [FOUR EXACT NAMES]
- Product Owner / sponsor: [CONFIRMED NAME AND ROLE]
- Speaker: [MEMBER]

## Slide 2 - Interrupted writes

- Embedded devices keep settings and counters across restarts.
- A partial write can leave a record invalid.
- Recovery needs a clear rule for which data to accept.
- Speaker: [MEMBER]

## Slide 3 - Storage path

- Application calls bounded Store operations.
- Store appends a fixed-size record to the log.
- Record format includes a sequence number and CRC.
- Device interface supplies Read, Write, and Sync.
- One operation is one commit; this is not a multi-operation transaction system.
- Speaker: [MEMBER]

## Slide 4 - Commit and recovery

- Commit order: encode -> write -> sync -> update table.
- Recovery accepts valid records with consecutive sequence numbers.
- Store is rebuilt by replaying the accepted prefix.
- Speaker: [MEMBER]

## Slide 5 - Demo and test evidence

- RAM showcase exercises replay and a simulated torn write.
- File-device tests check write/sync/reopen persistence on a desktop.
- Binary-search tests cover first, middle, last, update, and delete cases.
- GitHub Actions on `5c2fe92` passed the checks configured in CI.
- Speaker: [MEMBER]

## Slide 6 - Team contributions

- [MEMBER 1 NAME]: [CONFIRMED CONTRIBUTION]
- [MEMBER 2 NAME]: [CONFIRMED CONTRIBUTION]
- [MEMBER 3 NAME]: [CONFIRMED CONTRIBUTION]
- [MEMBER 4 NAME]: [CONFIRMED CONTRIBUTION]
- Every member explains their own contribution in a video or live showcase.
- See `team-contributions.md`; confirm names and work with the team before publishing.
- Speaker: [MEMBER]

## Slide 7 - Limits and next work

- No physical board or power-cut demonstration.
- No compaction implementation; a design note exists.
- CI runs SPARK flow analysis, not the full deductive proof goals.
- Next: complete proofs, validate hardware, implement compaction.
- Include the responsible AI/source disclosure from the shortcomings video script.
- Speaker: [MEMBER]

## Slide 8 - Sources and questions

- README, architecture, project plan, source, tests, and CI workflow.
- Course sponsor's capstone deliverables guidance.
- Draft AI disclosure: ChatGPT assisted CI troubleshooting and draft documentation; the team must confirm full AI use and review statements against project sources, tests, and CI results before publishing.
- Speaker: [MEMBER]
