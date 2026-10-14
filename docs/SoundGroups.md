---
sidebar_position: 7
---

# SoundGroups and Volume

Every group Configuration directly under `SOUNDS` becomes a `SoundGroup` with the same name, and every sound inside it plays through that group. All the groups sit under one main `SoundGroup`, also named `SOUNDS`, in `SoundService`.

```
SoundService
  └─ SOUNDS        ← Main SoundGroup: its volume scales everything
       ├─ MUSIC    ← One SoundGroup per group Configuration
       └─ SFX
```

You do not create or assign these yourself; [Folder Setup](./FolderSetup.md) is all it takes.

---

## Setting volumes

```lua
-- One group, for example from a settings slider.
VluxySF.Groups.SetVolume("MUSIC", 0.55)

-- The main volume scales every group.
VluxySF.Groups.SetMainVolume(0.8)

-- Several groups at once.
VluxySF.Groups.SetVolumes({
	MUSIC = 0.55,
	SFX = 0.7,
})
```

A volume is a number from 0 to 10. Anything else, or a group name that does not exist, prints a warning and changes nothing.

:::info
Where you set a volume decides who hears it. On a **client**, a change affects only that player, which is what a settings menu wants. On the **server**, a change replicates to every player.
:::

---

## Reading volumes

`GetVolumes` and `GetMainVolume` give you the current values, which is all you need to save a player's settings and load them again:

```lua
local saved = {
	Main = VluxySF.Groups.GetMainVolume(),
	Groups = VluxySF.Groups.GetVolumes(), -- { MUSIC = 0.55, SFX = 0.7 }
}
```

The [Cookbook](./Cookbook.md#volume-settings-that-save) has a complete settings menu that saves.

---

## Getting the SoundGroups

When you need the `SoundGroup` instances themselves, for example to add your own effect to a whole group:

| Function | Gives you |
|---|---|
| `Groups.Get(name)` | One `SoundGroup`, or `nil` |
| `Groups.GetAll()` | Every `SoundGroup`, keyed by name |
| `Groups.GetMain()` | The main `SoundGroup` |
| `Groups.GetNames()` | Every group name, in the order they appear under `SOUNDS` |

```lua
local sfx = VluxySF.Groups.Get("SFX")

if sfx then
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.Parent = sfx -- Every SFX sound now has reverb on this client.
end
```

See the [Groups API](/api/Groups) for every function.
