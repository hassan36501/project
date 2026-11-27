# Intro video script

**Limit:** 2 minutes. Target 90-110 seconds. Replace all bracketed fields. Show every team member's exact name on screen, together with the confirmed Product Owner or sponsor.

## Recording script

**[Opening slate: project name, all four member names, Product Owner/sponsor.]**

Hi, we are **[TEAM NAME]**, a four-student capstone team at VCU. Our members are **[MEMBER 1]**, **[MEMBER 2]**, **[MEMBER 3]**, and **[MEMBER 4]**. Our Product Owner or sponsor is **[CONFIRMED NAME AND ROLE]**.

Embedded devices need to preserve settings, counters, or small records through restarts. If power is interrupted during a write, a partial record can leave the application unsure which data is valid.

Legder is our Ada/SPARK prototype for a bounded key-value store over a fixed-block device. It appends a record to a write-ahead log, synchronizes the record, and only then updates the in-memory table. On reopening, it checks record validity and sequence order, then reconstructs the table by replaying the accepted log prefix.

Our work includes a RAM crash simulator, a desktop file-backed device, tests, and recovery demonstrations. GitHub Actions run #21 for commit `5c2fe92` passed its configured checks, including SPARK flow analysis. We have not completed the deductive proof goals or a hardware power-loss demonstration; we will explain these limits in the final video.

**[Closing slate: each member's name and confirmed contribution.]**

## Member contribution slate

| Member | Exact name | Confirmed contribution to explain in a video or live showcase |
|---|---|---|
| 1 | [FILL IN] | [FILL IN] |
| 2 | [FILL IN] | [FILL IN] |
| 3 | [FILL IN] | [FILL IN] |
| 4 | [FILL IN] | [FILL IN] |
| Product Owner / sponsor | [FILL IN NAME AND ROLE] | Not a team-member contribution |
