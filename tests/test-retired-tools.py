#!/usr/bin/env python3
"""Retired-name contract: removed tools, flags and harnesses stay removed.

Each check is a FORBIDDEN row. It must hold on the real tree and go RED on a
mutant that reintroduces the retired text. `fleet-rev(?!iew)` keeps the live
`fleet-review` skill from matching, and `agent-skills` not preceded by
`addyosmani/` keeps the upstream attribution from matching.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests/lib"))
from contract import expect_red  # noqa: E402

RETIRED_TOOL = re.compile(r"fleet-rev(?!iew)|fleet-install")
RETIRED_CHECKOUT = re.compile(r"(?<!addyosmani/)agent-skills")
RETIRED_INSTALLER = re.compile(r"--prune-old|agent-skills-backup")
RETIRED_BIN = {"fleet-install", "fleet-rev"}


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def skill_and_doc_texts():
    docs = {str(p.relative_to(ROOT)): p.read_text(encoding="utf-8")
            for p in sorted((ROOT / "skills").rglob("*.md"))}
    docs["AGENTS.md"] = read("AGENTS.md")
    docs["README.md"] = read("README.md")
    return docs


def check_skills_name_no_retired_tool(docs):
    for name, text in docs.items():
        assert not RETIRED_TOOL.search(text), f"{name}: names a retired tool"
        assert not RETIRED_CHECKOUT.search(text), f"{name}: names the retired agent-skills checkout"


def check_installer_has_no_move_code(files):
    for name, text in files.items():
        assert not RETIRED_INSTALLER.search(text), f"{name}: keeps the retired agent-skills move"


def check_manifest_has_no_gemini(text):
    assert "gemini" not in json.loads(text)["harnesses"], "gemini harness is retired"


def check_bin_has_no_retired_tool(names):
    retired = sorted(set(names) & RETIRED_BIN)
    assert not retired, f"retired tool in bin/: {retired}"


def main():
    docs = skill_and_doc_texts()
    check_skills_name_no_retired_tool(docs)
    print("PASS skills-and-docs-name-no-retired-tool")
    expect_red("skill-names-fleet-rev", check_skills_name_no_retired_tool,
               {**docs, "skills/wake/SKILL.md": docs["skills/wake/SKILL.md"] + "\nRun `fleet-rev --json` first.\n"})
    expect_red("readme-names-fleet-install", check_skills_name_no_retired_tool,
               {**docs, "README.md": docs["README.md"] + "\nfleet-install mergewake v1.2.3\n"})
    expect_red("skill-names-agent-skills", check_skills_name_no_retired_tool,
               {**docs, "skills/wake/SKILL.md": docs["skills/wake/SKILL.md"] + "\nClone agent-skills first.\n"})
    check_skills_name_no_retired_tool({**docs, "skills/fleet-review/SKILL.md": docs["skills/fleet-review/SKILL.md"]
                                       + "\nSee https://github.com/addyosmani/agent-skills and fleet-review.\n"})
    print("RED skill and README retired-tool mutants; PASS upstream citation and fleet-review controls (expected)")

    installer = {name: read(name) for name in ("scripts/install-skills.py", "install.sh", "README.md")}
    check_installer_has_no_move_code(installer)
    print("PASS installer-and-readme-have-no-move-code")
    expect_red("installer-restores-prune-old", check_installer_has_no_move_code,
               {**installer, "scripts/install-skills.py": installer["scripts/install-skills.py"]
                + "\n    parser.add_argument('--prune-old', action='store_true')\n"})
    expect_red("readme-restores-prune-old", check_installer_has_no_move_code,
               {**installer, "README.md": installer["README.md"] + "\n./install.sh --prune-old\n"})
    print("RED installer and README prune-old mutants (expected)")

    manifest = read("install/sets.json")
    check_manifest_has_no_gemini(manifest)
    print("PASS manifest-has-no-gemini-harness")
    gemini = ('"gemini": {"set": "worker", "install_dir": ".gemini/skills", '
              '"scan_dirs": [".gemini/skills"], "evidence": "x"},\n    "kiro": {')
    expect_red("manifest-restores-gemini", check_manifest_has_no_gemini,
               manifest.replace('"kiro": {', gemini, 1))
    print("RED gemini harness mutant (expected)")

    names = [p.name for p in (ROOT / "bin").iterdir()]
    check_bin_has_no_retired_tool(names)
    print("PASS bin-has-no-retired-tool")
    expect_red("bin-restores-fleet-rev", check_bin_has_no_retired_tool, names + ["fleet-rev"])
    print("RED bin retired-tool mutant (expected)")


if __name__ == "__main__":
    main()
