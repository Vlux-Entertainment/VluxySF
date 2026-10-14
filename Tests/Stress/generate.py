"""
Generates the stress fixture: one .model.json per SoundGroup, synced into TEST_SOUNDS by stress-place.project.json.

Run from the repository root:  python Tests/Stress/generate.py

The output is fully determined by asset_ids.json and SEED, so the fixture is identical on every machine and every run,
which keeps benchmark numbers comparable. Changing anything here changes the fixture: regenerate, commit the files,
and expect different numbers.
"""

import json
import math
import os
import random

SEED = 42
GROUP_SIZES = []  # 5000, then halved and rounded up until 5: 5000 2500 1250 625 313 157 79 40 20 10 5
size = 5000
while size >= 5:
    GROUP_SIZES.append(size)
    if size == 5:
        break
    size = math.ceil(size / 2)

FOLDER_SIZE = 40
VARIANT_EVERY = 5  # every 5th sound reuses an earlier sound's asset id with different properties
VARIANT_SOURCE_IDS = 200  # variants cycle through the first 200 ids, 10 variants each
VARIANTS_PER_ID = 10

ROLL_OFF_MODES = ["Inverse", "Linear", "InverseTapered", "LinearSquare"]

# Sound names mix the styles real games end up with, weighted so that about 20% of the name text repeats in the way an
# LZ compressor can exploit (measured below): readable names from shared words, gibberish, plain numbers, names with
# odd spacing and casing, and made-up words. Pure word names would repeat about 95%, which flatters compression.
NOUNS = """Door Window Gate Chest Lever Button Footstep Sword Axe Bow Gun Laser Rocket Bomb Engine Car Horn Bell Alarm
Wind Rain Thunder Fire Ice Glass Metal Wood Stone Bird Wolf Dog Dragon Ghost Zombie Boss Coin Gem Potion Key Drum
Piano Guitar Heart Punch Slash Beam Spark Click Menu Reward Level Quest Error Cave Forest Castle Tower""".split()
ADJECTIVES = "Big Small Heavy Soft Loud Quiet Distant Deep Fast Slow Dark Cold Hot Rusty Magic Frozen Golden Shadow Wild Calm".split()
ACTIONS = """Open Close Hit Break Swing Fire Reload Drop Pickup Use Start Stop Loop Crash Bounce Shatter Explode Pop Ding
Beep Roar Win Lose Walk Run Land""".split()
CATEGORIES = ["SFX", "UI", "Amb", "Music", "VO", "FX"]
CONSONANTS, VOWELS = "bcdfghjklmnprstvwxyz", "aeiou"
GIBBERISH = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

here = os.path.dirname(os.path.abspath(__file__))
ids = json.load(open(os.path.join(here, "asset_ids.json")))
rng = random.Random(SEED)

def rounded(value, places=3):
    return round(value, places)


def sound_properties():
    properties = {
        "Volume": rounded(rng.uniform(0.1, 1)),
        "RollOffMaxDistance": rng.randint(40, 300),
        "RollOffMinDistance": rng.randint(5, 20),
    }
    if rng.random() < 0.3:
        properties["PlaybackSpeed"] = rounded(rng.uniform(0.8, 1.25))
    if rng.random() < 0.25:
        properties["RollOffMode"] = rng.choice(ROLL_OFF_MODES)
    if rng.random() < 0.15:
        properties["Looped"] = True
    return properties


def sound_effects():
    roll = rng.random()
    if roll < 0.1:
        return [{"Name": "ReverbSoundEffect", "ClassName": "ReverbSoundEffect",
                 "Properties": {"DecayTime": rounded(rng.uniform(0.5, 3))}}]
    if roll < 0.15:
        return [{"Name": "EchoSoundEffect", "ClassName": "EchoSoundEffect",
                 "Properties": {"Delay": rounded(rng.uniform(0.1, 0.6)), "Feedback": rounded(rng.uniform(0.2, 0.7))}}]
    if roll < 0.2:
        return [{"Name": "EqualizerSoundEffect", "ClassName": "EqualizerSoundEffect",
                 "Properties": {"HighGain": rounded(rng.uniform(-10, 0)), "LowGain": rounded(rng.uniform(0, 6))}}]
    return []


name_rng = random.Random(SEED + 1)
used_names = {"MainTheme", "BattleOne", "BattleTwo", "Click", "Whoosh", "Explosion"}  # the regular fixture's names


