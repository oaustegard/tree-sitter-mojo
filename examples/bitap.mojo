"""Core bitap (shift-or) algorithm for approximate string matching.

Uses bit-parallel operations on UInt64 bitmasks for patterns up to
64 characters -- twice the 32-bit limit of Fuse.js (JavaScript).

Based on the Baeza-Yates-Gonnet algorithm as implemented in Fuse.js
(https://github.com/krisk/Fuse).
"""

comptime MAX_BITS = 64


# ── Data types ──────────────────────────────────────────────────────


@fieldwise_init
struct MatchRange(Copyable, Movable):
    """A contiguous match span [start, end] (inclusive)."""

    var start: Int
    var end: Int


struct SearchResult(Movable):
    """Result of a bitap search."""

    var is_match: Bool
    var score: Float64
    var indices: List[MatchRange]

    def __init__(out self, is_match: Bool, score: Float64):
        self.is_match = is_match
        self.score = score
        self.indices = List[MatchRange]()

    def __init__(
        out self,
        is_match: Bool,
        score: Float64,
        var indices: List[MatchRange],
    ):
        self.is_match = is_match
        self.score = score
        self.indices = indices^

    def __init__(out self, *, deinit take: Self):
        self.is_match = take.is_match
        self.score = take.score
        self.indices = take.indices^


# ── String helpers ──────────────────────────────────────────────────


def string_to_codepoints(s: String) -> List[Int]:
    """Convert a string to a list of codepoint integer values."""
    var result = List[Int]()
    for cp in s.codepoints():
        result.append(Int(cp))
    return result^


def to_lower_codepoints(cps: List[Int]) -> List[Int]:
    """Return a new list with ASCII uppercase mapped to lowercase."""
    var result = List[Int]()
    for i in range(len(cps)):
        var cp = cps[i]
        if cp >= 65 and cp <= 90:  # A-Z
            result.append(cp + 32)
        else:
            result.append(cp)
    return result^


def codepoints_equal(a: List[Int], b: List[Int]) -> Bool:
    """Check if two codepoint arrays are equal."""
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def find_exact(text: List[Int], pattern: List[Int], start: Int) -> Int:
    """Find exact substring match in codepoint arrays. Returns index or -1."""
    var tlen = len(text)
    var plen = len(pattern)
    if plen == 0 or start < 0 or start + plen > tlen:
        return -1
    for i in range(start, tlen - plen + 1):
        var matched = True
        for j in range(plen):
            if text[i + j] != pattern[j]:
                matched = False
                break
        if matched:
            return i
    return -1


# ── Pattern alphabet ────────────────────────────────────────────────


def create_pattern_alphabet(pattern: List[Int]) raises -> Dict[Int, UInt64]:
    """Build bitmask lookup for pattern characters.

    Each codepoint maps to a UInt64 where bit i is set if the character
    appears at position (pattern_length - 1 - i) in the pattern.
    """
    var masks = Dict[Int, UInt64]()
    var plen = len(pattern)
    for i in range(plen):
        var cp = pattern[i]
        var bit = UInt64(1) << UInt64(plen - 1 - i)
        if cp in masks:
            masks[cp] = masks[cp] | bit
        else:
            masks[cp] = bit
    return masks^


# ── Scoring ─────────────────────────────────────────────────────────


def compute_score(
    pattern_len: Int,
    errors: Int,
    current_location: Int,
    expected_location: Int,
    distance: Int,
    ignore_location: Bool,
) -> Float64:
    """Compute match score.  Lower is better.  0.0 = exact at expected location."""
    if pattern_len == 0:
        return 1.0
    var accuracy = Float64(errors) / Float64(pattern_len)
    if ignore_location:
        return accuracy

    var proximity = current_location - expected_location
    if proximity < 0:
        proximity = -proximity

    if distance == 0:
        if proximity > 0:
            return 1.0
        return accuracy

    return accuracy + Float64(proximity) / Float64(distance)


# ── Match indices ───────────────────────────────────────────────────


def convert_mask_to_indices(
    matchmask: List[Int],
    min_match_char_length: Int,
) -> List[MatchRange]:
    """Convert match bitmask to list of contiguous match ranges."""
    var indices = List[MatchRange]()
    var start = -1
    var mask_len = len(matchmask)

    for i in range(mask_len):
        if matchmask[i] != 0 and start == -1:
            start = i
        elif matchmask[i] == 0 and start != -1:
            var end = i - 1
            if end - start + 1 >= min_match_char_length:
                indices.append(MatchRange(start, end))
            start = -1

    # Handle match running to end of string
    if start != -1 and mask_len - start >= min_match_char_length:
        indices.append(MatchRange(start, mask_len - 1))

    return indices^


