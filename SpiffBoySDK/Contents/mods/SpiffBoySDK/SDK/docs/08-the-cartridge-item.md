# 8. The cartridge item

The cartridge is also an item of the world: it has an item script, a name, an icon, a 3D model and a place in the loot.

## The item script

The item is defined in `media/scripts/<Ns>/<Id>.txt`. The one of Hello SpiffBoy:

```
module SpiffBoySDK
{
    item Cartridge_HelloSpiffBoy
    {
        DisplayCategory = Entertainment,
        ItemType = base:normal,
        Weight = 0.1,
        Icon = SpiffBoySDK_Cartridge_HelloSpiffBoy,
        MetalValue = 1.0,
        Tags = base:hasmetal;spiffboy:cartridge,
        WorldStaticModel = SpiffBoySDK.Cartridge_HelloSpiffBoy,
    }

    model Cartridge_HelloSpiffBoy
    {
        mesh = SpiffBoy/Cartridge,
        texture = SpiffBoySDK/SpiffBoySDKCartridge_HelloSpiffBoy,
        scale = 0.3,
    }
}
```

- `module SpiffBoySDK` and `item Cartridge_HelloSpiffBoy` make the full type `SpiffBoySDK.Cartridge_HelloSpiffBoy`, which the `item` field of the definition must match exactly.
- `Icon = SpiffBoySDK_Cartridge_HelloSpiffBoy` names the picture `media/textures/Item_SpiffBoySDK_Cartridge_HelloSpiffBoy.png`: the engine adds `Item_` in front and `.png` after.
- `WorldStaticModel` names the `model` block of the same file, shown when the cartridge lies on the floor. Its mesh, `SpiffBoy/Cartridge`, ships with SpiffBoy, so every cartridge has the same shape; its `texture` is `media/textures/SpiffBoySDK/SpiffBoySDKCartridge_HelloSpiffBoy.png`.
- `Tags` lists the tags of the item, separated by `;`. `spiffboy:cartridge` is the tag of SpiffBoy that marks a cartridge: every cartridge item must carry it, so the dismantling recipe of SpiffBoy takes it ([Dismantling](#dismantling)). `base:hasmetal` is a tag of Project Zomboid, as on the cartridges of SpiffBoy.
- `Weight`, `DisplayCategory` and `MetalValue` are the usual properties of a Project Zomboid item.

`new_cartridge.py` names your item `Cartridge_<Id>` in your module, and the file names below follow that name. The inventory name of the item comes from `ItemName.json` ([Texts and translations](06-texts-and-translations.md#item-names)).

## The label, the icon and the 3D model

`label.png` in the art folder ([Screen and art](03-screen-and-art.md#labelpng-the-picture-on-the-cartridge)) also gives the item its look. `new_cartridge.py` copies the model texture and the icon of Hello SpiffBoy under the names of your cartridge. When your label is ready, `tools/cartridge_label.py` puts it on the blank cartridge that comes with the tool and writes:

- the texture of the 3D model, `media/textures/<Ns>/<Ns>Cartridge_<Id>.png`, the name the `model` block gives;
- the 64x64 inventory icon, `media/textures/Item_<Module>_Cartridge_<Id>.png`, the name the `Icon` line gives.

```
python tools/cartridge_label.py ".../ui/MyMod/Games/SpaceRace/label.png" ".../textures/MyMod/MyModCartridge_SpaceRace.png" ".../textures/Item_MyMod_Cartridge_SpaceRace.png"
```

Run it again whenever the label changes. Any 64x64 picture with the icon file name also works as the icon.

## Loot

The `loot` field of the definition decides where the cartridge spawns in the world.

| Value | Effect |
|---|---|
| `{ weight = 0 }` | Never spawns. The examples of the SDK use it: they come from the developer menu only. `new_cartridge.py` gives your cartridge 2 instead. |
| `{ weight = n }` | Added with weight `n` to the loot lists where the console spawns: the dressers and wardrobes of children's rooms, toy and electronics crates, school lockers, comic stores, among others. |
| `{ weight = n, lists = { "CrateToys", "GigamartToys" } }` | Added with weight `n` to your own choice of `ProceduralDistributions` lists instead. |
| no `loot` field | Weight 2. |

A weight is relative to the other items of the list; the cartridges of SpiffBoy use 2. A weight that is not a number of zero or more, or `lists` that is not a table, is an error at registration.

A cartridge with a weight above 0 can also be found, more often as its weight is higher:

- inside a console spawned in the world, picked among every cartridge with a weight above 0 in proportion to the weights;
- on zombies dressed as students or as staff of Spiffo's, with a chance in proportion to its weight.

The sandbox options of SpiffBoy act on every cartridge with a weight above 0, yours included:

| Option | Effect |
|---|---|
| Cartridge loot | Multiplies the weight of every cartridge in the loot lists: none (0), rare (0.5), normal (1, the default) or frequent (2). |
| Found consoles hold a cartridge | The chance, 0 to 100 (50 by default), that a console found in the world holds a cartridge. |
| Zombies carry cartridges | Whether students and Spiffo's staff zombies carry cartridges. |

## Dismantling

SpiffBoy has a recipe that dismantles a cartridge into electronics scrap with a screwdriver. It takes any item with the tag `spiffboy:cartridge`, so your cartridge is dismantled as soon as its item carries the tag: your mod needs no recipe of its own. The sandbox option of SpiffBoy for dismantling applies to it like to the cartridges of SpiffBoy.

When a game starts, SpiffBoy checks the item of every registered cartridge and writes a line in the log for each one whose item lacks the tag:

```
SpiffBoy: [SB-REG-TAG] cartridge SpaceRace of the mod MyMod has the item MyMod.Cartridge_SpaceRace without the tag spiffboy:cartridge: the dismantling recipe does not take it. Fix: give the item the tag spiffboy:cartridge in its item script. See: SDK docs/08-the-cartridge-item.md, Dismantling.
```

The same check writes a line when no item script defines the `item` of a definition, which happens when the item name of the script and the `item` field differ. The [robot](09-testing.md#the-robot) makes both checks offline and marks the game `WARN`, and `tools/check_texts.py` fails when `ItemName.json` gives no name to the item.

A console dismantled with your cartridge inside gives the cartridge back with its save, as long as a loaded mod defines its item.

Next: [Testing](09-testing.md).
