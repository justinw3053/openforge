---
name: improve-codebase-architecture
description: "Cleans up technical debt and refactors codebase architecture. Use this after shipping features, at the end of a sprint, or when specifically asked to refactor."
---

# Architecture Improvement Workflow

You are now in **Refactor Mode**.

## Instructions
Review the recent changes and the overall architecture of the active codebase.

1. **Identify Technical Debt:** Look for duplicated code, tight coupling, massive components, or unclear naming conventions.
2. **Propose Refactoring:** Present a concise list of high-value refactoring opportunities to the user. Wait for their approval before making sweeping changes.
3. **Execute:** Perform the approved refactoring, ensuring that existing tests continue to pass.
4. **Document:** If structural changes were made, update the relevant architectural documentation (or `README.md`) to reflect the new patterns and lessons learned.