# ── Core bitap search ───────────────────────────────────────────────


def bitap_search(
    text_cps: List[Int],
    pattern_cps: List[Int],
    alphabet: Dict[Int, UInt64],
    location: Int = 0,
    distance: Int = 100,
    threshold: Float64 = 0.6,
    find_all_matches: Bool = False,
    min_match_char_length: Int = 1,
    include_matches: Bool = False,
    ignore_location: Bool = False,
) raises -> SearchResult:
    """Perform fuzzy bitap search for pattern in text.

    Args:
        text_cps: Text as codepoint array.
        pattern_cps: Pattern as codepoint array (max 64 codepoints).
        alphabet: Precomputed pattern bitmasks from create_pattern_alphabet.
        location: Expected position of pattern in text (default 0).
        distance: How far from location a match can be (default 100).
        threshold: Score cutoff 0.0-1.0; lower = stricter (default 0.6).
        find_all_matches: Continue past first good match (default False).
        min_match_char_length: Min contiguous match length to report (default 1).
        include_matches: Compute match index ranges (default False).
        ignore_location: Ignore location/distance in scoring (default False).

    Returns:
        SearchResult with is_match, score, and optional match indices.
    """
    var pattern_len = len(pattern_cps)
    var text_len = len(text_cps)

    if pattern_len == 0 or pattern_len > MAX_BITS:
        return SearchResult(False, 1.0)

    # Clamp expected location
    var expected_location = location
    if expected_location < 0:
        expected_location = 0
    if expected_location > text_len:
        expected_location = text_len

    # Working threshold -- tightens as we find better matches
    var current_threshold = threshold
    var best_location = -1

    # Whether to build match-position masks
    var compute_matches = min_match_char_length > 1 or include_matches
    var matchmask = List[Int](length=text_len, fill=0)

    # ── Exact match acceleration ────────────────────────────────────
    # Find all exact occurrences to tighten the threshold before fuzzy phase.

    var search_start = 0
    var idx = find_exact(text_cps, pattern_cps, search_start)
    while idx >= 0:
        var score = compute_score(
            pattern_len, 0, idx, expected_location, distance, ignore_location
        )
        if score < current_threshold:
            current_threshold = score

        if compute_matches:
            for k in range(pattern_len):
                matchmask[idx + k] = 1

        search_start = idx + pattern_len
        idx = find_exact(text_cps, pattern_cps, search_start)

    var last_bit_arr = List[UInt64]()
    var final_score: Float64 = 1.0
    var bin_max = pattern_len + text_len
    var mask = UInt64(1) << UInt64(pattern_len - 1)

    # ── Fuzzy matching: iterate over increasing error counts ────────

    for i in range(pattern_len):
        # Binary-search for the furthest location from expected that
        # still scores within threshold at this error level.
        var bin_min = 0
        var bin_mid = bin_max

        while bin_min < bin_mid:
            var score = compute_score(
                pattern_len,
                i,
                expected_location + bin_mid,
                expected_location,
                distance,
                ignore_location,
            )
            if score <= current_threshold:
                bin_min = bin_mid
            else:
                bin_max = bin_mid
            bin_mid = (bin_max - bin_min) // 2 + bin_min

        bin_max = bin_mid

        var start = expected_location - bin_mid + 1
        if start < 1:
            start = 1

        var finish: Int
        if find_all_matches:
            finish = text_len
        else:
            finish = expected_location + bin_mid
            if finish > text_len:
                finish = text_len
            finish = finish + pattern_len

        # Bit array for this error level
        var bit_arr = List[UInt64](length=finish + 2, fill=UInt64(0))
        bit_arr[finish + 1] = (UInt64(1) << UInt64(i)) - UInt64(1)

        # Scan right-to-left
        var j = finish
        while j >= start:
            var current_location = j - 1

            # Look up character bitmask in alphabet
            var char_match = UInt64(0)
            if current_location >= 0 and current_location < text_len:
                var cp = text_cps[current_location]
                if cp in alphabet:
                    char_match = alphabet[cp]

            if compute_matches and current_location >= 0 and current_location < text_len:
                if char_match != UInt64(0):
                    matchmask[current_location] = 1

            # Exact-match bits
            bit_arr[j] = ((bit_arr[j + 1] << 1) | UInt64(1)) & char_match

            # Fuzzy: allow substitutions, insertions, deletions
            if i > 0:
                bit_arr[j] = bit_arr[j] | (
                    ((last_bit_arr[j + 1] | last_bit_arr[j]) << 1)
                    | UInt64(1)
                    | last_bit_arr[j + 1]
                )

            # Check for full-pattern match
            if (bit_arr[j] & mask) != UInt64(0):
                final_score = compute_score(
                    pattern_len,
                    i,
                    current_location,
                    expected_location,
                    distance,
                    ignore_location,
                )
                if final_score <= current_threshold:
                    current_threshold = final_score
                    best_location = current_location
                    if best_location <= expected_location:
                        break
                    var new_start = 2 * expected_location - best_location
                    if new_start > start:
                        start = new_start

            j -= 1

        # Check if more errors would help
        var next_score = compute_score(
            pattern_len,
            i + 1,
            expected_location,
            expected_location,
            distance,
            ignore_location,
        )
        if next_score > current_threshold:
            break

        last_bit_arr = bit_arr^  # Transfer ownership for next iteration

    # ── Build result ────────────────────────────────────────────────

    var is_match = best_location >= 0
    var result_score = final_score
    if result_score < 0.001:
        result_score = 0.001
    if not is_match:
        result_score = 1.0

    var result_indices = List[MatchRange]()
    if compute_matches and is_match:
        result_indices = convert_mask_to_indices(matchmask, min_match_char_length)
        if len(result_indices) == 0:
            is_match = False
            result_score = 1.0

    return SearchResult(is_match, result_score, result_indices^)


