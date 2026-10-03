---
sidebar_position: 7
---

# Advice

Here I'll give you some advice on how to have a good time using this library, plus a few things about sounds in Roblox.

---

## Why does this library exist?

**This library is designed for fast iteration and small to medium sized games!**

I made it because I didn't want to search through folders to find the sound I wanted. I had to write multiple lines just to go fetch a sound, and I found it annoying. On top of that, if the sound's location changed or the sound didn't exist anymore, the entire block would error. So, of course, I spent over 100 hours trying to fix that with a library, as that's completely logical!!!

### How far does it scale?

It also works in larger games without much issue. The only bottleneck is that it becomes less convenient after a certain number of sounds. There is no hierarchy when fetching sounds; it is completely flat. So the difficulty of giving every sound a unique name goes up as the number of sounds goes up.

The [Extension](./Extension.md) has a limit of 800 sounds, as that should be a safe number for a language server to handle without errors. The library itself should handle a few thousand sounds with no problem if you don't care for the extension.

---

## Working with the library

- **Set your sounds up in Studio for their most common use.** Adjust each sound in edit mode, then use [presets](./Examples.md#presets) or change properties yourself for the small things that differ at runtime. If a sound ends up too different from its original copy, it may be better to make a new `Sound`, even if it has the same `SoundId`.

- **Sounds should not decide your business logic**, at least 95% of the time. Sounds should go on top of your code, not mold it.

---

## Memory optimizations

Optimizing may be important if your game needs to run on phones or old devices.

In short:

- Only preload the sounds that you know need it.
- Lazy load your sounds wherever possible.
- Destroy sounds when you don't need them for the moment.
- Use third party software like Audacity or FL Studio to compress your audio.

### Preloading

This library makes preloading easy, as you just need to tag a sound with `VluxySF_Preload`. But just because it's easy, that doesn't mean you should preload everything, especially if your game uses more than 20 sounds. The more sounds you preload, the more memory is taken up throughout the game.

:::warning
There is no way to undo preloading a sound.
:::

If a sound only has to be ready for a while, like the sounds of one map, [warm it](./Examples.md#warm-and-chill) instead. You can chill it again once you are done.

### Lazy loading

Lazy loading is when you only create an object when it's needed. This library makes that easy, as you just need to call `VluxySF.Fetch`.

*Just make sure you call that function right when you need the sound, and there you go!*

### Destroying your sounds

If you want to save more memory, destroy the sound made by VluxySF once you're done playing it. `VluxySF.FetchPlayOnce` does this for you automatically.

:::note
Lazy loading and destroying only save memory if the `SoundId` was not preloaded and no other sound with the same `SoundId` exists.
:::

### Sound editing

Editing your audio files should be a last resort, as it is the most tedious of these methods. There is also a monthly import limit for audio in Roblox. But this is the best way to save memory, if it's worth it to you.

---

## When to optimize?

It depends on the project. In most cases, if your codebase is designed well, or well enough, it can be done later down the line.

For instance, maybe you're just polishing your game up. That could be the best time to start optimizing your sound memory, if it's needed.

**But of course, only optimize when you need to, and if you need to!**
