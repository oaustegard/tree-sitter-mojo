# tree-sitter-mojo

Mojo grammar for tree-sitter. v1.0 ships when `script/check-errors.sh`
reports zero ERROR/MISSING nodes against `examples/*.mojo` (the fusemojo
acceptance corpus). Mojo-specific syntax is added one feature at a time,
tracked as issues.

## TDD is the default for grammar work

Grammar features are pure input → AST contracts. They map cleanly to
corpus-test-first development, and bolt-on tests miss the class of bugs
that matter (your wrong expectation about what a valid parse looks like).
**Write the corpus test before touching `grammar.js`.**

### When TDD applies here

- New syntactic constructs (`raises`, `var`, `comptime`, `alias`, `trait`, …)
- New highlight queries (test against a known fixture)
- Bug fixes (the corpus case encodes the regression)

### When TDD does not apply

- README / docs / metadata edits
- One-shot script tweaks in `script/`
- Manual exploration to figure out *what* the test should assert

If unsure, default to TDD. The cost of a corpus case that turns out to be
trivial is ~2 minutes; the cost of a grammar change that breaks a silent
edge case is hours.

### Seven-step loop

1. **Read the issue.** Scope to the smallest coherent slice. One construct,
   one PR.
2. **Write the corpus test.** Add a new file under `test/corpus/`
   (one file per feature, named after the construct). Cover the
   positional variations the issue calls out — don't write the test from
   the implementation you're already drafting in your head; write it from
   the spec.
3. **Stub** if the construct is new enough that `grammar.js` doesn't
   reference it at all yet. Often not needed for tree-sitter — you can
   skip straight to step 4.
4. **Run `tree-sitter test`. Confirm RED for the right reason.** A test
   that fails because the test file is malformed is not a real RED.
   Look at the actual diff between expected and actual S-expression.
   Reasoning about why it *will* fail without running is the failure mode
   here — actually run it.
5. **Edit `grammar.js`.** Add the rule, wire it into existing rules
   (usually `function_definition`, `_statement`, or the relevant parent).
   Run `tree-sitter generate` to rebuild `src/parser.c`. Commit the
   regenerated `parser.c` — it's the source-of-truth artifact, not a
   build product.
6. **Run `tree-sitter test` until GREEN, then `script/check-errors.sh`.**
   The corpus tests prove the new construct parses; the acceptance script
   proves you didn't regress the rest of the fusemojo corpus. Both must
   pass.
7. **Commit test + grammar change + regenerated parser together.** PR body
   tells the red → green story and reports the before/after error count
   from `script/check-errors.sh`.

### Project-specific gotchas

- `src/parser.c` is **committed**, not generated at install time. Always
  regenerate after any `grammar.js` edit and include the result in the
  commit.
- `tree-sitter generate` is verbose on conflicts. Read the conflict
  message — it usually points at exactly which rules need precedence or
  reordering.
- The corpus-test format is finicky about whitespace inside the
  S-expression block. Copy the actual `tree-sitter parse <file>` output
  rather than hand-writing the expected tree.
- `script/check-errors.sh` counts both `ERROR` and `MISSING` nodes.
  A grammar change can drop ERROR count while introducing MISSING — both
  matter.
- Don't add a `raises_clause` (or similar one-token wrapper) without a
  reason — but DO add it when queries / highlights need to reference the
  construct by name. The acceptance criteria for an issue tell you which.

### Verifying

```bash
tree-sitter generate          # rebuild parser.c from grammar.js
tree-sitter test              # corpus tests in test/corpus/
script/check-errors.sh        # acceptance corpus in examples/
```

All three should be clean before opening a PR.
