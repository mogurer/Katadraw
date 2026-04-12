# Guide overlay & scoring — planned specification

**Status:** Planned (not implemented). May diverge from current game behavior.

**Related docs:** See `Docs/` — target vs. realized shape requirements, current evaluation logic, and clear-rate / clear-condition specification (existing Japanese `.md` files in that folder).

---

## 1. Background and goals

**Current behavior (to be replaced):** The guide shape scales and moves with the player’s KATA transform (zoom / pan / correspondence).

**Target behavior:**

- The guide is always drawn as a **topmost HUD overlay**, centered in the game window, independent of world/canvas pan and zoom.
- The player’s objective is **only** to align the KATA with the **on-screen guide**.
- **Achievement / score** must be recomputed so it uses the **same geometric transform** as the guide (draw and judge in one consistent space).

---

## 2. Guide layout (agreed)

### 2.1 Layering

- Guide is **always the front-most HUD**.
- Uses **screen / viewport** coordinates (not tied to the same transform as the drawable KATA in world space).

### 2.2 Size and margins (“80% of the window”)

After fitting, all of the following must hold:

1. The **entire** guide shape lies inside the **effective game window** (the rectangle used for playfield drawing — TBD: full window vs. area excluding chrome).
2. There is **at least 10% empty margin** on **left, right, top, and bottom** relative to that rectangle.

Equivalently: the guide’s axis-aligned bounding box is scaled and centered so it fits inside the **central 80% × 80%** sub-rectangle (equal margins), without clipping.

**Open points for implementation:**

- Exact definition of the **reference rectangle** (full window, content rect, safe area, etc.).
- Behavior when aspect ratios differ (always show full shape — letterboxing logic).

---

## 3. Player-facing goal

- Success is defined as **matching the KATA to the guide** on screen.
- Because the guide is HUD-fixed, **visual overlap** and **numeric score** must not drift apart: scoring must use the **same fit/center/scale** as rendering.

---

## 4. Scoring algorithm (direction of travel)

### 4.1 Principle

- Define **one transform**: stage “ideal” geometry → **guide in viewport** (fit + center + scale).
- Apply the **inverse / paired mapping** from player strokes into that same space for comparison.
- Avoid maintaining two independent scale systems (draw vs. score).

### 4.2 Coordinate options

- Compare in **viewport pixels** (with consistent DPI / logical pixel policy), **or**
- Normalize to e.g. **[0,1]²** using the guide’s bounding box after the HUD fit.

Either is fine if **one pipeline** feeds both draw and metrics.

### 4.3 “Match guide edges and vertices”

- Metrics should reflect distance / coverage against the **same polylines / curves** the player sees.
- If the guide uses arcs or subsampled curves, scoring must use the **same discretization or analytic curves** as the renderer (no silent mismatch).

### 4.4 Still to design

- Distance thresholds, per-segment weights, vertex neighborhoods, relationship to existing **実現率** and clear thresholds.
- Whether **player translation / rotation** of the KATA is part of the score or purely manual alignment (HUD-fixed guides often assume the player aligns; automatic Procrustes alignment in the score may be undesirable).

---

## 5. Relationship to existing documentation

- The **target vs. realized shape** requirements doc describes guide vs. realized shape scaling so they **look the same size** under player transform. After this change, that story becomes: **HUD fit to window**; player aligns KATA to that fixed guide.
- The **evaluation logic** doc notes sharing scale between guide and metrics; that **principle remains**, but the **source of the guide transform** becomes **window layout**, not (only) `ref_r` / player coupling.

---

## 6. Implementation notes

- **Single function** (or module) for “ideal outline → HUD transform”; use it for draw, hit-testing, debug overlays, and scoring.
- Prefer **logical pixels or normalized coordinates** if fairness across resolutions matters.

---

## 7. Change log

| Date       | Notes |
| ---------- | ------------------------------------------ |
| 2026-04-12 | First draft from design discussion         |
