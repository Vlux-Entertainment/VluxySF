---
sidebar_position: 6
---

# Extension

VluxySF comes with a companion VS Code `Extension`, which brings its own Roblox Studio `Plugin`. Together they give you autocomplete and type checking for your sound names.

Using it is completely optional.

![Extension Use Example](/VluxySFExtensionExample1.png)

---

## Setup

1. Install the [Extension](https://github.com/Vlux-Entertainment/VluxySFExtension) in VS Code.
2. Get the `Plugin` into Roblox Studio:
   - **Extension `0.5.0` or newer:** the extension installs the plugin for you as a local plugin and keeps it up to date. Restart Roblox Studio when the extension says the plugin was installed.
   - **Older versions:** install the [Plugin](https://create.roblox.com/store/asset/135156375922001/Vluxy-Sound-Factory-Companion?viewFromStudio=true&keyword=&searchId=58eb3ad0-447b-4e8d-a720-bca87c689362) from the Creator Store yourself.
3. Make sure the port matches in the extension and the plugin. By default it is `7842`.
4. Click the VluxySF icon in the Plugins tab of Studio. You should hear a connect sound.

If it stays connected, you are ready to bake your types.

:::warning
If you update the extension to `0.5.0` or newer, remove the Creator Store plugin in Studio's plugin manager. Otherwise two copies of the plugin will run.
:::

---

## How it works

The companion software bakes types for you. More specifically, it makes a union of string literals out of every sound name under your `SOUNDS` Configuration.

The plugin reads the sound names in Studio and sends them to the extension. The extension then writes them into a small file inside the VluxySF package named `_vluxysf_sound_name_types.luau`. The library uses that type for the name argument of its fetch functions.

By default, the file looks like this:

```lua
--!strict

export type GeneratedSoundNames = string

return nil
```

Once baked, it looks like this:

```lua
--!strict

export type GeneratedSoundNames = "A Cure for All" | "Agaiiiiiin" | "Bubble Pop Parade" | "Clara OL" | ...

return nil
```

With the `Loose Name Types` setting turned on in the extension, any other string is allowed too:

```lua
--!strict

export type GeneratedSoundNames = string | "A Cure for All" | "Agaiiiiiin" | "Bubble Pop Parade" | "Clara OL" | ...

return nil
```

:::note
This extension has a **limit of 800 sounds** for type baking! That should be a safe number for a language server to handle without errors.
:::

---

## Recommended editor setup

It is highly recommended that you use [Luau-LSP](https://github.com/JohnnyMorganz/luau-lsp) as your language server.

:::tip
If you use `Luau-LSP`, make sure `Enable Fragment AutoComplete` is off. At the moment (2/28/2026) it stops inline suggestions from popping up most of the time.
:::
