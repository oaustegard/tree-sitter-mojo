"""FuseMojo -- Lightweight fuzzy search in Mojo.

A port of the Fuse.js bitap algorithm to Mojo, achieving native
performance with Python-level ergonomics.  Patterns up to 64
characters are supported via UInt64 bitmasks (vs 32 in Fuse.js).
"""

from .bitap import (
    SearchResult,
    MatchRange,
    BitapSearcher,
    bitap_search,
    create_pattern_alphabet,
    string_to_codepoints,
    to_lower_codepoints,
)
from .fuse import Fuse, FuseResult
