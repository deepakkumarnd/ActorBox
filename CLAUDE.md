# CLAUDE.md

## This is a Spinel project, not a plain Ruby project

The code is written in Ruby but compiled to a native binary with Spinel, an
ahead-of-time Ruby compiler. Everything must compile and run under Spinel;
working under CRuby alone is not enough.

- Only use Ruby features and libraries Spinel supports. Gems such as Minitest
  and pry are not available. Check the limitations doc before reaching for
  anything beyond core Ruby.
- Build, run and test with `spin` (symlinked at `bin/spin`), not `ruby`.

## Spinel source code

Spinel is checked out at `/Users/deepak/Work/spinel/source_code`
(`../spinel/source_code` from this repo). Useful docs there:

- `docs/spin.md`: the `spin` package tool (layout, `require` resolution, tests)
- `docs/limitations.md`: what Spinel does not support
- `docs/thread.md`: Thread, Mutex and Queue support
- `packages/`: the stdlib packages that are available

## Tests

Each `test/*.rb` is a standalone program, not a Minitest file. Write checks
that raise on failure and print a line on success. Spin diffs stdout against
`test/<name>.rb.expected`, and a non-zero exit fails the test.

```sh
bin/spin test                  # run all tests
bin/spin test mailbox_test.rb  # run one test
bin/spin test --regen          # refresh .expected snapshots
```
