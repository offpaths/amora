# Activity-Biased Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update Amora's backend generation prompt so activity-led date stops are considered by default when they fit the user's area, vibe, budget, duration, and personal context.

**Architecture:** This is a backend-only prompt contract change. `worker/src/openai.ts` owns prompt construction, and `worker/test/openai.test.ts` verifies the prompt includes the activity-bias rules without changing request or response schemas.

**Tech Stack:** Cloudflare Worker, TypeScript, Vitest, OpenAI Responses API prompt construction.

---

### Task 1: Add Prompt Contract Test

**Files:**
- Modify: `worker/test/openai.test.ts`

- [x] **Step 1: Write the failing test**

Add this test inside `describe("generateDatePlan", () => { ... })`, after the existing `"sends a prompt to the Responses API and parses raw output text"` test:

```ts
  it("includes activity-led planning guidance in the prompt", () => {
    const prompt = buildPrompt({
      ...validRequest,
      vibe: "adventurous",
      partnerLikes: "axe throwing, dumplings, playful competition"
    });

    expect(prompt).toContain("Prioritize activities explicitly mentioned in the partner likes or pasted context before inventing unrelated activity ideas.");
    expect(prompt).toContain("For adventurous, playful, active, novelty, romantic, outdoorsy, cozy, low-key, or foodie vibes, consider one activity-led stop when it fits the planning area, budget, duration, and no-drinking constraint.");
    expect(prompt).toContain("Activity-led stops can include axe throwing, bowling, pottery painting, mini golf, arcades, climbing, cooking classes, bookstores, galleries, museums, dance classes, markets, or similarly specific local experiences.");
    expect(prompt).toContain("Restaurants, bars, coffee shops, parks, and walks may support the plan, but they should not become the default shape of most plans when a realistic activity-led option would feel more personal or memorable.");
    expect(prompt).toContain("Do not force an activity stop when the area, budget, duration, or personal context makes it unrealistic.");
  });
```

- [x] **Step 2: Run test to verify it fails**

Run:

```bash
npm --prefix worker test -- test/openai.test.ts
```

Expected: FAIL because the prompt does not yet include the activity-led planning guidance.

### Task 2: Add Activity-Biased Prompt Instructions

**Files:**
- Modify: `worker/src/openai.ts`

- [x] **Step 1: Add minimal prompt instructions**

In `buildPrompt`, after:

```ts
    "Use the personal context in preview concepts, preview reasons, preview personalization signals, and locked-stop reasons when provided.",
```

add:

```ts
    "Prioritize activities explicitly mentioned in the partner likes or pasted context before inventing unrelated activity ideas.",
    "For adventurous, playful, active, novelty, romantic, outdoorsy, cozy, low-key, or foodie vibes, consider one activity-led stop when it fits the planning area, budget, duration, and no-drinking constraint.",
    "Activity-led stops can include axe throwing, bowling, pottery painting, mini golf, arcades, climbing, cooking classes, bookstores, galleries, museums, dance classes, markets, or similarly specific local experiences.",
    "Restaurants, bars, coffee shops, parks, and walks may support the plan, but they should not become the default shape of most plans when a realistic activity-led option would feel more personal or memorable.",
    "Do not force an activity stop when the area, budget, duration, or personal context makes it unrealistic.",
```

- [x] **Step 2: Run OpenAI prompt tests**

Run:

```bash
npm --prefix worker test -- test/openai.test.ts
```

Expected: PASS.

### Task 3: Verify Worker Quality Gates

**Files:**
- No file edits expected.

- [x] **Step 1: Run Worker test suite**

Run:

```bash
npm --prefix worker test
```

Expected: PASS.

- [x] **Step 2: Run Worker typecheck**

Run:

```bash
npm --prefix worker run typecheck
```

Expected: PASS.

- [x] **Step 3: Review final diff**

Run:

```bash
git diff -- worker/src/openai.ts worker/test/openai.test.ts docs/superpowers/plans/2026-07-05-activity-biased-generation.md
```

Expected: Diff only includes the activity-biased prompt test, prompt instructions, and this plan.
