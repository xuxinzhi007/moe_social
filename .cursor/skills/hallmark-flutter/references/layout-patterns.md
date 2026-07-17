# Flutter Layout Patterns

Named structural patterns for Flutter pages. Each pattern defines the scroll model, section arrangement, widget hierarchy, and visual rhythm. **Pick one before building.**

---

## Pattern index

| # | Pattern | Scroll model | Best for |
|---|---------|-------------|----------|
| L1 | **Sliver Cascade** | `CustomScrollView` + `SliverAppBar` + `SliverList` | Content feeds, timelines, activity streams |
| L2 | **Pinned Header** | `NestedScrollView` + `SliverOverlapAbsorber` | Scrollable pages with sticky header sections |
| L3 | **Card Grid** | `CustomScrollView` + `SliverGrid` | Galleries, collections, discovery surfaces |
| L4 | **Stacked Sheets** | `Column` + `Expanded` + internal `ListView` | Dashboard, split-view, detail pages |
| L5 | **Tabbed Container** | `DefaultTabController` + `TabBarView` | Multi-category browsing, filtered content |
| L6 | **Scroll + FAB Cluster** | `CustomScrollView` + `Stack` + floating actions | Maps, creation surfaces, action-heavy pages |
| L7 | **Expandable List** | `ListView.separated` + `ExpansionTile`-like | Settings, FAQ, structured data |
| L8 | **Hero Detail** | `Hero` + `CustomScrollView` + parallax | Item detail, profile, immersive content |
| L9 | **Bottom Sheet Stack** | `Scaffold` + `showModalBottomSheet` layers | Chat, forms, multi-step flows |
| L10 | **Segmented Scroll** | `CustomScrollView` + `SliverPersistentHeader` (segmented) | Long-form content with chapter navigation |
| L11 | **Carousel + List** | `PageView` + `ListView` below | Featured content + detailed list |
| L12 | **Staircase** | `Column` + alternating `Row` alignments | Story-like, editorial, onboarding |

---

## Pattern details

### L1 · Sliver Cascade

```
CustomScrollView
├── SliverAppBar (collapsed → expanded, gradient background)
├── SliverToBoxAdapter (section header / filter chips)
├── SliverList (main content, staggered fade-in)
└── SliverToBoxAdapter (bottom state capsule)
```

**Visual rhythm:** Large hero → compact list → bottom indicator.
**Used by:** `home_page.dart` (feed), activity feeds.
**Diversification axis:** Hero height (collapsedExtent), section header style, list item treatment.

---

### L2 · Pinned Header

```
NestedScrollView
├── SliverOverlapAbsorber
│   └── SliverAppBar (pinned, with bottom tab bar)
└── CustomScrollView
    ├── SliverOverlapInjector
    ├── SliverToBoxAdapter (content header)
    └── SliverList (content items)
```

**Visual rhythm:** Sticky nav → scrollable content beneath.
**Used by:** Pages with persistent filter/category bars.
**Diversification axis:** Header content, injector height, content treatment.

---

### L3 · Card Grid

```
CustomScrollView
├── SliverToBoxAdapter (page title + filters)
├── SliverPadding
│   └── SliverGrid (card grid, crossAxisCount: 2)
└── SliverToBoxAdapter (load more / empty state)
```

**Visual rhythm:** Header → uniform grid → pagination.
**Used by:** Discovery pages, collections, galleries.
**Diversification axis:** Grid density (2 vs 3 columns), card aspect ratio, header treatment.

---

### L4 · Stacked Sheets

```
Column
├── Container (fixed header / summary card, shadowCard)
├── Expanded
│   └── ListView (scrollable detail list)
└── Container (fixed bottom bar, surfaceBorder top)
```

**Visual rhythm:** Fixed top → scrollable middle → fixed bottom.
**Used by:** Detail pages, dashboards, forms.
**Diversification axis:** Header height, bottom bar content, middle list treatment.

---

### L5 · Tabbed Container

