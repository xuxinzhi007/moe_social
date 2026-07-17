---
name: hallmark-flutter
description: "Anti-AI-slop Flutter UI design skill. Use when designing or building new Flutter pages, screens, or UI components in the Moe Social app. Triggers on page/screen creation, UI redesign, design review, or when the user invokes Hallmark."
version: 1.0.0
---

# Hallmark — Flutter Edition

A design skill for AI coding assistants working on Flutter apps. Makes the UIs they generate look **crafted**, not generated.

Adapted from [Hallmark](https://github.com/Nutlope/hallmark) (web edition) for Flutter + MoeTokens.

---

## How to use this skill

| Invocation | What it does |
| --- | --- |
| *(default)* | The user asked you to design or build a new Flutter page/screen. Follow the **Design flow** below. |
| `hallmark audit <target>` | Read the target Flutter widget/page, score it against the anti-pattern list, return a ranked punch list. **Do not edit.** |
| `hallmark redesign <target>` | Take the target's content and intent, then redesign the visual structure inside the existing implementation boundaries. New layout rhythm, new component voice. Preserve existing routes, state management, and business logic; replace only the visual/interaction layer. |
| `hallmark study <screenshot \| URL>` | Extract the DNA from a design you admire: layout pattern, visual rhythm, color usage, component style. Produce a diagnosis report, then optionally apply the extracted DNA to the user's Flutter content. |

If the user types anything that does not clearly map to `audit`, `redesign`, or `study`, treat it as default.

**Implementation safety rail.** Hallmark is a design skill, not a license to bulldoze a codebase:
- Never delete production files, route trees, or component directories unless the user explicitly asks.
- Default to in-place edits of named files, or additive new widgets/tokens wired through existing routes.
- Before editing, state the exact files you expect to modify. Deletions require explicit confirmation.

---

## Six disciplines (apply across every verb)

1. **Pre-emit self-critique.** Before handing back any output, score it 1–5 on six axes — **Philosophy** (does it have a point of view?), **Hierarchy** (is the visual hierarchy clear?), **Execution** (is the craft tight?), **Specificity** (does it feel made for this purpose?), **Restraint** (is nothing gratuitous?), **Variety** (does it differ from the last output?). Anything **< 3** triggers a revision pass. Stamp the six scores at the top of the file: `// Hallmark · pre-emit critique: P5 H4 E5 S4 R5 V5`.

2. **Honest copy — no fabricated content.** If the user did not supply a metric, do not invent one. Stat-led layouts must use real numbers or a placeholder (`'—'` + a labelled grey box). *"+47% engagement"* is slop the moment it's invented.

3. **Locked tokens — no mid-render improvisation.** Every colour, spacing, radius, shadow, and font-size must reference [MoeTokens](../../lib/theme/moe_tokens.dart) or the existing theme. Inline `Color(0xFFxxxxxx)` values, hardcoded `EdgeInsets`, or `BorderRadius.circular(16)` that bypass MoeTokens are **not allowed**. If a value is needed that doesn't exist as a token, add it to MoeTokens first, then reference it.

4. **No generic Material chrome.** Do not use default Material `AppBar`, `Card`, `ListTile`, `ElevatedButton` without visual customization. Every Material widget must be restyled via MoeTokens — custom `shape`, `backgroundColor`, `elevation: 0`, or replaced with a `Container`/`DecoratedBox` using MoeTokens shadows and borders.

5. **Responsive by construction.** Flutter pages must render correctly at phone (320–430 dp) and tablet (600–1024 dp) widths. Use `LayoutBuilder`, `Flexible`, `Expanded`, `Wrap`, or `SliverGrid` with appropriate `crossAxisCount`. Never use hardcoded widths that break on larger screens.

6. **Typography discipline.** Headings use `MoeTokens.fontWeightTitle` or `fontWeightDisplay`. Body text uses `fontWeightBody`. Never use italic for headings — carry emphasis with weight, accent color, or gradient text via `ShaderMask`.

---

## When the brief is a component, not a page

**Component-scope signals:**
- The brief names a single UI element: a button, a card, a chip, a badge, a modal, a bottom sheet, an input field, a toggle, an avatar, a list tile.
- The brief is short (≤ 30 words) and refers to one element.
- The user explicitly says *"just the X"*, *"only the Y"*, *"this one element"*.

If component-scope: skip layout-pattern selection and page-level diversification. Keep: token discipline, self-critique, anti-pattern check, slop test (visual subset).

---

## Design flow (default)

### 0. Pre-flight scan

Before designing anything, **read the existing codebase context**:

1. **MoeTokens** — Read `lib/theme/moe_tokens.dart`. This is the **locked design system**. All colours, spacing, radii, shadows, gradients, and motion values come from here.
2. **Existing pages** — Scan 2–3 existing pages in the same domain (e.g., if building a chat page, look at other chat pages). Note their layout patterns, widget structure, and visual rhythm.
3. **Theme extension** — Check `lib/theme/` for any theme extensions or additional design helpers.

**Output format** — emit this block once before Step 1:

```
Pre-flight findings:
· Design system: MoeTokens (lib/theme/moe_tokens.dart) — locked
· Existing pages in domain: <list 2-3 relevant pages>
· Layout patterns observed: <e.g., SliverAppBar + CustomScrollView, card-based lists>
· Motion stance: MoeReveal fade-in + stagger (motionFadeDuration 300ms, stagger 60ms)

Hallmark will preserve: MoeTokens SSOT, existing route structure, state management patterns.
Hallmark will introduce: layout pattern variety, anti-slop discipline, self-critique.
```

### 1. Design-context gate

Before writing any widget, understand three things:

1. **Audience.** Who uses this screen? (e.g., young social app users, gamers, creators)
2. **Job.** What's the ONE thing this screen helps the user do?
3. **Tone.** Pick from Moe Social's voice: *kawaii-soft · playful · clean-modern · editorial · utilitarian*. "Nice and clean" is not a tone.

**Always ask** — answering is optional. The prompt:

> *Before I build, I need three things:*
>
> *1. **Audience** — Who will use this screen?*
> *2. **Job** — What's the one action this screen enables?*
> *3. **Tone** — Pick: kawaii-soft · playful · clean-modern · editorial · utilitarian*
>
> *Or say **"go ahead"** and I'll infer from the brief.*

If the user says "go ahead" or doesn't engage: infer from context, state inferences in one sentence, then proceed.

### 2. Pick a layout pattern FIRST

Before choosing visual details, **read [`references/layout-patterns.md`](references/layout-patterns.md) and pick one of the named patterns.** The pattern determines the structural skeleton — scroll model, section arrangement, widget hierarchy, visual rhythm.

**Diversification rule (mandatory).** Before you pick:
1. Check the last 3 pages you designed in this session. Your pick must be a **different** pattern.
2. Two consecutive pages should not share the same scroll model (e.g., both `CustomScrollView` + `SliverList`).

**State your pick.** Before writing code: *"Layout: Card Feed. Scroll: CustomScrollView + SliverList. Differs from last on: scroll model + section rhythm."*

### 3. Load the visual ruleset

**Always-load:**
- MoeTokens (already scanned in pre-flight)
- [`references/anti-patterns.md`](references/anti-patterns.md) — the named Flutter UI tells you must not emit

**Load-per-build:**
- [`references/layout-patterns.md`](references/layout-patterns.md) — the picked pattern's specifics

**Load-at-the-end (after build):**
- [`references/slop-test.md`](references/slop-test.md) — the post-emit quality check

### 4. Preview

Before emitting any code, output a summary:

```
**Hallmark Flutter · v1.0.0**

- **Layout** · <pattern name>
- **Scroll model** · <CustomScrollView / ListView / NestedScrollView / ...>
- **Sections** · <section names in order>
- **Token usage** · MoeTokens: colours ✓ spacing ✓ shadows ✓ gradients ✓
- **Motion** · <MoeReveal stagger / fade / none>
- **Slop test** · <N / N ✓ or fails: gate numbers>
- **Diversification** · <differs from last on: ...>
```

### 5. Build

Emit Flutter/Dart code that satisfies the tone and structural fingerprint.

Always:
- **Every colour** from `MoeTokens` — never `Color(0xFFxxxxxx)` inline.
- **Every spacing** from `MoeTokens.space*` — never `EdgeInsets.all(16)` with magic numbers.
- **Every radius** from `MoeTokens.radius*` — never `BorderRadius.circular(12)` with magic numbers.
- **Every shadow** from `MoeTokens.shadow*()` — never `BoxShadow(...)` with inline values.
- **Every gradient** from `MoeTokens.gradient*` — never `LinearGradient(...)` with inline colours.
- **Every text style** uses `MoeTokens.text*` sizes and `MoeTokens.fontWeight*` weights.
- **Every animation** uses `MoeTokens.motion*` durations and offsets.
- Use `const` constructors wherever possible.
- Keep widget trees shallow — extract sub-widgets at 3+ levels of nesting.
- **Stamp the output.** First line of each designed file: `// Hallmark · layout: <name> · tone: <tone> · scroll: <model>`.

### 6. The slop test

Before handing back, run the output through the slop test in [`references/slop-test.md`](references/slop-test.md). Every answer must be **no** (i.e., the code does NOT exhibit the anti-pattern). If any gate fails, fix it. Do not ship slop.

---

## `hallmark audit`

Read the target page/widget file. Score it against every gate in [`references/slop-test.md`](references/slop-test.md). Return a ranked punch list — most-violated first. **Do not edit the code.**

Format:
```
**Hallmark Audit · <file>**

Score: <pass-count> / <total> gates pass

Fails (ranked by severity):
1. **Gate <N>** — <description of violation> at <location>
2. ...

Recommendations:
- <top 3 actionable fixes>
```

---

## `hallmark redesign`

Take the target's content, routes, state management, and business logic. Discard only the visual layer. Rebuild using a **different** layout pattern from the original. Preserve:
- Route paths and navigation calls
- Provider/Controller/BLoC references
- API call logic
- Data models

Replace:
- Layout structure (widget tree arrangement)
- Visual styling (colours, shadows, spacing)
- Scroll model
- Component visual treatment

Follow the full Design flow (Steps 0–6) with the constraint that content/IA stays fixed.

---

## `hallmark study`

The user has supplied a reference — a screenshot or URL of a design they admire. Extract its DNA and apply it to Flutter.

### Pipeline

1. **Extraction.** Analyze the reference for:
   - Layout skeleton (how sections are arranged)
   - Visual rhythm (spacing patterns, density)
   - Colour anchor (dominant colour feeling)
   - Component style (card treatment, button style, text hierarchy)
   - Motion feel (static vs animated, heavy vs light)

2. **Diagnosis report.** Return:
   ```
   **Design DNA · <source>**
   
   - Layout: <description of structural pattern>
   - Rhythm: <spacing density — generous/moderate/compact>
   - Colour anchor: <dominant feeling — warm/cool/neutral + saturation>
   - Component style: <rounded/sharp, heavy/light, bordered/flat>
   - Motion feel: <static/subtle/lively>
   - Flutter mapping: <which MoeTokens map to this DNA>
   ```

3. **Confirmation.** Ask: *"Apply this DNA to your current screen, or just use the diagnosis as reference?"*

4. **Branch:**
   - **"Apply"** → run the Design flow, mapping the DNA to MoeTokens equivalents. Stamp with `studied: yes`.
   - **"Reference only"** → stop. The diagnosis is the deliverable.

---

## Output contract

- **Never delete** production code without explicit user confirmation.
- **Never invent** data, metrics, or user content.
- **Never bypass** MoeTokens — all visual values go through the SSOT.
- **State files** you will modify before editing.
- **Stamp every designed file** with the Hallmark comment.