# ── BitapSearcher ───────────────────────────────────────────────────


struct BitapSearcher(Movable):
    """High-level fuzzy searcher wrapping the bitap algorithm.

    Handles case normalization, codepoint conversion, and alphabet
    precomputation.  Patterns up to 64 characters are supported directly;
    for longer patterns, returns no match (chunking is a future enhancement).
    """

    var pattern_cps: List[Int]
    var alphabet: Dict[Int, UInt64]
    var case_sensitive: Bool
    var location: Int
    var threshold: Float64
    var distance: Int
    var include_matches: Bool
    var find_all_matches: Bool
    var min_match_char_length: Int
    var ignore_location: Bool

    def __init__(
        out self,
        pattern: String,
        case_sensitive: Bool = False,
        location: Int = 0,
        threshold: Float64 = 0.6,
        distance: Int = 100,
        include_matches: Bool = False,
        find_all_matches: Bool = False,
        min_match_char_length: Int = 1,
        ignore_location: Bool = False,
    ) raises:
        self.case_sensitive = case_sensitive
        self.location = location
        self.threshold = threshold
        self.distance = distance
        self.include_matches = include_matches
        self.find_all_matches = find_all_matches
        self.min_match_char_length = min_match_char_length
        self.ignore_location = ignore_location

        var cps = string_to_codepoints(pattern)
        if not case_sensitive:
            cps = to_lower_codepoints(cps)
        self.pattern_cps = cps^
        self.alphabet = create_pattern_alphabet(self.pattern_cps)

    def __init__(out self, *, deinit take: Self):
        self.pattern_cps = take.pattern_cps^
        self.alphabet = take.alphabet^
        self.case_sensitive = take.case_sensitive
        self.location = take.location
        self.threshold = take.threshold
        self.distance = take.distance
        self.include_matches = take.include_matches
        self.find_all_matches = take.find_all_matches
        self.min_match_char_length = take.min_match_char_length
        self.ignore_location = take.ignore_location

    def search_in(self, text: String) raises -> SearchResult:
        """Search for the pattern in the given text.

        Normalizes case if case_sensitive is False, then runs bitap search.
        """
        var text_cps = string_to_codepoints(text)
        if not self.case_sensitive:
            text_cps = to_lower_codepoints(text_cps)

        # Exact-match fast path
        if codepoints_equal(self.pattern_cps, text_cps):
            var indices = List[MatchRange]()
            if self.include_matches:
                indices.append(MatchRange(0, len(text_cps) - 1))
            return SearchResult(True, 0.0, indices^)

        return bitap_search(
            text_cps,
            self.pattern_cps,
            self.alphabet,
            self.location,
            self.distance,
            self.threshold,
            self.find_all_matches,
            self.min_match_char_length,
            self.include_matches,
            self.ignore_location,
        )
