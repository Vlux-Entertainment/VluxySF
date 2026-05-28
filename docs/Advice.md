---
sidebar_position: 6
---



# Advice

Here ill give you some advice on how to have a good time using this library and stuff about sounds in `Roblox`.

---
---

## Why this library exists?

<b>This library is designed for fast iteration and small to medium sized games!</b>
>
I made it because I didnt want to have to search through folders to find the sound I wanted. I would have to write multiple lines just to go fetch the sound I wanted and I found it anoying. On top of that if the sound location changed or the sound didnt exist anymore the entire block would error. So, of course i spend over 100 hours trying to fix that with a library as thats completly logical!!!

*This can also work in larger games without much issue the only bottleneck is that it becomes less convenient to use after a cetain amount of sounds. And thats because there is no heiarchy when fetching sounds; its completly flat. So, the difficulty of naming a sound with a unique name scales up as the amount of sounds scale up.*

For the `Extension` there is a `limit of 800 sounds` as that should be a safe number for a `Language Server` to not error. But, the library itself should be able to handle a few thousand sounds no problem if you don't care for the `Extension`.

## Library Setup

- You should adjust your sounds in studios `EditMode` for your most common use case. Then use presets or manually adjust your sounds if you need to change small things about them at runtime. If a sounds properties are too diffrent from the original copy then it may be better to just make a new `Sound` even if it has the same `SoundID`.

- Sounds should not determine your `Buisness Logic` atleast 95% of the time. Sounds should go ontop of your code not mold it.

---
---

## Memory Optimizations

Optimizations may be important if you need your game to run on cellular devices or old devices.

---

### Optimization List

- Use 3rdParty Software like Audacity or FL Studio to compress the audio size.

- Only Preload sounds that you know needs it.

- Lazy Load your sounds wherever possible.

- Delete Sounds when you know you dont need them for the moment.

---

### Sound Editing

Sound editing should be a last resort as that that is the most tedious of the methods. Also there is a monthly import limit in roblox for audio. But this is the best memory saving method if its worth it to you.

---

### Pre Loading

This library makes preloading easy as you just need to tag with `VluxySF_Preload`. But just because its easy that doesn't mean you should preload everything. Especially if your game is going to be using more than 20 sounds. The more Sounds you preload the more memory will be taken up throught the game. There is no way to revert `Preloading` a `Sound`.

---

### Lazy Loading

Lazy loading is when you only create an object when its needed. This library makes that easy as you just need to call `VluxySF.Fetch`.

*Just make sure that you call that function right when you need the sound and there you go!*

<b>This will only work if the soundID was not preloaded and there is no other sounds with the same soundID!</b>

---

### Deleting Your Sound

If you want to save more memory then just delete the sound made by the `VluxySF` library once your done playing it. By using `VluxySF.FetchPlayNow` it will automaticly do this for you.

<b>This will only work if the soundID was not preloaded and there is no other sounds with the same soundID!</b>

---

## When to optimize?

It may depend on the Project but in most cases if your codebase is designed well or well enough it can be done later down the line.

For instance, maybe your just polishing your game up. Well that could be the best time to start optimizing your sound memory if its needed.

<b>But of course only optimize when you need too and if you need too!</b>

---