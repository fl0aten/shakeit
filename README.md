# ShakeIt

A lightweight World of Warcraft Classic Era addon that adds a screen shake effect when you land critical hits or critical heals.

## For Players: What to Expect

**ShakeIt adds visceral feedback to your combat** — every time you crit (damage or healing), your UI elements shake briefly. This creates a satisfying "impact" feeling that makes combat feel more responsive without being distracting.

### What Shakes?

The effect moves "safe" UI elements like:
- Action bars
- Minimap
- Buff/Debuff frames
- Casting bar
- Quest tracker
- Most third-party addon frames

### What Stays Put?

Important elements remain untouched:
- Chat frames (so you can still read)
- Player/Target/Pet unit frames (they use special animations)
- Enemy nameplates/raid frames

### Performance

ShakeIt is designed to be lightweight:
- No noticeable FPS impact
- Scans once at startup (or on your first crit)
- Uses only native WoW API calls
- Less than 300 lines of code

## Features

- **Automatic Detection**: Detects all your critical hits and critical heals (melee, ranged, spells, HoTs)
- **Combat-Safe**: Only shakes non-protected UI elements that can be moved during combat
- **Zero Configuration**: Works out of the box, no settings needed
- **Minimal Impact**: Uses efficient frame scanning and smooth animations
- **Addon-Friendly**: Handles frames from third-party addons gracefully

## Commands

| Command | Description |
|---------|-------------|
| `/shakeit` | Show help |
| `/shakeit shake` | Trigger a manual shake |
| `/shakeit scan` | Rescan all UI frames (prints count to chat) |
| `/shakeit test <framename>` | Shake a specific frame by name |

## Installation

1. Download ShakeIt
2. Extract to `Interface/AddOns/ShakeIt`
3. Restart WoW
4. Enable the addon in character select

## Configuration

No configuration needed. The addon uses these defaults:

| Setting | Value |
|---------|-------|
| Intensity | 5 |
| Duration | 200ms |
| Cooldown | 300ms |

## Technical Details

### Frame Scanning

ShakeIt recursively scans the UI frame tree starting from `UIParent`. Scanning is triggered by the first critical hit or heal (with a 15-second fallback if no crit occurs), ensuring that third-party addon frames are fully loaded.

A frame is considered shakeable when:
1. **It has a protected parent** OR **is anchored directly to UIParent** - this ensures we only shake "safe" frames
2. **It has at least one anchor point** - frames without positioning are skipped
3. **It passes the filter checks** below

#### Excluded Frame Types

The following frames are explicitly excluded from shaking (along with their children):

| Frame Type | Detection | Reason |
|------------|-----------|--------|
| ChatFrames | `ScrollingMessageFrame` type | Has mouse-over fade and dock positioning |
| EditBoxes | `EditBox` type | Input fields with special handling |
| CompactRaidFrameManager | `dynamicContainerPosition` property | Dynamically recalculates bounds |
| UnitFrames | `unit` property exists | Player/Target/Pet frames use animation systems |
| AddOn-created frames | Hex suffix in name (e.g., `Minimap.24e7df2ce30`) | Dynamically created frames often have absolute positioning |

#### Why These Frames Are Excluded

Some UI elements have complex internal positioning systems that break when externally manipulated:

- **ChatFrames**: Maintain dock positions and have mouse-over fade logic
- **UnitFrames**: Use animation systems for entering/leaving combat and health updates
- **Raid Frames**: Dynamically resize based on raid size and screen position
- **AddOn-created frames**: Often use absolute coordinates independent of their parent

Attempting to shake these frames would cause them to "disappear" or behave incorrectly.

### Anchored Frame Deduplication

Frames that are anchored to another shakeable frame are automatically excluded - they move with their parent and don't need separate shaking. This prevents issues with chained elements like micro-buttons.

### Combat Log Events

ShakeIt listens to the following combat log events:

| Event Type | SubEvent | Description |
|------------|----------|-------------|
| Melee | `SWING_DAMAGE` | Auto-attack crits |
| Ranged | `RANGE_DAMAGE` | Ranged attack crits |
| Spell Damage | `SPELL_DAMAGE` | Direct damage spell crits |
| DoT | `SPELL_PERIODIC_DAMAGE` | Damage over time crits |
| Heal | `SPELL_HEAL` | Direct heal crits |
| HoT | `SPELL_PERIODIC_HEAL` | Heal over time crits |

Only events from the player (`sourceGUID == UnitGUID("player")`) are processed to avoid responding to other players' combat events.

## Compatibility

- **World of Warcraft**: Classic Era (Interface 11504)
- **No external dependencies**

## Contributing

Contributions are welcome! The codebase is small and well-commented. Areas for improvement:

- Additional frame type detection
- Configurable intensity/duration via UI
- Support for other WoW versions

## License

This project is open source and available under the MIT License.
