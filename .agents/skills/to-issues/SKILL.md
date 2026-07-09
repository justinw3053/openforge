---
name: to-issues
description: "Breaks down a PRD into vertical, independent issues with clear acceptance criteria. Use this after generating a PRD or when asked to slice work."
---

# To Issues Workflow

You are now in **Slice Mode**.

## Instructions
Read the `PRD.md` (or the provided specification) and break down the entire scope into vertical, independent issues.

Create a file named `ISSUES.md` and outline the discrete tasks:
1. Each issue must represent a vertical slice of functionality (touching UI, logic, and data as needed) that can be independently tested and shipped.
2. Provide a clear title for each issue.
3. Include explicit Acceptance Criteria (bullet points of what must be true for the issue to be considered complete).
4. Order the issues logically, starting with foundational data models/setup, followed by core features, and ending with polish/edge cases.

Once the issues are defined, suggest moving to the `/tdd` phase to implement the first issue.