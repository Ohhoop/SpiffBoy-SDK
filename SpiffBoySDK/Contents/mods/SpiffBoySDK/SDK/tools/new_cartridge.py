"""Creates a new cartridge in a mod from the Hello SpiffBoy example of the SpiffBoy SDK, with every name of the example renamed.

It copies, from the media folder of the SDK to the media folder of the mod:
    lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Definition.lua and Translate/*.json   ->  lua/shared/<Namespace>/Games/<Id>/
    lua/client/SpiffBoySDK/Games/HelloSpiffBoy/*.lua (Game.lua, Music.lua)           ->  lua/client/<Namespace>/Games/<Id>/
    ui/SpiffBoySDK/Games/HelloSpiffBoy/*.png (spiffo.png, label.png)                 ->  ui/<Namespace>/Games/<Id>/
    scripts/SpiffBoySDK/HelloSpiffBoy.txt (the item and its 3D model)                ->  scripts/<Namespace>/<Id>.txt
    textures/SpiffBoySDK/SpiffBoySDKCartridge_HelloSpiffBoy.png (model texture)      ->  textures/<Namespace>/<Namespace>Cartridge_<Id>.png
    textures/Item_SpiffBoySDK_Cartridge_HelloSpiffBoy.png (inventory icon)           ->  textures/Item_<Module>_Cartridge_<Id>.png
and writes lua/shared/<Namespace>/Core.lua, which defines the global table <Namespace> and <Namespace>.MOD_ID, when the mod
has none; an existing one must define <Namespace>.MOD_ID.

In the text of the copied files, it replaces, in this order:
    "SpiffBoySDKHelloGame"                  the game class      ->  "<Namespace><Id>Game"
    "SpiffBoySDK.Cartridge_HelloSpiffBoy"   the item            ->  "<Module>.Cartridge_<Id>"
    "SpiffBoySDK_Cartridge_HelloSpiffBoy"   the item icon       ->  "<Module>_Cartridge_<Id>"
    "module SpiffBoySDK"                    the script module   ->  "module <Module>"
    "Hello SpiffBoy"                        the title           ->  "<Title>"
    "HELLO SPIFFBOY"                        the title on screen ->  "<TITLE>"
    "HelloSpiffBoy"                         the id              ->  "<Id>"
    "SpiffBoySDK"                           the namespace       ->  "<Namespace>"
It checks the example first (its definition must register these names) and writes nothing when a file to create already
exists or when a name of the example is left in the result.

Usage:
    python new_cartridge.py --sdk <SDK media folder> --mod <mod media folder> --namespace <Ns> --module <Module>
                            --id <Id> --title "<Title>" --mod-id <mod id>

Examples:
    python new_cartridge.py --sdk ".../SpiffBoySDK/42/media" --mod "C:/Users/me/Zomboid/Workshop/MyMod/Contents/mods/MyMod/42/media"
        --namespace MyMod --module MyMod --id SpaceRace --title "Space Race" --mod-id MyMod
"""

import argparse
import re
import sys
from pathlib import Path

EXAMPLE_NAMESPACE = "SpiffBoySDK"
EXAMPLE_MODULE = "SpiffBoySDK"
EXAMPLE_ID = "HelloSpiffBoy"
EXAMPLE_TITLE = "Hello SpiffBoy"
EXAMPLE_GAME = "SpiffBoySDKHelloGame"
TEXT_SUFFIXES = {".lua", ".json", ".txt"}
NAME = re.compile(r"^[A-Za-z][A-Za-z0-9]*$")
MOD_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.\- ]*$")
TITLE = re.compile(r"^[^\"\\\r\n\t]+$")
CORE = '''-- {namespace} keeps everything it shares between its files in one global table, named after the mod.
{namespace} = {namespace} or {{}}

-- The id of this mod, as written in its mod.info. A cartridge definition gives it in its `mod` field.
{namespace}.MOD_ID = "{mod_id}"
'''


class ScaffoldError(Exception):
    """Reports a cartridge that cannot be created."""


def renames(args):
    """Returns the ordered pairs of example text and new text applied to every copied text file."""
    return [
        (EXAMPLE_GAME, f"{args.namespace}{args.id}Game"),
        (f"{EXAMPLE_MODULE}.Cartridge_{EXAMPLE_ID}", f"{args.module}.Cartridge_{args.id}"),
        (f"{EXAMPLE_MODULE}_Cartridge_{EXAMPLE_ID}", f"{args.module}_Cartridge_{args.id}"),
        (f"module {EXAMPLE_MODULE}", f"module {args.module}"),
        (EXAMPLE_TITLE, args.title),
        (EXAMPLE_TITLE.upper(), args.title.upper()),
        (EXAMPLE_ID, args.id),
        (EXAMPLE_NAMESPACE, args.namespace),
    ]


def copies(sdk, mod, args):
    """Returns the pairs of example file and new file to copy, one per file of the example."""
    pairs = []
    for side, folder in (("lua/shared", "Games"), ("lua/client", "Games"), ("ui", "Games")):
        source = sdk / side / EXAMPLE_NAMESPACE / folder / EXAMPLE_ID
        if not source.is_dir():
            raise ScaffoldError(f"no example folder {source}: --sdk must be the media folder of the SpiffBoy SDK")
        target = mod / side / args.namespace / folder / args.id
        pairs += [(path, target / path.relative_to(source)) for path in sorted(source.rglob("*")) if path.is_file()]
    script = sdk / "scripts" / EXAMPLE_NAMESPACE / f"{EXAMPLE_ID}.txt"
    if not script.is_file():
        raise ScaffoldError(f"no example item script {script}")
    pairs.append((script, mod / "scripts" / args.namespace / f"{args.id}.txt"))
    textures = sdk / "textures"
    pictures = [
        (textures / EXAMPLE_NAMESPACE / f"{EXAMPLE_NAMESPACE}Cartridge_{EXAMPLE_ID}.png", mod / "textures" / args.namespace / f"{args.namespace}Cartridge_{args.id}.png"),
        (textures / f"Item_{EXAMPLE_MODULE}_Cartridge_{EXAMPLE_ID}.png", mod / "textures" / f"Item_{args.module}_Cartridge_{args.id}.png"),
    ]
    for source, target in pictures:
        if not source.is_file():
            raise ScaffoldError(f"no example picture {source}")
        pairs.append((source, target))
    return pairs


