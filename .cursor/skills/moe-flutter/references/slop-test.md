# Flutter Slop Test — Post-Emit Quality Gates

Run this check **after** building the UI. Every answer must be **NO** (the code does NOT exhibit the pattern). If any gate fails, fix it before handing back.

---

## Visual token gates (G1–G8)

**G1. Hardcoded colours**
Does any widget contain `Color(0xFFxxxxxx)` or `Colors.xxx` (except `Colors.white`/`Colors.transparent` where semantically correct)?
→ All colours must come from `MoeTokens`.

**G2. Magic number spacing**
Does any `EdgeInsets`, `SizedBox`, or `Padding` use a number not in the MoeTokens spacing scale (`spaceXs`=4, `spaceSm`=8, `spaceMd`=12, `spaceLg`=16, `spaceXl`=20, `space2xl`=24, `space3xl`=32, `space4xl`=40)?
→ All spacing must reference MoeTokens.

**G3. Magic number radius**
Does any `BorderRadius` use a number not in the MoeTokens radius scale (`radiusSm`=8, `radiusMd`=12, `radiusLg`=16, `radiusXl`=20, `radius2xl`=24, `radiusButton`=25, `radiusInput`=15, `radiusFull`=9999)?
→ All radii must reference MoeTokens.

**G4. Inline shadows**
Does any `BoxShadow` use inline values instead of `MoeTokens.shadowSm()`, `shadowMd()`, `shadowCard()`, `shadowLg()`, `shadowElevated()`, `shadowButton()`, or `shadowGlow()`?
→ All shadows must use MoeTokens shadow methods.

**G5. Inline gradients**
Does any `LinearGradient` use inline `colors: [...]` instead of `MoeTokens.gradientPrimary`, `gradientSoft`, `gradientKawaii`, `gradientText`, `primaryGradient`, `heroGradient`, or `gradientPageBg`?
→ All gradients must reference MoeTokens.

**G6. Inline font sizes**
Does any `TextStyle` use a `fontSize` not in the MoeTokens type scale (`textXs`=11, `textSm`=12, `textBase`=14, `textMd`=15, `textLg`=18, `textXl`=20, `text2xl`=24, `text3xl`=28)?
→ All font sizes must reference MoeTokens.

**G7. Inline font weights**
Does any `TextStyle` use a `FontWeight` not in the MoeTokens weight set (`fontWeightDisplay`=w700, `fontWeightTitle`=w700, `fontWeightSubtitle`=w600, `fontWeightBody`=w400, `fontWeightCaption`=w400)?
→ All font weights must reference MoeTokens.

**G8. Inline motion values**
Does any `Duration` or animation use a value not in the MoeTokens motion set (`motionFadeDuration`=300ms, `motionStaggerStep`=60ms, `motionFast`=160ms, `motionMedium`=260ms, `motionSlow`=420ms)?
→ All motion values must reference MoeTokens.

---

## Structure gates (G9–G14)

**G9. Default Material chrome**
Does the page use unstyled `AppBar()`, `Card()`, `ListTile()`, `ElevatedButton()`, or `FloatingActionButton()` without any MoeTokens customization?
→ All Material widgets must be restyled.

**G10. Missing surface borders**
Are there white/light cards on white backgrounds with only shadow for separation and no `Border.all(color: MoeTokens.surfaceBorder)`?
→ Elevated surfaces need surfaceBorder.

**G11. Identical layout rhythm**
Does this page use the exact same structural skeleton as the last page designed in this session?
→ Must differ on at least one structural axis (scroll model, section arrangement, widget hierarchy).

**G12. Widget tree depth**
Does any single widget tree exceed 4 levels of nesting without extracting a sub-widget?
→ Extract at 3+ levels.

**G13. Missing const**
Are there widget constructors that could be `const` but aren't?
→ Use `const` wherever possible.

**G14. Missing file stamp**
Does the file lack the `// Hallmark · layout: <name> · tone: <tone> · scroll: <model>` stamp at the top?
→ Every designed file must be stamped.

---

## Content gates (G15–G17)

**G15. Invented metrics**
Does the UI display any fabricated numbers, percentages, user counts, or testimonials?
→ Use real data or honest placeholders.

**G16. Italic headings**
Does any heading/section title use `FontStyle.italic`?
→ Headings are always roman.

**G17. Generic empty states**
Are there empty/error states with just a bare `Icon` + `Text` and no visual treatment?
→ Empty states need gradient icon container + text hierarchy + optional CTA.

---

## Interaction gates (G18–G20)

**G18. Flat interactions**
Are there tappable elements with no press feedback (no scale animation, no ripple customization)?
→ Interactive elements need `motionPressScale` feedback.

**G19. Missing focus/hover states**
Are there interactive elements that don't change appearance on hover/focus (for platforms that support it)?
→ At minimum, use press-scale feedback.

**G20. Animation overload**
Does the page have more than 3 different animation types (fade + scale + slide + rotate + ...)?
→ Cap at 2–3 animation primitives per page.

---

## Responsive gates (G21–G22)

**G21. Hardcoded widths**
Does any widget use a fixed pixel width that would break on tablets or larger screens?
→ Use `Flexible`, `Expanded`, `LayoutBuilder`, or responsive breakpoints.

**G22. Overflow risk**
Are there `Row` or `Column` widgets with unbounded children that could overflow on small screens?
→ Use `Flexible`, `Expanded`, `Wrap`, or `FittedBox`.

---

## Pre-emit self-critique (run last)

Score the output 1–5 on each axis:

| Axis | Question |
|------|----------|
| **Philosophy** | Does this UI have a clear point of view, or could it be any app? |
| **Hierarchy** | Is the visual hierarchy immediately clear? Does the eye go where it should? |
| **Execution** | Is the craft tight? Are tokens used consistently? Are shadows/borders correct? |
| **Specificity** | Does this feel designed for *this* purpose, or is it generic? |
| **Restraint** | Is nothing gratuitous? Could anything be removed without losing meaning? |
| **Variety** | Does this differ from the last output, or is it the same template again? |

Anything **< 3** triggers a revision pass. Stamp the scores at the top of the file.

---

## Gate summary format

```
Slop test: <pass-count> / 22 ✓
Fails: G<N>, G<M>
Self-critique: P<N> H<N> E<N> S<N> R<N> V<N>
```
