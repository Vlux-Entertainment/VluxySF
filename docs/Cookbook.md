---
sidebar_position: 10
---

# Cookbook

Complete examples for common jobs. Each one assumes the library has been [started](./Setup.md) and that client code waits for it with `VluxySF.Startup.WaitUntilReady()`. Swap the example sound names for your own.

---

## Footsteps

Plays a step sound that matches the floor, with a little volume and speed variation so a hundred steps in a row still sound natural.

```lua
-- LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

local STEP_SOUNDS: { [Enum.Material]: string } = {
	[Enum.Material.Wood] = "Step_Wood",
	[Enum.Material.WoodPlanks] = "Step_Wood",
	[Enum.Material.Grass] = "Step_Grass",
	[Enum.Material.Concrete] = "Step_Stone",
}

-- Built once and reused for every step.
local stepPreset = VluxySF.Presets.Combine(
	VluxySF.Presets.NaturalVolumeJitter(0.6, 0.1),
	VluxySF.Presets.NaturalPlaybackJitter(1, 0.08)
)

VluxySF.Startup.WaitUntilReady()

local function playStep(foot: BasePart, floor: Enum.Material)
	VluxySF.OneShot(STEP_SOUNDS[floor] or "Step_Default", foot, stepPreset)
end
```

- `Natural` jitter keeps most steps close to the center value, which sounds more like real steps than an even spread.
- Footsteps play constantly from the moment a player spawns, so tag their sounds with `VluxySF_Preload` in Studio. The first step then plays without a gap.

---

## Volume settings that save

Sliders for each SoundGroup and the main volume, saved between sessions. The client applies the volumes, so each player hears their own settings. The server owns the saved data: it checks what the client sends, keeps it in memory, and writes it once when the player leaves.

```lua
-- Script in ServerScriptService
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("SoundSettings")

local getSettings = Instance.new("RemoteFunction")
getSettings.Name = "GetSoundSettings"
getSettings.Parent = ReplicatedStorage

local setSettings = Instance.new("RemoteEvent")
setSettings.Name = "SetSoundSettings"
setSettings.Parent = ReplicatedStorage

local MAX_GROUPS = 32

type Settings = { Main: number, Groups: { [string]: number } }

local settingsByPlayer: { [Player]: Settings } = {}

local function isVolume(value: any): boolean
	return type(value) == "number" and value >= 0 and value <= 10
end

-- Anything a client sends is checked before it is kept.
local function clean(raw: any): Settings?
	if type(raw) ~= "table" or not isVolume(raw.Main) or type(raw.Groups) ~= "table" then
		return nil
	end

	local groups = {}
	local count = 0
	for name, volume in pairs(raw.Groups) do
		count += 1
		if count > MAX_GROUPS or type(name) ~= "string" or not isVolume(volume) then
			return nil
		end
		groups[name] = volume
	end

	return { Main = raw.Main, Groups = groups }
end

Players.PlayerAdded:Connect(function(player)
	local success, saved = pcall(store.GetAsync, store, player.UserId)
	local settings = if success then clean(saved) else nil

	if settings then
		settingsByPlayer[player] = settings
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local settings = settingsByPlayer[player]
	settingsByPlayer[player] = nil

	if settings then
		pcall(store.SetAsync, store, player.UserId, settings)
	end
end)

getSettings.OnServerInvoke = function(player)
	return settingsByPlayer[player]
end

setSettings.OnServerEvent:Connect(function(player, raw)
	local settings = clean(raw)
	if settings then
		settingsByPlayer[player] = settings
	end
end)
```

```lua
-- LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)
local getSettings = ReplicatedStorage:WaitForChild("GetSoundSettings") :: RemoteFunction
local setSettings = ReplicatedStorage:WaitForChild("SetSoundSettings") :: RemoteEvent

VluxySF.Startup.WaitUntilReady()

local saved = getSettings:InvokeServer()
if saved then
	VluxySF.Groups.SetMainVolume(saved.Main)
	VluxySF.Groups.SetVolumes(saved.Groups)
end

-- Connect these to your sliders. Changes are heard right away.
local function onGroupSlider(groupName: string, value: number)
	VluxySF.Groups.SetVolume(groupName, value)
end

local function onMainSlider(value: number)
	VluxySF.Groups.SetMainVolume(value)
end

-- Call this when the settings menu closes, not on every slider move.
local function onSettingsClosed()
	setSettings:FireServer({
		Main = VluxySF.Groups.GetMainVolume(),
		Groups = VluxySF.Groups.GetVolumes(),
	})
end
```

