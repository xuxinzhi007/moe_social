# Generic AI Sprite v1

## Purpose

This format turns an AI-generated PNG into a runtime-ready sprite draft without requiring LPC slots, palettes, or a fixed character anatomy.

The source image is preserved as authoring input. The exported PNG is a normalized canvas using a selected template and anchor.

## Workflow

1. Import a transparent PNG.
2. Select a template for a character, object, effect, animation strip, or directional grid.
3. Adjust fit, scale, offset, and anchor against the template guides.
4. Export the normalized PNG and JSON manifest.
5. Let Flutter/Flame or Godot consume the manifest and sprite sheet.

Video files are supported as a local authoring source. The editor samples a bounded time range into PNG frames, then sends those frames through the same alignment, cleanup, validation, and export pipeline as imported PNG files.

## Contract

The shared TypeScript contract lives in `moe-avatar/core/src/spriteTypes.ts`.

Required concepts:

- `id` and `kind`
- `canvas` and `anchor`
- `frameLayout`
- one or more `animations`
- original `source` metadata
- optional runtime `sheet` path
- optional independent `layers`

## Non-goals

- LPC slot names are not required.
- Palette recoloring is optional and is not part of v1.
- AI does not automatically produce reliable animation frames.
- The first editor export is a normalized static/template draft; frame authoring comes later.
- Video import is local-only, capped by duration and frame count, and does not preserve audio.

## Runtime

Runtime implementations must crop one frame from the exported sheet. They must not display the full authoring sheet as the in-game character.
