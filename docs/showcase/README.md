# Capstone showcase deliverables

This folder prepares content for the Fall 2026 showcase guidance supplied by the team. It contains recording scripts, poster copy, a slide outline, an AI/source disclosure, and a submission checklist.

## Completion state

- Scripts and checklist: drafted from current repository facts and the supplied course guidance.
- Poster and slide content: drafts; team names, sponsor, and final review are still required.
- Videos, YouTube settings/captions, My Showcase uploads, Zoom room links, rehearsal attendance, and live presentation: **not completed by these repository files**. The team must perform and verify them.
- Replace every `[FILL IN ...]` placeholder before recording or submitting. Do not guess names, sponsor, or individual contributions.

## Files

- `intro-script.md` - Intro, maximum 2 minutes.
- `demo-script.md` - Narrated demo, maximum 3 minutes.
- `shortcomings-future-work-script.md` - Limits, next work, AI disclosure; maximum 3 minutes.
- `installation-maintenance-script.md` - Clean setup and maintenance; maximum 5 minutes.
- `poster-copy.md` - One-page 36 x 48 inch portrait poster copy.
- `poster.html` and `legder-poster-draft.pdf` - Editable poster source and printable one-page PDF draft.
- `slides-outline.md` - Slide sequence and speaker assignment slots.
- `slides.html` and `legder-slides-draft.pdf` - Editable slide source and printable seven-page PDF draft.
- `sources-and-ai-disclosure.md` - Source record and disclosure.
- `submission-checklist.md` - Deadlines, publishing rules, and evidence.
- `team-submission-data-template.md` - Team roles and external submission confirmation fields.
- `team-contributions.md` - Contribution ownership worksheet; names and ownership require team confirmation.

## Technical basis

Legder is a bounded Ada/SPARK key-value store using a write-ahead log, fixed 512-byte records, CRC validation, a RAM crash simulator, and a desktop file-backed device. One Put/Delete is one commit. Multi-operation transactions and compaction are not implemented. CI on commit `5c2fe92` passed the checks configured in that workflow, including SPARK flow analysis. It does not prove the deductive goals or hardware durability; see `../proof-status.md`.

The supplied course guidance is the source for presentation requirements. The repository and its recorded CI run are the source for technical claims. The RAM torn-write scenario must be called a simulation, not a physical power cut.
