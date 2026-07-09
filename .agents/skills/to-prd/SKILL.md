---
name: to-prd
description: "Compiles the resolved decisions from a grill-me interview into a detailed Product Requirement Document (PRD). Use this after completing a grill-me session or when asked to write a PRD."
---

# To PRD Workflow

You are now in **Spec Mode**.

## Instructions
Based on our shared understanding from the recent conversation/interview, write a highly detailed Product Requirement Document (PRD).

Create a file named `PRD.md` (or update an existing one) that includes:
- **Core Objective:** A brief summary of the feature/project.
- **Entry Points:** Where does the user navigate *from* to reach this feature?
- **User Journey:** The complete flow from discovery to completion and return.
- **Roles:** How managers, guests, admins, or unauthenticated users interact with it.
- **State Transitions:** How changes are pushed (e.g., WebSockets, SSE, polling, optimistic updates).
- **Edge Cases:** Empty states, network errors, concurrent access, mobile vs. desktop view.
- **Module Sketches:** High-level outlines of the components and data models required.

Do not start writing application code yet. Once the PRD is generated, suggest moving to the `/to-issues` phase.