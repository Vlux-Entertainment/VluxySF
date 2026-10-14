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


sound_index = 0
unique_used = 0
variants_made = 0

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
            sound = {"Name": f"StressSound{sound_index}", "ClassName": "Sound", "Properties": properties}
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