- Saved settings from an older version of your game are safe to load: a group that was renamed or removed is skipped with a warning.
- A real game should also save on `game:BindToClose`, and may want to retry failed DataStore calls.

---

## Mute toggle

The main volume scales every group, so muting is one call. Remember the old volume to restore it.

```lua
local volumeBeforeMute = 1

local function setMuted(muted: boolean)
	if muted then
		volumeBeforeMute = VluxySF.Groups.GetMainVolume()
		VluxySF.Groups.SetMainVolume(0)
	else
		VluxySF.Groups.SetMainVolume(volumeBeforeMute)
	end
end
```

---

## Music that crossfades

A small music player that fades the old track out while the new one fades in. Switching again mid-fade cancels the running fades, so tracks never pile up.

```lua
local TweenService = game:GetService("TweenService")

local FADE = TweenInfo.new(2)

local current: Sound? = nil
local fades: { Tween } = {}

local function fadeTo(sound: Sound, volume: number, onDone: (() -> ())?)
	local tween = TweenService:Create(sound, FADE, { Volume = volume })
	if onDone then
		tween.Completed:Once(onDone)
	end
	table.insert(fades, tween)
	tween:Play()
end

local function playMusic(name: string?)
	for _, tween in fades do
		tween:Cancel()
	end
	table.clear(fades)

	local old = current
	if old then
		fadeTo(old, 0, function()
			old:Destroy()
		end)
	end

	current = nil
	if name then
		local music = VluxySF.Fetch(name, workspace)
		local volume = music.Volume -- The volume you set in Studio.

		music.Looped = true
		music.Volume = 0
		music:Play()
		fadeTo(music, volume)

		current = music
	end
end

playMusic("Lobby_Theme")
playMusic("Forest_Theme") -- Crossfades from the lobby theme.
playMusic(nil) -- Fades out to silence.
```

If you want fades on every sound, give your fetches a [wrapper class](./Wrapping.md) with `FadeIn` and `FadeOut` methods instead.

---

## Getting a boss fight ready

The boss's sounds only matter during the fight. Warm them when the player gets close to the arena and chill them when the fight is over.

```lua
local BOSS_SOUNDS = { "Boss_Theme", "Boss_Roar", "Boss_Stomp", "Boss_Slam" }

local function onArenaApproached()
	VluxySF.Cache.Warm(table.unpack(BOSS_SOUNDS))
end

local function onFightStarted(boss: Model)
	local theme = VluxySF.Fetch("Boss_Theme", workspace)
	theme.Looped = true
	theme:Play()

	VluxySF.OneShot("Boss_Roar", boss:FindFirstChild("Head"))
end

local function onFightEnded()
	VluxySF.Cache.Chill(table.unpack(BOSS_SOUNDS))
end
```

- **Why warm and not preload:** a warm sound is kept on the client with its `SoundId`, so Roblox starts downloading its audio right away. Warming as the player approaches gives the audio time to arrive before the fight, and chilling lets it all go afterwards. Preloading would keep the boss's audio in memory for the rest of the session, and it has no undo.
- Warm early, not at the moment the fight starts, so the download has time to finish.
- Chilling only removes the kept copies. The theme that is already playing keeps playing until you destroy it.

---

## Optional voice lines

Not every character has every line recorded. `Schema.Has` checks for a sound without printing a warning, so missing lines stay quiet.

```lua
local function speak(character: Model, line: string)
	local name = `VO_{character.Name}_{line}`

	if VluxySF.Schema.Has(name) then
		VluxySF.OneShot(name, character:FindFirstChild("Head"))
	end
end

speak(npc, "Greeting")
```

Use `TryFetch` instead when a missing sound is a mistake you want to hear about: it prints a warning and returns `nil`.

---

## Sounds on a loading screen

To play sounds while the rest of your game is still loading, start the library from your loading screen's `LocalScript` in `ReplicatedFirst`.

```lua
-- LocalScript in ReplicatedFirst
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("VluxySF"))

-- 0: do not hold the loading screen back for the sounds tagged to preload.
VluxySF.Startup.InitClient(0)

local music = VluxySF.Fetch("Loading_Music")
music.Looped = true
music:Play() -- Starts as soon as its audio arrives.

-- When loading is done:
-- music:Destroy()
```

- `InitClient` waits for the library's data to reach the client, so this works however early the script runs. Call it only here; other client scripts use `WaitUntilReady`.
- The loading music is not preloaded on purpose: it is only needed for a moment, and a preload would keep it in memory for the whole session.
