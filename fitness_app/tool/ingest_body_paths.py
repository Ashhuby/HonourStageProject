"""Convert body-muscles' TypeScript path data into a Dart source file.

Run once. Output is checked in; this script is not part of the build.
Source: https://github.com/vulovix/body-muscles (Apache-2.0, (c) 2024 Ivan Vulovic)
"""
import io, re, sys, os

# The vendored Apache-2.0 sources, kept in-tree so this conversion is
# reproducible and the upstream licence travels with the data it covers.
SRC = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'third_party', 'body-muscles',
)

ENTRY = re.compile(
    r'\{\s*id:\s*"(?P<id>[^"]+)"\s*,\s*'
    r'name:\s*"(?P<name>[^"]+)"\s*,\s*'
    # A `// note` line may sit between any two fields.
    r'view:\s*[^,]+,\s*(?://[^\n]*\n\s*)*'
    r'path:\s*"(?P<path>(?:[^"\\]|\\.)*)"\s*,?\s*\}',
    re.S,
)


def parse(fname):
    text = io.open(os.path.join(SRC, fname), encoding='utf-8').read()
    out = []
    for m in ENTRY.finditer(text):
        out.append((m.group('id'), m.group('name'), m.group('path')))
    declared = re.findall(r'id:\s*"([^"]+)"', text)
    missing = set(declared) - {o[0] for o in out}
    assert not missing, '%s: unparsed entries %s' % (fname, sorted(missing))
    return out


# id prefix -> our Muscle enum name. Matched longest-prefix-first.
# Left/right pairs collapse into one muscle.
MUSCLE_PREFIXES = [
    ('chest-upper', 'chest'), ('chest-lower', 'chest'),
    ('shoulder-front', 'frontDelts'),
    ('shoulder-side', 'sideDelts'),
    ('deltoid-rear', 'rearDelts'),
    ('biceps', 'biceps'),
    ('triceps-long', 'triceps'), ('triceps-lateral', 'triceps'),
    ('forearm-flexors', 'forearms'), ('forearm-extensors', 'forearms'),
    ('forearm', 'forearms'),
    ('abs-upper', 'abs'), ('abs-lower', 'abs'),
    ('obliques', 'obliques'),
    ('lats-upper', 'lats'), ('lats-mid', 'lats'), ('lats-lower', 'lats'),
    ('traps-upper', 'traps'), ('traps-mid', 'traps'), ('traps-lower', 'traps'),
    ('lower-back-erectors', 'lowerBack'), ('lower-back-ql', 'lowerBack'),
    ('spine', 'lowerBack'),
    ('quads', 'quads'),
    ('hamstrings-medial', 'hamstrings'), ('hamstrings-lateral', 'hamstrings'),
    ('gluteus-maximus', 'glutes'), ('gluteus-medius', 'glutes'),
    ('calves-gastroc', 'calves'), ('calves-soleus', 'calves'),
]
MUSCLE_PREFIXES.sort(key=lambda kv: -len(kv[0]))


def muscle_for(pid):
    for prefix, muscle in MUSCLE_PREFIXES:
        if pid == prefix or pid.startswith(prefix + '-'):
            return muscle
    return None


def build(fname, view):
    muscles = {}   # muscle -> [d, ...]
    inert = []     # everything else: head, hands, feet, knees, ...
    unmapped = []
    for pid, name, d in parse(fname):
        muscle = muscle_for(pid)
        if muscle is None:
            inert.append((pid, d))
            unmapped.append(pid)
        else:
            muscles.setdefault(muscle, []).append((pid, d))
    return muscles, inert, unmapped


def dart_string(s):
    return "'" + s.replace('\\', '\\\\').replace("'", r"\'") + "'"


def emit(front, back, front_inert, back_inert):
    L = []
    L.append("// GENERATED FILE — do not edit by hand.")
    L.append("//")
    L.append("// Muscle outlines converted from the `body-muscles` project:")
    L.append("//   https://github.com/vulovix/body-muscles")
    L.append("//   Copyright 2024 Ivan Vulovic, licensed under Apache-2.0.")
    L.append("//   See third_party/body-muscles/LICENSE for the full licence")
    L.append("//   and NOTICE for the attribution it requires.")
    L.append("//")
    L.append("// Regenerate with tool/ingest_body_paths.py. The `d` strings are")
    L.append("// verbatim; only the grouping into our muscle vocabulary is ours.")
    L.append("")
    L.append("/// SVG path data per muscle, front view. Keys are `Muscle` names.")
    L.append("const Map<String, List<String>> kFrontMusclePaths = {")
    for muscle in sorted(front):
        L.append("  '%s': [" % muscle)
        for pid, d in front[muscle]:
            L.append("    // %s" % pid)
            L.append("    %s," % dart_string(d))
        L.append("  ],")
    L.append("};")
    L.append("")
    L.append("/// SVG path data per muscle, back view. Keys are `Muscle` names.")
    L.append("const Map<String, List<String>> kBackMusclePaths = {")
    for muscle in sorted(back):
        L.append("  '%s': [" % muscle)
        for pid, d in back[muscle]:
            L.append("    // %s" % pid)
            L.append("    %s," % dart_string(d))
        L.append("  ],")
    L.append("};")
    L.append("")
    L.append("/// Head, hands, feet, joints and the muscles outside our")
    L.append("/// vocabulary. Drawn flat and never hit-tested — this is what")
    L.append("/// makes the figure read as a body.")
    L.append("const List<String> kFrontInertPaths = [")
    for pid, d in front_inert:
        L.append("  // %s" % pid)
        L.append("  %s," % dart_string(d))
    L.append("];")
    L.append("")
    L.append("const List<String> kBackInertPaths = [")
    for pid, d in back_inert:
        L.append("  // %s" % pid)
        L.append("  %s," % dart_string(d))
    L.append("];")
    L.append("")
    return '\n'.join(L)


front, front_inert, front_un = build('muscles.front.ts', 'front')
back, back_inert, back_un = build('muscles.back.ts', 'back')

print('front muscles:', sorted(front))
print('front inert  :', front_un)
print('back muscles :', sorted(back))
print('back inert   :', back_un)

out = sys.argv[1]
io.open(out, 'w', encoding='utf-8', newline='\n').write(emit(front, back, front_inert, back_inert))
print('wrote', out)
