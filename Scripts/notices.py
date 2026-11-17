#!/usr/bin/env python3
"""Writes the licenses of everything third-party inside Graphitree.

THIRD_PARTY_NOTICES.md, for the repo, and App/Resources/ThirdPartyNotices.txt, which the app shows
in Graphitree › About Graphitree. Both list the Swift packages, the graph pane's and the Playbook
lab's npm packages that end up in their bundles, and the components copied into the lab, each with
its license text.

Run it after changing a dependency. `--check` only says whether both files are current, and
Scripts/package.sh runs it so a release can't ship stale notices.

Needs the Swift packages checked out (any Release build does that) and `npm install` in Web/ and
playground/.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MARKDOWN = ROOT / "THIRD_PARTY_NOTICES.md"
TEXT = ROOT / "App/Resources/ThirdPartyNotices.txt"
COPIED = ROOT / "Scripts/notices"

SWIFT = [
    ("GRDB.swift", "https://github.com/groue/GRDB.swift", "GRDB.swift"),
    ("Sparkle", "https://sparkle-project.org", "Sparkle"),
]
# Each npm project's packages that can't end up in its bundle: build tools and type definitions.
NPM = [
    ("Graph pane", "Web", set()),
    ("Playbook lab", "playground", {"@tailwindcss/vite", "shadcn"}),
]
# Code copied into the Playbook lab, with where it came from and its license file in Scripts/notices.
COPIED_COMPONENTS = [
    ("shadcn/ui", "https://ui.shadcn.com", "shadcn-ui.txt"),
    ("Magic UI", "https://magicui.design", "magicui.txt"),
    ("Animate UI", "https://animate-ui.com", "animate-ui.txt"),
    ("Vercel AI Elements", "https://ai-sdk.dev/elements", "ai-elements.txt"),
    ("blocks.so", "https://blocks.so", "blocks.txt"),
    ("Beautiful UI", "https://beautifului.dev", "beautiful-ui.txt"),
    ("ShitUI (formerly RareUI)", "https://shitui.in", "shitui.txt"),
    ("Aceternity UI", "https://ui.aceternity.com", "aceternity-ui.txt"),
]
LICENSE_NAMES = ("LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "LICENCE.md", "license", "license.md", "License.md", "LICENSE-MIT")


def fail(message):
    sys.exit(f"notices: {message}")


def swift_packages():
    for checkouts in (ROOT / "build.noindex/package/SourcePackages/checkouts", ROOT / "build.noindex/SourcePackages/checkouts"):
        if checkouts.is_dir():
            break
    else:
        fail("the Swift packages aren't checked out. Run Scripts/package.sh or Scripts/test.sh first.")
    for name, url, folder in SWIFT:
        path = checkouts / folder / "LICENSE"
        if not path.is_file():
            fail(f"{path} is missing.")
        yield name, None, url, path.read_text(encoding="utf-8")


def bundled(folder, skip):
    """The packages reachable from a project's runtime dependencies, from its package-lock.json."""
    root = ROOT / folder
    lock = json.loads((root / "package-lock.json").read_text())["packages"]
    if not (root / "node_modules").is_dir():
        fail(f"{folder}/node_modules is missing. Run npm install in {folder}.")

    def resolve(at, name):
        base = at
        while True:
            key = f"{base}/node_modules/{name}" if base else f"node_modules/{name}"
            if key in lock:
                return key
            if not base:
                return None
            cut = base.rfind("/node_modules/")
            base = base[:cut] if cut >= 0 else ""

    roots = json.loads((root / "package.json").read_text()).get("dependencies", {})
    seen, todo = set(), [resolve("", name) for name in roots if name not in skip]
    while todo:
        key = todo.pop()
        if not key or key in seen:
            continue
        seen.add(key)
        info = lock[key]
        for name in list(info.get("dependencies", {})) + list(info.get("peerDependencies", {})):
            found = resolve(key, name)
            if found and not lock[found].get("dev"):
                todo.append(found)

    packages = []
    for key in seen:
        name = key.split("node_modules/")[-1]
        # Type definitions are only for the compiler, so nothing of theirs is in a bundle.
        if name.startswith("@types/") or name == "csstype":
            continue
        info = lock[key]
        spdx = info.get("license") or json.loads((root / key / "package.json").read_text()).get("license", "unknown")
        text = next(((root / key / candidate).read_text(encoding="utf-8", errors="replace")
                     for candidate in LICENSE_NAMES if (root / key / candidate).is_file()), None)
        if text is None:
            text = f"License: {spdx}. The package has no license file of its own."
        packages.append((name, info.get("version"), f"https://www.npmjs.com/package/{name}", text))
    # By name, then version, since a package can be installed twice at different versions.
    return sorted(packages, key=lambda item: (item[0].lower(), item[0], item[1] or ""))


def copied_components():
    for name, url, filename in COPIED_COMPONENTS:
        yield name, None, url, (COPIED / filename).read_text(encoding="utf-8")


def sections():
    yield "Swift packages", list(swift_packages())
    for title, folder, skip in NPM:
        yield f"{title} ({folder}/), npm packages in its bundle", bundled(folder, skip)
    yield "Components copied into the Playbook lab", list(copied_components())
    yield "Apache License 2.0, in full, for the parts above under it", [
        ("Apache License, Version 2.0", None, "https://www.apache.org/licenses/LICENSE-2.0", (COPIED / "apache-2.0.txt").read_text(encoding="utf-8"))
    ]


INTRO = (
    "Graphitree includes the third-party software below. Each part keeps its own license, reproduced here. "
    "Graphitree's own code is under the MIT License in LICENSE.\n\n"
    "graphify and uv aren't included: Graphitree runs them, and they're installed separately. "
    "See Credits in the README for them, and please support their work."
)


def render():
    data = list(sections())
    md = ["# Third-party notices", "", INTRO, ""]
    txt = ["THIRD-PARTY NOTICES", "", INTRO, ""]
    for title, items in data:
        md += [f"## {title}", ""]
        txt += ["=" * 72, title.upper(), "=" * 72, ""]
        for name, version, url, text in items:
            label = f"{name} {version}" if version else name
            body = text.strip("\n")
            md += [f"### {label}", "", url, "", "```text", body, "```", ""]
            txt += [f"{label} ({url})", "", body, "", "-" * 72, ""]
    return "\n".join(md).rstrip("\n") + "\n", "\n".join(txt).rstrip("\n") + "\n"


def main():
    markdown, text = render()
    if "--check" in sys.argv:
        stale = [path.relative_to(ROOT).as_posix() for path, wanted in ((MARKDOWN, markdown), (TEXT, text))
                 if not path.is_file() or path.read_text(encoding="utf-8") != wanted]
        if stale:
            fail(f"{' and '.join(stale)} are out of date. Run Scripts/notices.py, then build again.")
        print("Third-party notices are current.")
        return
    MARKDOWN.write_text(markdown, encoding="utf-8")
    TEXT.write_text(text, encoding="utf-8")
    count = markdown.count("\n### ")
    print(f"Wrote {MARKDOWN.relative_to(ROOT)} and {TEXT.relative_to(ROOT)}: {count} entries.")


if __name__ == "__main__":
    main()
