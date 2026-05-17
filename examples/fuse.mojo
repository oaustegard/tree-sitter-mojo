"""Main Fuse search API -- fuzzy search over string collections."""

from .bitap import (
    SearchResult,
    MatchRange,
    BitapSearcher,
    string_to_codepoints,
    to_lower_codepoints,
)


struct FuseResult(Copyable, Movable):
    """A single search result with the matched item, its index, and score."""

    var item: String
    var index: Int
    var score: Float64
    var matches: List[MatchRange]

    def __init__(
        out self,
        var item: String,
        index: Int,
        score: Float64,
        var matches: List[MatchRange],
    ):
        self.item = item^
        self.index = index
        self.score = score
        self.matches = matches^

    def __init__(out self, *, copy: Self):
        self.item = copy.item
        self.index = copy.index
        self.score = copy.score
        self.matches = copy.matches.copy()

    def __init__(out self, *, deinit take: Self):
        self.item = take.item^
        self.index = take.index
        self.score = take.score
        self.matches = take.matches^


struct Fuse(Movable):
    """Fuzzy search over a string collection using the bitap algorithm.

    Example::

        var books: List[String] = [
            "The Great Gatsby",
            "Brave New World",
            "1984",
        ]
        var fuse = Fuse(books^, threshold=0.4, ignore_location=True)
        var results = fuse.search("graet gatby")
        for i in range(len(results)):
            print(results[i].item, results[i].score)
    """

    var collection: List[String]
    var threshold: Float64
    var distance: Int
    var location: Int
    var min_match_char_length: Int
    var include_matches: Bool
    var should_sort: Bool
    var find_all_matches: Bool
    var ignore_location: Bool
    var case_sensitive: Bool

    def __init__(
        out self,
        var collection: List[String],
        threshold: Float64 = 0.6,
        distance: Int = 100,
        location: Int = 0,
        min_match_char_length: Int = 1,
        include_matches: Bool = False,
        should_sort: Bool = True,
        find_all_matches: Bool = False,
        ignore_location: Bool = False,
        case_sensitive: Bool = False,
    ):
        self.collection = collection^
        self.threshold = threshold
        self.distance = distance
        self.location = location
        self.min_match_char_length = min_match_char_length
        self.include_matches = include_matches
        self.should_sort = should_sort
        self.find_all_matches = find_all_matches
        self.ignore_location = ignore_location
        self.case_sensitive = case_sensitive

    def __init__(out self, *, deinit take: Self):
        self.collection = take.collection^
        self.threshold = take.threshold
        self.distance = take.distance
        self.location = take.location
        self.min_match_char_length = take.min_match_char_length
        self.include_matches = take.include_matches
        self.should_sort = take.should_sort
        self.find_all_matches = take.find_all_matches
        self.ignore_location = take.ignore_location
        self.case_sensitive = take.case_sensitive

    def search(self, query: String) raises -> List[FuseResult]:
        """Search the collection for items matching the query.

        Returns a list of FuseResult sorted by score (best first).
        """
        if len(query) == 0:
            return List[FuseResult]()

        var searcher = BitapSearcher(
            query,
            case_sensitive=self.case_sensitive,
            location=self.location,
            threshold=self.threshold,
            distance=self.distance,
            include_matches=self.include_matches,
            find_all_matches=self.find_all_matches,
            min_match_char_length=self.min_match_char_length,
            ignore_location=self.ignore_location,
        )

        var results = List[FuseResult]()

        for idx in range(len(self.collection)):
            var result = searcher.search_in(self.collection[idx])
            if result.is_match:
                results.append(
                    FuseResult(
                        item=String(self.collection[idx]),
                        index=idx,
                        score=result.score,
                        matches=result.indices.copy(),
                    )
                )

        # Sort by score (selection sort -- result sets are typically small)
        if self.should_sort and len(results) > 1:
            for i in range(len(results) - 1):
                var min_idx = i
                for j in range(i + 1, len(results)):
                    if results[j].score < results[min_idx].score:
                        min_idx = j
                if min_idx != i:
                    results.swap_elements(i, min_idx)

        return results^
