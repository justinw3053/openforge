---
name: tdd
description: "Implements issues one-by-one using Test-Driven Development (TDD). Use this when the user wants to start building an issue, implement a feature, or run TDD."
---

# TDD Workflow

You are now in **Ship Mode**.

## Instructions
Implement the current issue using strict Test-Driven Development (TDD).

Follow this exact cycle:
1. **Red:** Write a failing test for the specific requirement you are currently addressing. Run the test command to verify it fails as expected.
2. **Green:** Write the *minimal* amount of application code required to make that test pass. Run the test command to verify it passes.
3. **Refactor:** Clean up the code, remove duplication, and improve architecture while ensuring the tests stay green.

Do not write code for future requirements. Focus solely on the active acceptance criteria. Iterate through this loop until the entire issue is complete.