# Swift Apple Shortcuts

Run, read and build Shortcuts from Swift — and search every action this Mac
can put in one.

```swift
import AppleShortcuts

// Run one in the background and take what it hands back.
let result = try ShortcutRunner.run("Resize for Web", inputFile: URL(fileURLWithPath: "photo.jpg"))
print(String(decoding: result.output, as: UTF8.self))

// What can this Mac do? 2,094 actions from 89 apps, searched in 8 ms.
let catalog = try ActionCatalog()
for action in try catalog.search("volume") {
    print(action.id, action.name, action.parameters.map(\.key))
}

// Write a new one, checked against that catalogue, signed.
let recipe = Recipe(name: "Quiet", actions: [
    RecipeStep(action: "is.workflow.actions.setvolume", parameters: ["WFVolume": .double(0.2)]),
])
let file = try ShortcutBuilder().write(recipe, to: .downloadsDirectory)
try ShortcutBuilder.offer(file)    // Shortcuts asks a person to add it
```

Much of what Apple lets a Mac do is reachable ONLY as a Shortcuts action —
Focus modes, Home scenes and accessories, appearance, Wi-Fi, a hundred System
Settings toggles. There is no framework for them. A shortcut is the way in,
and this is a way to shortcuts.

## What it does

| Call | What it does |
|---|---|
| `ShortcutLibrary.shortcuts(in:)` | every shortcut, with its folder |
| `ShortcutLibrary.folders()` | every folder |
| `ShortcutLibrary.shortcut(_:)` | one, by name or identifier |
| `ShortcutLibrary.steps(of:catalog:)` | what a shortcut does, action by action |
| `ShortcutRunner.run(_:input:…)` | run one in the background, input in, output back |
| `ActionCatalog.search(_:app:)` | every action this Mac offers, with parameters and their choices |
| `ActionCatalog.action(id:)` | one action in full |
| `ShortcutBuilder.write(_:to:)` | a recipe, checked, as a signed `.shortcut` file |
| `ShortcutBuilder.offer(_:)` | open it in Shortcuts for a person to add |
| `HelperCatalogue.builtIn()` | the fleet's helper shortcuts, one JSON file each |
| `Helper.status()` / `.offer()` / `.run(_:)` | is it installed and current; offer it; run it headless with JSON in |
| `HelperCatalogue.census()` / `.stale(for:)` | every helper's state; old ones to delete |

## Adding a shortcut takes a person — by design

There is no way to put a shortcut into a library without somebody clicking
**Add Shortcut**, and this library does not look for one. Shortcuts'
scripting dictionary is read-only — no `make` — and writing to the library's
database behind a running, iCloud-synced app would be corruption waiting for
the next sync.

So a built shortcut is a signed file, and `offer` opens it: Shortcuts shows
its own sheet, and a person decides. A shortcut can do almost anything, and
that click is the right place for the decision.

## The action catalogue

Shortcuts keeps an index of every action every installed app offers, at
`~/Library/Shortcuts/ToolKit/Tools-prod.v<n>-<uuid>.sqlite`. `ActionCatalog`
reads it read-only. On the Mac this was built on: **2,094 actions from 89
apps** — Shortcuts' own 434, System Settings' 431, Photos' 80 — each with its
parameters, their types, and for an enumeration the values it takes:

```
is.workflow.actions.setvolume — Set Volume
  WFVolumeSetting   Media, Ringtone, Alarms & Timers, Alerts & System Sounds
  WFVolume          number
```

The identifiers and keys are the ones a shortcut file uses, so a recipe built
from them is a shortcut Shortcuts opens. A recipe is checked against the
catalogue before it is written: a misspelt action comes back with the one it
probably meant, and a misspelt parameter with the ones the action takes.

## Recipes

A recipe is data — the shortcut, before it is built:

```json
{
  "name": "Echo",
  "actions": [
    {"action": "is.workflow.actions.gettext",
     "parameters": {"WFTextActionText": "You said: $input"}}
  ]
}
```

