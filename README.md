# Actors

A small actor model library written in Ruby and compiled to a native binary
with [Spinel](../spinel/source_code), an ahead-of-time Ruby compiler.

Each actor owns an unbounded mailbox by default and handles its messages one at a time on its
own thread. A supervisor runs a pool of actors and hands messages to them in
round-robin order.

## Quick start

```ruby
require "actor"

printer = Actor::Actor.new(name: 'printer') do |message|
  puts "Got #{message}"
end

printer.start
printer.send_message('hello')                      # => :ok
printer.send_message(Actor::ControlMessage::STOP)  # finish queued work, then stop
printer.await                                      # wait for the thread to exit
```

## Setup

`bin/` is gitignored. After cloning, link the Spinel tools into it (this
assumes Spinel is checked out at `../spinel/source_code`):

```sh
mkdir -p bin
ln -s ../../spinel/source_code/bin/spin bin/spin
ln -s ../../spinel/source_code/spinel   bin/spinel
```

## Project layout

This is a [spin](../spinel/source_code/docs/spin.md) library package. Spin
resolves `require "actor"` to `actor.rb` and `require "actor/<name>"` to
`actor/<name>.rb`, so there is no `lib/` directory.

```
actors/
├── spin.toml               # package manifest
├── actor.rb                # entry point: loads Actor and Supervisor
├── actor/
│   ├── actor.rb            # Actor::Actor
│   ├── control_message.rb  # Actor::ControlMessage
│   ├── mailbox.rb          # Actor::MailBox
│   └── supervisor.rb       # Actor::Supervisor
├── programs/
│   ├── fib.rb              # fib(n), used by main.rb
│   └── cycle.rb            # repro for a Spinel Enumerator#next bug
├── main.rb                 # example program
└── test/                   # one standalone test program per file
```

## API

Everything lives under the `Actor` module.

### `Actor::ControlMessage`

Symbols that control an actor's life cycle instead of carrying work:

| Constant | Value | Meaning |
| --- | --- | --- |
| `STOP` | `:stop` | Tells an actor to stop once it reaches this message |
| `OK` | `:ok` | `send_message` / `enqueue` accepted the message |
| `REJECTED` | `:rejected` | The message was dropped: the mailbox was full or the actor has stopped |

### `Actor::MailBox`

A FIFO queue. It is unbounded by default; pass a size to bound it.

- `MailBox.new` creates an unbounded mailbox backed by `Queue`. `enqueue`
  always returns `:ok`.
- `MailBox.new(max_size)` creates a bounded mailbox backed by `SizedQueue`.
  `enqueue` returns `:rejected` (and warns on stderr) once it holds `max_size`
  messages.
- `enqueue` never blocks.
- `dequeue` blocks until a message is available.
- `empty?`, `length` (aliased as `size` and `count`).

### `Actor::Actor`

- `Actor::Actor.new(name: 'actor', mailbox_size: nil) { |message| ... }`
  creates an actor in the `:ready` state. The block runs once per message.
  The mailbox is unbounded unless you pass `mailbox_size`.
- `start` spawns the actor's thread (state becomes `:running`).
- `send_message(message)` puts a message in the mailbox and returns `:ok`, or
  `:rejected` if a bounded mailbox is full or the actor has stopped.
- `await` joins the actor's thread.
- `stopped?`, `state`, `stats`, `name`, `address` (the actor's `object_id`).

When the actor dequeues `ControlMessage::STOP`, it exits its loop and its state
becomes `:stopped`. Messages queued before `STOP` are processed first.

### `Actor::Supervisor`

A subclass of `Actor::Actor` that runs a pool of child actors, all using the
same block:

```ruby
pool = Actor::Supervisor.new(name: 'squares', concurrency: 10) do |message|
  puts message * message
end

pool.start                                       # starts all children
50.times { |i| pool.send_message(i) }
pool.send_message(Actor::ControlMessage::STOP)
pool.await
```

- `mailbox_size:` sets the size of each child's mailbox. Children have
  unbounded mailboxes when it is omitted. The supervisor's own mailbox is
  always unbounded.
- Each message goes to the next child in round-robin order. With bounded
  child mailboxes, if a child rejects the message the supervisor tries the
  next one, and after a full pass with no taker it backs off exponentially
  (starting at 100ms) before trying again.
- On `ControlMessage::STOP`, the supervisor sends `STOP` to every child, waits
  for all of them to finish, cleans them up, and stops itself.
- With several children, output order depends on thread scheduling.

## Using the library from another project

Add it as a path dependency:

```sh
cd ../myapp
../actors/bin/spin add actor --path ../actors
```

Then `require "actor"`. Scripts inside this repo, like [main.rb](main.rb), use
`require_relative 'actor'`.

## Running the example

```sh
bin/spinel main.rb    # compiles to ./main
./main
```

`main.rb` ends with a bare `sleep`, so it never exits on its own. Stop it with
Ctrl-C.

### Debug logging

Set `DEBUG_MODE=true` to log every message an actor processes:

```sh
DEBUG_MODE=true ./main
```

The flag is read at run time, so the same binary works with logging on or off.
Set it per command rather than exporting it: log lines include object IDs,
which change on every run and would break test snapshots.

## Tests

Each `test/*.rb` is a standalone program that uses only core Ruby, so it runs
under both Spinel and CRuby.

### With Spinel

`spin test` compiles each test with this package's sources and checks it:

- If `test/<name>.rb.expected` exists, stdout must match it.
- Otherwise the test also runs under CRuby and the two outputs must match.
- A non-zero exit fails the test.

```sh
bin/spin test                  # run all tests
bin/spin test mailbox_test.rb  # run one test
bin/spin test --regen          # refresh .expected snapshots
```

Build output goes to `build/`.

### With CRuby

Add the repo root to the load path so `require "actor/..."` resolves the same
way it does under spin:

```sh
ruby -I. test/mailbox_test.rb
```

A failed check raises and exits non-zero. Passing under CRuby is a quick
check, not a substitute: the code must also compile and pass under Spinel.

### Writing a test

Minitest isn't available under Spinel. Write checks that raise on failure and
print a line on success:

```ruby
require "actor/mailbox"

def check(name, ok)
  raise "FAIL: #{name}" unless ok
  puts "ok - #{name}"
end

mailbox = Actor::MailBox.new
check("returns ok on enqueue", mailbox.enqueue("hello") == Actor::ControlMessage::OK)
```

Keep output identical between runs:

- Don't print object IDs or `inspect` output that contains addresses.
- Leave `DEBUG_MODE` unset.
- With several actors, collect results, `await` the actors, then print the
  results sorted.
- Wait with `await`, not `sleep`.

## Known issues

- [programs/cycle.rb](programs/cycle.rb) reproduces a Spinel bug where calling
  a user-defined method on the result of `Enumerator#next` raises
  `NoMethodError` ([matz/spinel#9620](https://github.com/matz/spinel/issues/9620)).
  The supervisor's round-robin uses the same `Array#cycle` + `next` pattern. It
  works with the current Spinel build, but suspect this first if supervisor
  scheduling breaks after a compiler update.