def check_example(sdk):
    """Checks that the definition of the example registers the id, item, title and game class the renames expect."""
    definition = (sdk / "lua" / "shared" / EXAMPLE_NAMESPACE / "Games" / EXAMPLE_ID / "Definition.lua").read_text(encoding="utf-8")
    expected = {"id": EXAMPLE_ID, "item": f"{EXAMPLE_MODULE}.Cartridge_{EXAMPLE_ID}", "title": EXAMPLE_TITLE, "game": EXAMPLE_GAME}
    for field, value in expected.items():
        if not re.search(rf'^\s*{field}\s*=\s*"{re.escape(value)}"\s*,', definition, re.M):
            raise ScaffoldError(f"the example definition no longer registers {field} = \"{value}\"; update the renames of this tool")
    if not re.search(rf"^\s*mod\s*=\s*{EXAMPLE_NAMESPACE}\.MOD_ID\s*,", definition, re.M):
        raise ScaffoldError(f"the example definition no longer registers mod = {EXAMPLE_NAMESPACE}.MOD_ID; update this tool")


def leftovers(path, text, args):
    """Returns the lines of a renamed text still holding a name of the example that the new names do not explain."""
    found = []
    names = [EXAMPLE_GAME, EXAMPLE_ID, EXAMPLE_TITLE, EXAMPLE_NAMESPACE]
    own = [args.namespace, args.module, args.id, args.title]
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line
        for name in sorted(own, key=len, reverse=True):
            stripped = stripped.replace(name, "")
        if any(name in stripped for name in names):
            found.append(f"{path}:{number}: {line.strip()}")
    return found


def validate(args):
    """Checks the names given on the command line."""
    for value, label in ((args.namespace, "--namespace"), (args.module, "--module"), (args.id, "--id")):
        if not NAME.match(value):
            raise ScaffoldError(f"{label} must be letters and digits starting with a letter, not {value}")
    if not MOD_ID.match(args.mod_id):
        raise ScaffoldError(f"--mod-id must be the id of the mod.info of the mod, letters, digits, spaces, dots, dashes and underscores, not {args.mod_id}")
    if not TITLE.match(args.title):
        raise ScaffoldError("--title must be one line without quotes, backslashes or tabs")
    if not args.mod.is_dir():
        raise ScaffoldError(f"no folder {args.mod}: --mod must be the media folder of the mod")


def plan(args):
    """Returns the files to write as pairs of path and content, bytes for pictures and text otherwise, after every check passed."""
    validate(args)
    check_example(args.sdk)
    table = renames(args)
    writes, problems = [], []
    for source, target in copies(args.sdk, args.mod, args):
        if target.exists():
            problems.append(f"{target} already exists")
            continue
        if source.suffix not in TEXT_SUFFIXES:
            writes.append((target, source.read_bytes()))
            continue
        text = source.read_text(encoding="utf-8")
        for old, new in table:
            text = text.replace(old, new)
        problems += leftovers(target, text, args)
        writes.append((target, text))
    core = args.mod / "lua" / "shared" / args.namespace / "Core.lua"
    if core.exists():
        if f"{args.namespace}.MOD_ID" not in core.read_text(encoding="utf-8"):
            problems.append(f"{core} exists and does not define {args.namespace}.MOD_ID, which the new definition reads")
    else:
        writes.append((core, CORE.format(namespace=args.namespace, mod_id=args.mod_id)))
    if problems:
        raise ScaffoldError("nothing written:\n    " + "\n    ".join(problems))
    return writes


def main():
    """Plans the new cartridge, writes its files when every check passed and lists them, or prints the problems found."""
    parser = argparse.ArgumentParser(description="Creates a new cartridge in a mod from the Hello SpiffBoy example of the SpiffBoy SDK.")
    parser.add_argument("--sdk", required=True, type=Path, help="media folder of the SpiffBoy SDK mod")
    parser.add_argument("--mod", required=True, type=Path, help="media folder of the mod receiving the cartridge")
    parser.add_argument("--namespace", required=True, help="folder name of the mod under lua, ui and scripts, and its global table")
    parser.add_argument("--module", required=True, help="script module of the cartridge item")
    parser.add_argument("--id", required=True, help="id of the new game")
    parser.add_argument("--title", required=True, help="title of the new game")
    parser.add_argument("--mod-id", required=True, help="id of the mod in its mod.info")
    args = parser.parse_args()
    try:
        writes = plan(args)
    except (ScaffoldError, OSError) as error:
        print(f"new_cartridge: {error}", file=sys.stderr)
        return 1
    for target, content in writes:
        target.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            target.write_bytes(content)
        else:
            target.write_text(content, encoding="utf-8", newline="\n")
        print(f"written {target.relative_to(args.mod).as_posix()}")
    print(f"cartridge {args.id} created: item {args.module}.Cartridge_{args.id}, game class {args.namespace}{args.id}Game")
    return 0


if __name__ == "__main__":
    sys.exit(main())
