---
sidebar_position: 6
---

# Wrapping Sounds

`VluxySF.Fetch` returns a plain `Sound`. If you want every fetch to give you your own class instead, with methods like `FadeIn` or `SetLooped`, use `VluxySF.WithWrapper`.

```lua
local sound = Sounds.Fetch("LoFiBeat1") -- your class, not a Sound
sound:SetLooped(true):FadeIn(2)
```

This page sets that up so it is written once and fully typed everywhere.

---

## How it works

`WithWrapper` takes a function that turns a `Sound` into your class, and returns a copy of the library whose `Fetch` and `TryFetch` return your class.

- **It is fully typed.** Whatever type your function returns is what `Fetch` returns, so autocomplete and `--!strict` see your class's methods. No casts.
- **It does not change `VluxySF`.** Scripts and packages that require `VluxySF` directly still get plain `Sound`s. Only code that uses the wrapped copy gets your class.
- **Everything else is the same.** `Startup`, `Schema`, `Groups`, `Preload`, `Cache`, `Conversions`, `Presets`, `Jitter` and `OneShot` are the library's own.

---

## 1. Write the wrapper class

The class takes the fetched `Sound` in its constructor. Export its type so `WithWrapper` can pass it through.

```lua
--!strict
-- ReplicatedStorage/Shared/SoundWrapper.luau

local TweenService = game:GetService("TweenService")

local SoundWrapper = {}
SoundWrapper.__index = SoundWrapper

export type SoundWrapper = typeof(setmetatable(
	{} :: {
		Sound: Sound,
		_tween: Tween?,
	},
	SoundWrapper
))

function SoundWrapper.new(sound: Sound): SoundWrapper
	return setmetatable({ Sound = sound, _tween = nil }, SoundWrapper)
end

function SoundWrapper.SetLooped(self: SoundWrapper, looped: boolean): SoundWrapper
	self.Sound.Looped = looped

	return self
end

function SoundWrapper.FadeTo(self: SoundWrapper, volume: number, seconds: number): SoundWrapper
	if self._tween then
		self._tween:Cancel()
	end

	local tween = TweenService:Create(self.Sound, TweenInfo.new(seconds), { Volume = volume })
	self._tween = tween
	tween:Play()

	return self
end

function SoundWrapper.FadeIn(self: SoundWrapper, seconds: number): SoundWrapper
	local volume = self.Sound.Volume
	self.Sound.Volume = 0
	self.Sound:Play()

	return self:FadeTo(volume, seconds)
end

function SoundWrapper.Destroy(self: SoundWrapper)
	if self._tween then
		self._tween:Cancel()
		self._tween = nil
	end

	self.Sound:Destroy()
end

return SoundWrapper
```

:::caution
Clean up what your class starts. A fade that keeps running, or a connection that is never disconnected, outlives the sound. Give the class a `Destroy` that cancels them and destroys the `Sound`, and call it instead of `Sound:Destroy()`.
:::

---

## 2. Wrap the library once

Make one module that returns the wrapped library. This is the only place `WithWrapper` is called.

```lua
--!strict
-- ReplicatedStorage/Shared/Sounds.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)
local SoundWrapper = require(script.Parent.SoundWrapper)

return VluxySF.WithWrapper(SoundWrapper.new)
```

Roblox runs a module once and hands every script the same result, so the wrapped library is built once and shared by every script on that side.

:::tip
Put this module in `ReplicatedStorage` so server and client scripts can both require it. With Rojo, that is any folder your project file maps into `ReplicatedStorage`, for example `src/shared`.
:::

---

## 3. Require it everywhere

Scripts require your `Sounds` module instead of `VluxySF`. Starting the library works the same through it.

```lua
-- Server script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

Sounds.Startup.InitServer(ServerStorage.SOUNDS)
```

```lua
-- Any client script
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

Sounds.Startup.WaitUntilReady()

local music = Sounds.Fetch("LoFiBeat1", workspace)
music:SetLooped(true):FadeIn(2)
```

See [Initialization](./Setup.md) for where `InitServer` and `InitClient` go.

---

## What changes and what does not

| | Wrapped copy |
|---|---|
| `Fetch` | Returns your class. An unknown name still warns, and the blank sound it returns is wrapped too. |
| `TryFetch` | Returns your class, or `nil` for an unknown name without calling your function. |
| `OneShot` | Unchanged. It returns a cleanup function, not a sound. |
| Presets | Run on the `Sound` before it is wrapped, so existing presets keep working. |
| Parent | Set before wrapping, the same as an unwrapped fetch. |
| Everything else | The library's own `Startup`, `Schema`, `Groups`, `Preload`, `Cache`, `Conversions`, `Presets` and `Jitter`. |

:::warning
Do not assign to `VluxySF.Fetch` to get the same effect. The library table is frozen, and replacing a shared module's function would change it for every script and package in the game. `WithWrapper` gives you a separate copy instead.
:::
