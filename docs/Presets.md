---
sidebar_position: 9
---

# Presets and Jitter

A preset is a function that adjusts a `Sound` as it is fetched. Pass one as the third argument of `Fetch`, `TryFetch` or `OneShot` to set a sound up the same way every time. It runs before the sound is parented.

Jitter gives small random variations to values like volume and speed, so a sound that plays over and over does not sound robotic.

---

## Built-in presets

| Preset | What it does |
|---|---|
| `Volume(volume)` | Sets `Volume` |
| `PlaybackSpeed(speed)` | Sets `PlaybackSpeed` |
| `Parent(instance)` | Sets the parent |
| `NaturalVolumeJitter(center?, spread?)` | A slightly different volume each time, usually close to the center |
| `NaturalPlaybackJitter(center?, spread?)` | A slightly different speed each time, usually close to the center |
| `RandomVolumeJitter(center?, spread?)` | A volume anywhere in the range, evenly spread |
| `RandomPlaybackJitter(center?, spread?)` | A speed anywhere in the range, evenly spread |
| `Combine(...)` | Applies several presets in order |

```lua
local presets = VluxySF.Presets

VluxySF.OneShot("UIClick", nil, presets.Volume(0.4))
```

See the [Presets API](/api/Presets) for the defaults and an example of each.

A built-in preset never throws. A builder given a bad argument, like `Volume("loud")` or `Parent(nil)`, warns right where it was called and returns a preset that does nothing, so the sounds that use it still play. `Parent` with an Instance that refuses the sound by the time it is fetched warns and leaves the sound where the fetch puts an unparented one.

---

## Combining presets

`Combine` merges presets into one. They run in the order you list them.

```lua
local presets = VluxySF.Presets

local impact = presets.Combine(
	presets.NaturalVolumeJitter(0.8, 0.12),
	presets.NaturalPlaybackJitter(1, 0.09)
)

VluxySF.OneShot("RockImpact", part, impact)
VluxySF.OneShot("WoodImpact", part, impact)
```

A parent passed to the fetch function wins over a parent set by a preset.

---

## Making your own

A preset is any function that takes a `Sound`. When it needs settings, write a function that returns one:

```lua
local function startAt(seconds: number): (Sound) -> ()
	return function(sound: Sound)
		sound.TimePosition = seconds
	end
end

VluxySF.OneShot("LongIntro", nil, startAt(2.5))
```

Keep your own presets in a module and use them next to the built-in ones.

:::tip
Use presets to set properties and other quick, one-time setup. Anything that has to keep running while the sound plays, like a fade, belongs in your own code or a [wrapper class](./Wrapping.md).
:::

---

## Jitter on its own

The jitter presets are built from `VluxySF.Jitter`, which you can use directly. A jitter is a function that gives a new value every time you call it.

```lua
local stepVolume = VluxySF.Jitter.Natural(0.6, 0.1)

local function playFootstep(foot: BasePart)
	VluxySF.OneShot("Footstep", foot, VluxySF.Presets.Volume(stepVolume()))
end
```

| Jitter | Values |
|---|---|
| `Uniform(center, spread)` | Anywhere from `center - spread` to `center + spread`, evenly spread |
| `Natural(center, spread)` | Same range, but mostly close to the center. Sounds more natural for repeated sounds like footsteps |
| `Range(min, max)` | Anywhere from `min` to `max` |

Jitter values never go below 0. A builder given something that is not a number warns and falls back to a value with no variation; `Range` with its bounds reversed swaps them. See the [Jitter API](/api/Jitter) for details.