def readable_name(r):
    return r.choice([f"{r.choice(NOUNS)}_{r.choice(ACTIONS)}",
                     f"{r.choice(CATEGORIES)}_{r.choice(NOUNS)}_{r.choice(ACTIONS)}",
                     f"{r.choice(ADJECTIVES)}{r.choice(NOUNS)}{r.randint(1, 20)}"])


def gibberish_name(r):
    return "".join(r.choice(GIBBERISH) for _ in range(r.randint(6, 14)))


def number_name(r):
    return str(r.randint(10 ** 5, 10 ** 12))


def odd_name(r):
    words = [r.choice(NOUNS + ADJECTIVES + ACTIONS) for _ in range(r.randint(2, 3))]
    words = [word.upper() if r.random() < 0.3 else word.lower() if r.random() < 0.5 else word for word in words]
    name = r.choice([" ", "  ", " - ", ".", " _ ", "   "]).join(words)
    if r.random() < 0.5:
        name += f" {r.randint(1, 99)}"
    return (" " if r.random() < 0.2 else "") + name + (" " if r.random() < 0.2 else "")


def made_up_name(r):
    word = "".join(r.choice(CONSONANTS) + r.choice(VOWELS) for _ in range(r.randint(2, 4)))
    return word.capitalize() + (str(r.randint(1, 30)) if r.random() < 0.3 else "")


NAME_STYLES = [readable_name, gibberish_name, number_name, odd_name, made_up_name]
NAME_WEIGHTS = [6, 72, 4, 8, 10]


def random_name():
    while True:
        name = name_rng.choices(NAME_STYLES, NAME_WEIGHTS)[0](name_rng)
        if name not in used_names:
            used_names.add(name)
            return name


def lz_coverage(data):
    """Share of bytes a greedy LZ4-style matcher (min match 4, 64 KB window) covers with back references."""
    table, position, covered = {}, 0, 0
    while position <= len(data) - 4:
        key = data[position:position + 4]
        candidate = table.get(key)
        table[key] = position
        if candidate is not None and position - candidate <= 65535:
            length = 4
            while position + length < len(data) and data[candidate + length] == data[position + length]:
                length += 1
            covered += length
            position += length
        else:
            position += 1
    return covered / max(len(data), 1)


sound_index = 0
unique_used = 0
variants_made = 0
all_names = []

for group_size in GROUP_SIZES:
    group_name = f"Stress{group_size}"
    folders = []
    for folder_start in range(0, group_size, FOLDER_SIZE):
        children = []
        for _ in range(folder_start, min(folder_start + FOLDER_SIZE, group_size)):
            sound_index += 1
            if sound_index % VARIANT_EVERY == 0:
                asset_id = ids[(variants_made // VARIANTS_PER_ID) % VARIANT_SOURCE_IDS]
                variants_made += 1
            else:
                asset_id = ids[unique_used]
                unique_used += 1

            properties = {"SoundId": f"rbxassetid://{asset_id}", **sound_properties()}
            name = random_name()
            all_names.append(name)
            sound = {"Name": name, "ClassName": "Sound", "Properties": properties}
            effects = sound_effects()
            if effects:
                sound["Children"] = effects
            children.append(sound)
        folders.append({"Name": f"Folder{len(folders) + 1}", "ClassName": "Folder", "Children": children})

    model = {"ClassName": "Configuration", "Children": folders}

    # one sound per line keeps the files small and still readable in a diff
    lines = ["{", '\t"ClassName": "Configuration",', '\t"Children": [']
    for folder_number, folder in enumerate(folders):
        lines.append(f'\t\t{{ "Name": {json.dumps(folder["Name"])}, "ClassName": "Folder", "Children": [')
        for child_number, child in enumerate(folder["Children"]):
            comma = "," if child_number < len(folder["Children"]) - 1 else ""
            lines.append("\t\t\t" + json.dumps(child, separators=(", ", ": ")) + comma)
        lines.append("\t\t] }" + ("," if folder_number < len(folders) - 1 else ""))
    lines.append("\t]")
    lines.append("}")

    with open(os.path.join(here, f"{group_name}.model.json"), "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines) + "\n")

print(f"{len(GROUP_SIZES)} groups {GROUP_SIZES}, {sound_index} sounds, "
      f"{unique_used} unique ids, {variants_made} variants")

uniform = [f"StressSound{index}" for index in range(1, sound_index + 1)]
print(f"names: {len(all_names)} unique, average {sum(map(len, all_names)) / len(all_names):.1f} characters, "
      f"{lz_coverage(chr(10).join(all_names).encode()):.0%} repeated for LZ "
      f"(StressSound1..N would be {lz_coverage(chr(10).join(uniform).encode()):.0%})")