```
DefaultTabController
└── Column
    ├── Container (TabBar, shadowCard + surfaceBorder)
    └── Expanded
        └── TabBarView
            └── [per-tab content, each its own scroll model]
```

**Visual rhythm:** Tab strip → content panels.
**Used by:** `message_center_page.dart`, category browsers.
**Diversification axis:** Tab style (label/indicator), per-tab internal layout.

---

### L6 · Scroll + FAB Cluster

```
Stack
├── CustomScrollView (main content)
└── Positioned (bottom-right)
    └── Column (FAB cluster, gradientPrimary + shadowGlow)
```

**Visual rhythm:** Full-bleed scroll + floating action cluster.
**Used by:** Map pages, creation surfaces.
**Diversification axis:** FAB count/arrangement, content scroll model.

---

### L7 · Expandable List

```
CustomScrollView
├── SliverToBoxAdapter (page header)
└── SliverList
    └── [ExpansionTile-like items, surface1 + surfaceBorder]
```

**Visual rhythm:** Header → vertically stacked expandable sections.
**Used by:** Settings, FAQ, structured data.
**Diversification axis:** Item visual treatment, expand animation, grouping.

---

### L8 · Hero Detail

```
CustomScrollView
├── SliverToBoxAdapter
│   └── Hero (image/avatar, gradientSoft background)
├── SliverToBoxAdapter (info card, shadowCard + surfaceBorder)
├── SliverList (detail rows)
└── SliverToBoxAdapter (CTA button, gradientPrimary)
```

**Visual rhythm:** Immersive hero → info → details → action.
**Used by:** Profile pages, item detail.
**Diversification axis:** Hero size/shape, info card layout, CTA position.

---

### L9 · Bottom Sheet Stack

```
Scaffold
├── body: Column / ListView (main content)
└── bottomSheet / showModalBottomSheet:
    └── Container (surface1 + surfaceBorder + shadowElevated)
        └── Form / Step content
```

**Visual rhythm:** Main surface → modal overlay for focused tasks.
**Used by:** Chat pages (options), form flows.
**Diversification axis:** Sheet height, handle style, content arrangement.

---

### L10 · Segmented Scroll

```
CustomScrollView
├── SliverPersistentHeader (pinned, segment picker)
├── SliverToBoxAdapter (section A content)
├── SliverToBoxAdapter (section B content)
└── SliverToBoxAdapter (section C content)
```

**Visual rhythm:** Pinned segment bar → long scrollable content with visual breaks.
**Used by:** Long-form content, editorial pages.
**Diversification axis:** Segment style, section divider treatment.

---

### L11 · Carousel + List

```
Column
├── SizedBox (height: 200)
│   └── PageView (featured items, gradientSoft backgrounds)
├── Container (section title, gradient left bar)
└── Expanded
    └── ListView (detailed items, shadowCard)
```

**Visual rhythm:** Horizontal featured → vertical detailed list.
**Used by:** Discovery, recommendation surfaces.
**Diversification axis:** Carousel item style, list item treatment, section transition.

---

### L12 · Staircase

```
Column
├── Row [left-aligned content block]
├── Row [right-aligned content block]
├── Row [left-aligned content block]
└── ...
```

**Visual rhythm:** Alternating alignment creates a story-like flow.
**Used by:** Onboarding, tutorials, editorial.
**Diversification axis:** Block size, alignment pattern, visual connectors.

---

## Diversification rules

1. **No consecutive same-pattern.** If you used L1 (Sliver Cascade) last time, pick from L2–L12.
2. **Vary the scroll model.** If the last two pages both used `CustomScrollView`, the next should use `NestedScrollView`, `Column + ListView`, or `PageView + ListView`.
3. **Match pattern to purpose.** Don't pick a pattern just for variety — it must fit the content. A feed needs L1 or L3; a detail page needs L8 or L4; a form needs L9 or L4.
4. **State your pick out loud.** *"Last 3 patterns: L1 (feed) · L5 (tabs) · L1 (chat). L1 used twice — picking L4 (Stacked Sheets) this time for the detail page."*
