"""Basic FuseMojo example -- fuzzy search over book titles."""

from fusemojo import Fuse


def main() raises:
    var books: List[String] = [
        "The Great Gatsby",
        "The Grapes of Wrath",
        "To Kill a Mockingbird",
        "1984",
        "Brave New World",
        "The Catcher in the Rye",
        "Lord of the Flies",
        "Animal Farm",
        "Of Mice and Men",
        "The Old Man and the Sea",
    ]

    var fuse = Fuse(
        books^,
        threshold=0.4,
        ignore_location=True,
    )

    # Exact-ish match
    print("Search: 'great gatsby'")
    var results = fuse.search("great gatsby")
    for i in range(len(results)):
        print("  ", results[i].item, "(score:", results[i].score, ")")

    # Typo
    print("\nSearch: 'mockingbrd' (typo)")
    results = fuse.search("mockingbrd")
    for i in range(len(results)):
        print("  ", results[i].item, "(score:", results[i].score, ")")

    # Partial
    print("\nSearch: 'old man sea'")
    results = fuse.search("old man sea")
    for i in range(len(results)):
        print("  ", results[i].item, "(score:", results[i].score, ")")

    # No match
    print("\nSearch: 'quantum physics'")
    results = fuse.search("quantum physics")
    if len(results) == 0:
        print("  (no results)")
    for i in range(len(results)):
        print("  ", results[i].item, "(score:", results[i].score, ")")
