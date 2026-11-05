"""Shared helpers for the skill contract tests (tests/test-*.sh).

Each contract test pins rule text in a skill document and proves every pin with
a mutant that must go RED by assertion. These helpers keep the section scoping
and the mutant mechanics identical across tests, so a pin means the same thing
everywhere.

Usage from a test's Python heredoc:

    sys.path.insert(0, str(root / "tests/lib"))
    from contract import flat, section, section_span, delete_row, expect_red
"""
import re

__all__ = ["flat", "heading_end", "section", "section_span", "delete_row", "expect_red"]


def flat(text: str) -> str:
    """Collapse every whitespace run to one space, so a pin survives rewrapping."""
    return re.sub(r"\s+", " ", text)


def heading_end(text: str, heading: str) -> int:
    """Offset just past the first line that starts with `heading`.

    The match is anchored at a line start, so a heading quoted inline (for
    example in a `§` pointer) or a deeper heading that contains the same words
    never counts as the section itself.
    """
    m = re.search(r"(?m)^" + re.escape(heading), text)
    assert m, f"missing heading: {heading.strip()}"
    return m.end()


def section_span(text: str, heading) -> tuple:
    """(start, end) of a section body: after its heading line, up to the next
    heading of the same or a higher level. A falsy heading spans the whole text."""
    if not heading:
        return 0, len(text)
    start = heading_end(text, heading)
    level = len(heading) - len(heading.lstrip("#"))
    m = re.compile(rf"(?m)^#{{1,{level}}} ").search(text, start)
    return start, (m.start() if m else len(text))


def section(text: str, heading) -> str:
    """Body of a ##/### section up to the next heading of same-or-higher level."""
    start, end = section_span(text, heading)
    return text[start:end]


def delete_row(text: str, heading, pattern: str, row: str = "") -> str:
    """Delete the text a pin matches inside its own section, whatever its wrapping.

    The pattern is matched on the flattened section; its words are then found
    in the raw section, so the mutant removes exactly the pinned sentence and
    not a copy of it in another section.
    """
    start, end = section_span(text, heading)
    m = re.search(pattern, flat(text[start:end]))
    assert m, f"fixture: row {row or pattern} not found in its section"
    words = m.group(0).split()
    raw = re.compile(r"\s+".join(re.escape(w) for w in words)).search(text, start, end)
    assert raw, f"fixture: row {row or pattern} not found unflattened in its section"
    return text[: raw.start()] + text[raw.end():]


def expect_red(label: str, check, *args, **kwargs) -> None:
    """Run `check` on a mutant; it must fail by AssertionError, nothing else."""
    try:
        check(*args, **kwargs)
    except AssertionError:
        return
    except Exception as exc:
        raise AssertionError(f"{label} errored instead of assertion RED: {exc}") from exc
    raise AssertionError(f"mutant {label} did not go RED")
