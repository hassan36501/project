# Sources and AI-use disclosure

## Source record

| Source | Used for |
|---|---|
| Course capstone deliverables guidance supplied by the team (email screenshots) | Video content/lengths, poster and slide uploads, YouTube settings, and deadlines. |
| `README.md`, `ARCHITECTURE.md`, and `plan_fall_2026.md` | Project purpose, design, fault model, and scope. |
| Ada/SPARK source under `src/`, `devices/file/`, `showcase/`, and `tests/` | Actual commit/recovery behavior, file-device behavior, demos, and test coverage. |
| `.github/workflows/ci.yml` and GitHub Actions run #21 for `d2428db`, plus the run for `5c2fe92` | Which automated checks passed and which GNATprove mode CI runs. |
| `docs/compaction-design.md` and `docs/proof-status.md` | Compaction and formal proof status. |

## Draft disclosure

> Draft: ChatGPT assisted with CI troubleshooting and drafting project documentation and showcase materials. Before submission, the team must confirm its full AI use and check technical statements against repository source, tests, course guidance, and GitHub Actions results; no unproved goal should be presented as proved.

This statement records AI use in preparation of these materials. Before submission, confirm whether any team members used other AI tools and expand the disclosure to cover the team's full use. Do not claim AI tools were the only sources: the course guidance and project repository were also used.

## Verification notes

- Technical claims in the scripts were checked against source, project documents, and workflow configuration.
- CI passing is reported only for checks in that workflow. The workflow GNATprove command is flow analysis, not completed deductive proof of R1/R2/L1/S1.
- The RAM showcase torn-write scenario is described as simulated, not physical power-loss testing.
- Recording, captions, uploads, poster printing, Zoom setup, and rehearsal attendance are not verified by this repository.
