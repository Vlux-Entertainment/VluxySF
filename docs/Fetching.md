---
sidebar_position: 6
---

# Fetching Sounds

Fetching builds a fresh `Sound` from the one you set up in Studio, with its properties, effects and SoundGroup. There are three ways to fetch, depending on what you need the sound for.

| Function | Gives you | Use it when |
|---|---|---|
| `Fetch(name, parent?, preset?)` | A `Sound`, always | You play and manage the sound yourself |
| `TryFetch(name, parent?, preset?)` | A `Sound` or `nil` | The sound might not exist |
| `OneShot(name, parent?, preset?)` | A function that stops it early | You want it played once and cleaned up |

Every example on this page assumes the library has [started](./Setup.md) and that this script has waited for it:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.WaitUntilReady()
```

:::note
Names like `"MainTheme"` are example sound names. Use the names of the sounds in your own `SOUNDS` Configuration.
:::

---

## Fetch

`Fetch` is the main function of the library. It always gives you a `Sound`, so your code never needs a `nil` check.

```lua
local music = VluxySF.Fetch("MainTheme", workspace)
music.Volume = 0.3
music:Play()

-- Later, when it is no longer needed:
music:Destroy()
```

A fetched `Sound` is yours: play it, change it, and destroy it when you are done.

If the name is not in your sounds, a warning is printed and you get a silent blank `Sound` named `VluxySF_Blank_Sound`, so the rest of your code keeps running.

Effects come along with the sound, named after their class, so you can reach them the same way whatever they were called in Studio:

```lua
local explosion = VluxySF.Fetch("Explosion", part)

local echo = explosion:FindFirstChild("EchoSoundEffect")
if echo then
	echo.WetLevel = 0.5
end
```

---

## TryFetch

`TryFetch` is the same as `Fetch`, but gives you `nil` instead of a blank sound when the name is not in your sounds. Use it when the name is built at runtime, or when a sound is optional.

```lua
local voiceLine = VluxySF.TryFetch(`VO_{npcName}_Greeting`, npc.Head)

if voiceLine then
	voiceLine:Play()
end
```

It still prints a warning for a missing name. To check whether a sound exists without any warning, use `VluxySF.Schema.Has(name)`.

---

## OneShot

`OneShot` is for the sounds you just want to hear: a hit, a click, a footstep. It fetches the sound, turns looping off, plays it and destroys it when it ends.

```lua
VluxySF.OneShot("SwordHit", character.HumanoidRootPart)
```

It returns a function that stops the sound early, in case you need to cut it off:

```lua
local stopCharge = VluxySF.OneShot("ChargeUp", character.HumanoidRootPart)

-- The player let go before the charge finished.
stopCharge()
```

You never have to wait for a one-shot's audio to load. Roblox holds a played sound until its audio arrives and then plays it from the beginning. A sound whose audio never loads, because it was deleted, moderated or is private, is destroyed after 10 seconds with a warning, so nothing is left behind.

Destroying the parent while a one-shot plays is fine: the sound goes with it, and nothing is reported.

:::info
`Sound.Played` fires as soon as the sound is played, which can be before its audio has loaded. If your code needs the sound to actually be audible, wait for `Sound.Loaded`.
:::

---

## Choosing a parent

The second argument of every fetch function is the parent. Give it a `BasePart` or an `Attachment` to play the sound from that spot in the world:

```lua
VluxySF.OneShot("DoorCreak", workspace.Door)
```

A sound fetched without a parent goes into a Configuration named `UnattachedSounds` in `SoundService`, where it plays everywhere at the same volume. It stays there until it is destroyed, so destroy sounds you fetched with `Fetch` once you are done with them. `OneShot` does that for you.

A parent that is not an Instance is ignored with a warning, and a parent that refuses the sound (a locked or destroyed Instance) sends it to `UnattachedSounds` with a warning. Neither throws into your code.

---

## Using presets

The third argument is a preset: a function that adjusts the sound before it is parented, for settings you apply over and over. Presets have [their own page](./Presets.md).

```lua
local quiet = VluxySF.Presets.Volume(0.2)

VluxySF.OneShot("UIClick", nil, quiet)
```

Something that is not a function is ignored with a warning. An error thrown inside your own preset is yours and propagates; the sound it was applied to is destroyed first.

---

## Before the library has started

Fetching before the library has started does not error. `Fetch` gives you a blank sound, `TryFetch` gives you `nil` and `OneShot` plays nothing. The blank sound is parented to the parent you gave, so nothing lands in the wrong place, and stays unparented otherwise; the preset is not applied to it. The first time this happens a warning is printed, so you can find the script that needs to [wait for the library](./Setup.md#3-use-it-from-other-scripts).
