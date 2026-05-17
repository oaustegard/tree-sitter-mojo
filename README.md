tree-sitter-mojo
================

[Mojo](https://www.modular.com/mojo) grammar for [tree-sitter](https://github.com/tree-sitter/tree-sitter).

**Status:** early WIP — parses Python-compatible subset of Mojo cleanly; Mojo-specific syntax (`var`, `raises`, `comptime`, `alias`, `trait`, ownership operators) is being added one feature at a time, tracked as issues.

Acceptance corpus: the source of [fusemojo](https://github.com/oaustegard/fusemojo) (~640 lines of real Mojo across 4 files). v1.0 ships when `script/check-errors.sh` reports zero ERROR/MISSING nodes against the corpus.

## Lineage

- Initial concept and `fn`/`struct` keywords: [HerringtonDarkholme/tree-sitter-mojo](https://github.com/HerringtonDarkholme/tree-sitter-mojo) (MIT, last touched 2023-05-10).
- Grammar base rebased onto modern [tree-sitter/tree-sitter-python](https://github.com/tree-sitter/tree-sitter-python) v0.25 for the working `scanner.c`, type-parameter brackets, and f-string handling.
- Mojo additions land here.

## Building

Requires [tree-sitter CLI](https://tree-sitter.github.io/tree-sitter/cli/) 0.26+ and a C compiler.

```bash
tree-sitter generate
tree-sitter test            # corpus tests in test/corpus/
script/check-errors.sh      # acceptance corpus in examples/
```

## Project layout

```
grammar.js                  -- the grammar DSL
src/scanner.c               -- INDENT/DEDENT/string scanner (from tree-sitter-python)
src/parser.c                -- generated, committed
test/corpus/                -- tree-sitter test corpus (one .txt per feature)
examples/*.mojo             -- real Mojo files; script/check-errors.sh asserts zero parse errors
script/check-errors.sh      -- v1.0 acceptance gate
queries/highlights.scm      -- syntax highlighting queries
bindings/                   -- Node and Rust bindings
```

## License

MIT
