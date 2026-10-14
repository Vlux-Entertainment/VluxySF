---
sidebar_position: 14
---

# Cookbook

Complete, copyable examples for common jobs. Each one assumes the library has [started](./Setup.md) and the script waited for it with `VluxySF.Startup.WaitUntilReady()`. Swap the example sound names for your own.

---

## Footsteps that do not sound robotic

Plays a step for each foot with a little volume and speed variation, so a hundred steps in a row still sound natural.

```lua
-- LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.WaitUntilReady()

local stepPreset = VluxySF.Presets.Combine(
	VluxySF.Presets.NaturalVolumeJitter(0.6, 0.1),
	VluxySF.Presets.NaturalPlaybackJitter(1, 0.08)
)

local function playStep(foot: BasePart, material: Enum.Material)
	local name = if material == Enum.Material.Wood then "Footstep_Wood" else "Footstep_Default"

	VluxySF.OneShot(name, foot, stepPreset)
end
```

Build the preset once and reuse it. `Natural` jitter keeps most steps close to the center value, which sounds more like real footsteps than an even spread.

---

## Volume settings that save

A settings menu with a slider per group that saves between sessions. The client sets the volumes, so each player hears their own settings.

```lua
-- ServerScript: stores each player's volumes
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("SoundSettings")
local remote = Instance.new("RemoteFunction")
remote.Name = "SoundSettings"
remote.Parent = ReplicatedStorage

remote.OnServerInvoke = function(player: Player, saved: any)
	if saved == nil then
		local success, data = pcall(store.GetAsync, store, player.UserId)

		return if success then data else nil
	end

	pcall(store.SetAsync, store, player.UserId, saved)

	return nil
end
```

```lua
-- LocalScript: applies and saves them
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)
local remote = ReplicatedStorage:WaitForChild("SoundSettings") :: RemoteFunction

VluxySF.Startup.WaitUntilReady()

local saved = remote:InvokeServer(nil)
if saved then
	VluxySF.Groups.SetMainVolume(saved.Main)
	VluxySF.Groups.SetVolumes(saved.Groups)
end

local function save()
	remote:InvokeServer({
		Main = VluxySF.Groups.GetMainVolume(),
		Groups = VluxySF.Groups.GetVolumes(),
	})
end

-- Hook these to your sliders.
local function onGroupSlider(groupName: string, value: number)
	VluxySF.Groups.SetVolume(groupName, value)
end

local function onMainSlider(value: number)
	VluxySF.Groups.SetMainVolume(value)
end

-- Call save() when the settings menu closes, not on every slider move.
```

Saved data that no longer matches your game is safe to load: a group that was renamed or removed is skipped with a warning, and a volume outside 0 to 10 is ignored.

---

## Sounds on a loading screen

To play sounds while your game is still loading, start the library from a `LocalScript` in `ReplicatedFirst` and preload the loading screen's sounds first.

```lua
-- LocalScript in ReplicatedFirst
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("VluxySF"))

VluxySF.Startup.InitClient(0) -- Do not wait for the tagged preloads here.
VluxySF.Preload.AddAsync("Loading_Music", "Loading_Click")

local music = VluxySF.Fetch("Loading_Music")
music.Looped = true
music:Play()

-- When loading is done:
-- music:Destroy()
```

`InitClient` waits for the sounds to reach the client, so this works however early the script runs. Only call `InitClient` once: other client scripts should use `WaitUntilReady`.

---

## Optional voice lines

Not every NPC has every voice line. `Schema.Has` checks without a warning, and `TryFetch` returns `nil` for a missing sound.

```lua
local function speak(npc: Model, line: string)
	local name = `VO_{npc.Name}_{line}`

	if not VluxySF.Schema.Has(name) then
		return -- This NPC has no recording for this line.
	end

	VluxySF.OneShot(name, npc:FindFirstChild("Head"))
end
```

---

## Getting a boss fight ready

Preload the sounds that must be heard instantly, warm the ones that will be fetched many times, and let them go when the fight ends.

```lua
local function onBossFightStarting()
	VluxySF.Preload.AddAsync("Boss_Theme") -- The music must start without a gap.
	VluxySF.Cache.Warm("Boss_Roar", "Boss_Stomp", "Boss_Slam")
end

local function onBossFightEnded()
	VluxySF.Cache.Chill("Boss_Roar", "Boss_Stomp", "Boss_Slam")
end
```

Chilling only removes the kept copies; sounds already playing carry on. Preloading has no undo, so only preload what the fight cannot do without.

---

## Fading music in and out

VluxySF gives you plain `Sound`s; fades are up to your code. With a [wrapper class](./Wrapping.md) every fetch can come with fade methods. Without one, a tween does the job:

```lua
local TweenService = game:GetService("TweenService")

local function playMusic(name: string, fadeSeconds: number): Sound
	local music = VluxySF.Fetch(name, workspace)
	local volume = music.Volume

	music.Volume = 0
	music:Play()
	TweenService:Create(music, TweenInfo.new(fadeSeconds), { Volume = volume }):Play()

	return music
end

local function stopMusic(music: Sound, fadeSeconds: number)
	local fade = TweenService:Create(music, TweenInfo.new(fadeSeconds), { Volume = 0 })
	fade.Completed:Once(function()
		music:Destroy()
	end)
	fade:Play()
end

local current = playMusic("Lobby_Theme", 2)

-- Switching areas:
stopMusic(current, 2)
current = playMusic("Forest_Theme", 2)
```
