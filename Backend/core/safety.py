"""Wording guard for user-facing wellness text (plan Section 6.3).

Every recommendation / plan string the backend produces is checked against
this list so the app can never accidentally sound like a medical diagnosis.
The one place these words are allowed is the fixed disclaimer, which lives
in the Flutter app and explicitly says the tool does NOT diagnose them.
"""
import re

# Stems are matched at the start of a word, so "diagnos" catches diagnose,
# diagnosis, diagnosed, diagnostic. Extend this list as needed.
BANNED_STEMS = (
    "depress",
    "anxi",
    "ptsd",
    "post-traumatic",
    "posttraumatic",
    "diagnos",
    "disorder",
    "mental illness",
    "psychiatr",
    "clinical",
    "suicid",
    "self-harm",
)

_PATTERN = re.compile(
    r"\b(" + "|".join(re.escape(s) for s in BANNED_STEMS) + r")",
    re.IGNORECASE,
)


def find_banned_terms(text: str) -> list[str]:
    """Return every banned stem found in `text` (empty list = clean)."""
    return [m.group(1).lower() for m in _PATTERN.finditer(text)]


def is_clean(text: str) -> bool:
    return not find_banned_terms(text)
