# Widget Usage Convention

## When to use `MoeActionRow`

- Use for action rows in drawers, bottom sheets, popups, and setting-like lists.
- Use when row structure is: `icon + title + optional subtitle + optional trailing`.
- Prefer `selected: true` for current/active item states (for example current chat session).
- Prefer token colors (`MoeTokens` / module tokens) via `iconColor` instead of hardcoded primary colors.

## When to use `MoeMenuCard`

- Use for grouped menu sections on pages (usually multiple related actions in one card).
- Keep page-level menu blocks inside `MoeMenuCard(items: [...])`, not raw `ListTile`.
- Use `MoeMenuItem.trailing` for switches/custom controls while keeping row visual style consistent.

## Rule of thumb

- Single independent row in modal/drawer -> `MoeActionRow`.
- Grouped section menu on page body -> `MoeMenuCard`.
- Avoid new `ListTile` in menu/settings/drawer flows unless there is a strong reason.

## Typical Examples

```dart
MoeActionRow(
  icon: Icons.reply_rounded,
  title: '回复消息',
  subtitle: const Text('引用这条消息继续提问'),
  iconColor: MoeTokens.primary,
  onTap: onReply,
)
```

```dart
MoeActionRow(
  icon: Icons.chat_bubble_outline_rounded,
  title: sessionTitle,
  selected: isCurrent,
  selectedBackgroundColor: MoeTokens.primary.withValues(alpha: 0.1),
  selectedBorderColor: MoeTokens.primary.withValues(alpha: 0.28),
  showDefaultTrailing: false,
  trailing: IconButton(
    icon: const Icon(Icons.delete_outline_rounded, size: 18),
    onPressed: onDelete,
  ),
  onTap: onOpen,
)
```

```dart
MoeMenuCard(
  items: [
    MoeMenuItem(
      icon: Icons.palette_rounded,
      title: '主题颜色',
      subtitle: '自定义应用主色调',
      color: Colors.pink,
      onTap: onOpenThemeColor,
    ),
  ],
)
```
