---
sidebar_position: 4
---




# Folder Setup

VluxySF makes it easy to manage all your game’s sounds. This guide will walk you through best practices for organizing, grouping, and preloading your audio assets.

---
---

## The Basics: Folder Structure

VluxySF uses your folder structure to automatically group and identify sounds.  

**You do not need to manually assign SoundGroups or create them!**

---

**Legend:**
```
⚙️ = Configuration Instance
📁 = Folder Instance
🔊 = Sound Instance
```


**Naming Conventions:**

- *`UPPER_CASE`* for `SoundGroups`
- *`PascalCase`* for ` Folders` is recommended but most naming convention will work
- *`PascalCase`* or *`camelCase`* for `Sounds` is recommended but most naming convention will work
- `Sound` names are used as keys for programmatic access (e.g., `VluxySF.Fetch("explosion1")`).

---

**Example:**
```
SOUNDS⚙️               ← Base file
  ├─ MUSIC⚙️           ← Name of SoundGroup
  │    ├─ mainTheme🔊  ← Grouped to MUSIC SoundGroup
  │    └─ battle🔊     ← Grouped to MUSIC SoundGroup
  └─ SFX⚙️             ← Name of SoundGroup
        ├─ click🔊     ← Grouped to SFX SoundGroup
        └─ explosion🔊 ← Grouped to SFX SoundGroup
```
*Music and SFX become `SoundGroups`, and their children are grouped accordingly.*


> **Tip:** Once `SoundGroup Configurations` are defined (MUSIC, SFX, etc.), organization within them is your choice.

---



### Organizing with Subfolders

You can use additional folders (📁) inside SoundGroups to keep your sounds organized.

**Example:**
```
SOUNDS⚙️
  └─ SFX⚙️
      ├─ UI📁
      │    └─ click🔊
      └─ Game📁
          └─ explosion🔊
```


> **Tip:** Organize your folders however you want! The heiarchy does not effect the library.
>
> **Note:** All `Sounds` need to have unique names. A warning will appear at runtime if you go against this.

---
---

## Preloading Sounds Automatically

Want certain sounds to be ready instantly? You can tag any Folder or Sound with `VluxySF_Preload` and it will automaticly preload once the client is started.

**How to use:**
```
SOUNDS⚙️
  ├─ MUSIC⚙️
  │    ├─ mainTheme🔊
  │    └─ battles📁 <-- you can tag with "VluxySF_Preload" to preload sounds within this folder
          ├─ importantSound1🔊
          └─ importantSound2🔊
  └─ SFX⚙️
        ├─ click🔊
        ├─ explosions📁
          ├─ CommonExplosionSound🔊 <-- You can tag with "VluxySF_Preload" to preload this sound
          └─ UncommonLongExplosionSound🔊
```

### Preload Timeout
You can set an optional timeout (in seconds) for preloading. If preloading takes too long, it will continue in the background. Default is 5 seconds.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

local preloadTimeout = 10
VluxySF._initClient(preloadTimeout)

-- <-- reaches this line once sounds are preloaded or timeout is reached
```

---
---

## Configuring Sound Instances

Each Sound instance can be customized with any Roblox sound properties and child sound effects except for the Parent:

- **Properties:** Set properties like `SoundId`, `Volume`, `PlaybackSpeed`, etc, directly on the Sound instance.
- **Effects:** Add child instances such as `EqualizerSoundEffect`, `ReverbSoundEffect`, etc, to the Sound Instance.

>**Note:** Any Instances parented to a `Sound` thats not a `SoundEffect` will not be serialized.
>
>**Note:** Only 1 of each `Class` will be serialized.

---
---

## End Result


A `SOUNDS Configuration` should look something like this when you’re done in Roblox Studio:

![Folder Structure Example](/SoundsConfigExample1.png)
> **Note:** This should be inside `ServerStorage`. It is recommended to make it a direct child of that service.


---
