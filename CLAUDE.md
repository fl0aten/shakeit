# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ShakeIt is a World of Warcraft Classic Era addon (Interface 11508) that adds screen shake effects when the player lands critical hits or heals. The entire addon is contained in a single Lua file (`Core.lua`).

## Development

This is a WoW addon - there is no build system, linting, or tests. Development workflow:
1. Edit `Core.lua`
2. Reload the game UI with `/reload` or restart WoW
3. Test with `/shakeit shake` or by triggering crits in-game

## Architecture

The addon uses a single-file architecture with these key components:

**Frame Scanning System** (`scanUnprotectedFrames`): Recursively walks the UI tree from `UIParent` to find frames that can safely be moved during combat. Filters out chat frames, unit frames, edit boxes, raid frames, and addon-created frames with hex suffixes.

**Shake Animation** (`triggerShake`, `shakeSingleFrame`): Stores original frame positions, then uses an `OnUpdate` script to apply random offsets over 200ms. Restores original positions when complete.

**Combat Log Handler** (`onCombatLogEvent`): Listens to `COMBAT_LOG_EVENT_UNFILTERED` and checks for player-sourced critical hits across melee, ranged, spell, and periodic damage/heal events. Indices for the `isCrit` flag vary by event type (see lines 385-397).

**Initialization Flow**: On `ADDON_LOADED`, prints a message. On `PLAYER_ENTERING_WORLD`, schedules a 15-second fallback scan. On first player crit, triggers an immediate scan if frames haven't been scanned yet.

## WoW API Notes

- `pcall` wraps most frame operations to handle protected frames gracefully
- Frame positions use anchor points (`GetPoint`/`SetPoint`), not absolute coordinates
- Protected frames cannot be moved during combat - the scanning system identifies the boundary between protected and unprotected frames
- `C_Timer.After` is used for delayed execution