Two variables may appear in any string: `$input` — whatever the shortcut was
run with — and `$previous`, the output of the step before. `$$` is a dollar
sign. Neither encoding is guessed. After its first command-line run,
Shortcuts appended a step of its own to a shortcut this library built,
referring to the step before — and the variable it wrote is byte for byte
what the encoder produces for `$previous`; that value is a test. Then a built
recipe using both was added and run: `"You said: $input"` followed by
`"$previous (twice)"`, given "hi there", printed `You said: hi there (twice)`
— from an argument, from stdin, from a file, and with an emoji in it.

## Helpers

A fleet tool that needs a Shortcuts-only action ships a **helper**: one JSON
file in `Helpers/`, compiled in by `python3 Scripts/gen-helpers.py` (a test
fails if the two disagree). Adding a helper is adding a file.

```json
{"id": "settings.focus", "tool": "settings", "title": "Set Focus",
 "description": "Turns a Focus on or off.", "version": 1,
 "icon": {"glyph": 61440, "color": "grey"},
 "input": [{"name": "on", "type": "bool", "description": "on or off"}],
 "output": {"type": "text", "description": "the Focus now"},
 "steps": [{"action": "is.workflow.actions.dnd.set", "parameters": {"Enabled": "$input"}}],
 "notes": [], "replaces": [], "install": "settings doctor --install"}
```

Every file is read strictly (an unknown key anywhere refuses it) and checked
on load: unique ids named `<tool>.<what>`, a one-line description, a version,
the fleet's one colour (grey), a glyph seen in a real shortcut, and steps the
Mac's action catalogue knows (a test). In the library each helper is
`<tool> · <title>` on a grey tile, and its first step is a comment —
the description, "Installed by settings — don't edit; reinstall with
`settings doctor --install`", and `[helper id=settings.focus version=1
recipe=3f9a1c2e]`. That marker, not the name, says what a shortcut is, so
`status` tells current from outdated, edited (`changed`), a copy under
another name (`misnamed`), two that answer to one name (`duplicated`) and a
hand-made one with the name (`unmarked`). `run` checks the input against the
fields and refuses anything not current before it runs; it returns the
output and nothing more — the caller reads back the state it changed.
`shortcut helpers` reports every helper at once. Version 0 with a `name` is
for a helper from before markers (agenda's "agenda set tags").

## Things that cost an afternoon

Each was measured, on macOS 27, and each is a rule in the code.

**A shortcut's first run may wait on a person.** Before a shortcut can hand
its output to a command line, Shortcuts asks on screen — "Allow … to output
1 text item?" — Don't Allow, Allow Once, Always Allow. The run sat for
**18.8 s** until it was answered. After Always Allow it never asked again,
and runs took **0.13–0.17 s**. `run` takes a `patience` after which it says
so, and an optional `timeout`.

**`shortcuts list --folder-name` with a folder that does not exist lists
every shortcut and exits 0.** A wrong answer that looks like the right one.
Folders are checked here first, and a missing one is `noSuchFolder`.

**The action count Shortcuts reports can be wrong.** Its scripting
dictionary said **0** for a shortcut whose one action was in the database.
`steps(of:)` reads the database.

**The Add Shortcut sheet lists none of the actions** of a built shortcut —
"Please review this shortcut before adding it" above an empty space. Whoever
clicks Add is relying on what they were told about it.

**Shortcuts names an added shortcut after the file.** The property list
carries no name; `Shortcut Probe.shortcut` became "Shortcut Probe" — so files
are named after the recipe.

**Signing is fast, unless it is for anyone.** `people-who-know-me` signs on
this Mac in **0.09 s**; `anyone` goes through Apple and took **9 s**. The
output is an Apple Encrypted Archive (`AEA1`), not a property list — keep the
recipe.

**`"\r\n"` again.** A listing split on the newline byte leaves `\r` on each
line, and `.whitespaces` does not trim it. The CRLF test caught every line
being rejected.

## Requirements

macOS 14+. Reading the library's database and the catalogue needs the
terminal to be allowed into `~/Library/Shortcuts`; where it is not, the open
fails as `notPermitted` rather than as a missing file. Both are read in
place and read-only through
[swift-sqlite-reader](https://github.com/arraypress/swift-sqlite-reader).

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-apple-shortcuts.git", from: "0.2.0")
```

## Licence

MIT.
