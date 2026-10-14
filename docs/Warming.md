---
sidebar_position: 11
---

# Warming and Chilling

Warming builds a sound once, effects included, and keeps the ready-made `Sound` around. While it is warm, every `Fetch` of that sound clones the kept copy instead of building a new one. Chilling throws the kept copy away again.

Use it for sounds that matter during one part of the game: warm them before that part starts, and chill them when it ends.

Warming only works on the client.

---

## Warm and chill

```lua
-- The boss fight is about to start.
VluxySF.Cache.Warm("BossTheme", "BossRoar", "BossStomp")

-- During the fight, fetches clone the warm copies.
VluxySF.OneShot("BossRoar", boss.Head)

-- The fight is over.
VluxySF.Cache.Chill("BossTheme", "BossRoar", "BossStomp")
```

Chilling only removes the kept copy. Sounds you already fetched keep playing.

To check what is warm:

```lua
print(VluxySF.Cache.IsWarmed("BossRoar")) -- true or false
print(VluxySF.Cache.GetNames()) -- Every warm sound.
```

---

## Warming or preloading?

They solve different problems, and you can use both on the same sound.

| | [Preloading](./Preloading.md) | Warming |
|---|---|---|
| Keeps ready | The downloaded **audio** | A built **`Sound`** |
| Waits for the download | Yes | No |
| Lasts | The whole session | Until you chill it |

Keeping a warm `Sound` also makes Roblox start downloading its audio, but warming does not wait for that. When a sound has to be audible the moment it plays, preload it.

:::note
For simple sounds, cloning a warm copy is about as fast as building a new one. Warming pays off most for sounds with several effects, where building takes more work.
:::
