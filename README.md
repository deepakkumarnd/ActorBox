# ActorBox

> ActorBox is where the actors live.

A small actor model library written in Ruby and compiled to a native binary
with [Spinel](https://github.com/matz/spinel), an ahead-of-time Ruby compiler.

Each actor owns an unbounded mailbox by default and handles its messages one at a time on its
own thread. A supervisor runs a pool of actors and hands messages to them in
round-robin order.


## Requirements

You need the Spinel compiler installed before you can build or test anything.
ActorBox is not a gem and does not run as a plain Ruby library: every program
that uses it must be compiled with Spinel.

Build and install Spinel from source:

```sh
git clone https://github.com/matz/spinel.git
cd spinel
make deps            # fetch libprism (one-time)
make                 # build the spinel compiler and the spin package tool
sudo make install    # install spinel and spin into /usr/local/bin
```

To install somewhere else, use `make install PREFIX=$HOME/.local` and make
sure that prefix's `bin` directory is on your `PATH`. Check the install with:

```sh
spinel --help
spin --help
```

## Quick start

Create actors through `SystemActor`, the global actor system. It starts the
actor for you, registers it under an address, and lets you stop everything in
one call.

```ruby
require "actor_box"

printer = SystemActor.actor(name: 'printer') do |message|
  puts "Got #{message}"
end

SystemActor.send_message(printer, 'hello')  # => :ok
SystemActor.stop                            # send STOP to every actor and wait
```

`SystemActor.actor` returns the actor's address, not the actor object. You
talk to the actor by sending messages to that address.

## Concepts

Everything lives under the `ActorBox` module, except `SystemActor`, which is a
top-level constant.

| Entity | What it is |
| --- | --- |
| [`ActorBox::Actor`](#actor) | Handles messages one at a time on its own thread |
| [`ActorBox::Supervisor`](#supervisor) | An actor that spreads messages over a pool of child actors |
| [`ActorBox::ActorSystem`](#actorsystem) | A registry that creates, starts, finds and stops actors by address |
| [`ActorBox::ActorAddress`](#actoraddress) | The address an actor gets when it joins an actor system |
| [`ActorBox::MailBox`](#mailbox) | The FIFO queue in front of every actor |
| [`SystemActor`](#systemactor) | The global `ActorSystem` created when you `require "actor_box"` |
| [`ActorBox::ControlMessage`](#controlmessage) | Symbols that control an actor or report whether a message was accepted |

### Actor

An actor is a block of code with a mailbox and a thread. Messages sent to it
wait in its mailbox, and the thread takes them out one at a time and runs the
block on each. Because only that thread runs the block, state the block
closes over is never touched by two messages at once. The block receives the
message and the actor itself, so it can read its own `name`, `address` or
`stats`.

An actor moves through four states: `:ready` after `new`, `:running` while it
handles a message, `:waiting` while its mailbox is empty, and `:stopped` once
it dequeues `ControlMessage::STOP`. Messages queued before `STOP` are handled
first. A stopped actor rejects new messages.

Create one through `SystemActor`, which starts it
and gives it an address:

```ruby
require "actor_box"

counter = SystemActor.actor(name: 'counter') do |message, actor|
  puts "#{actor.name} handling #{message}"
end

3.times { |i| SystemActor.send_message(counter, i) }
SystemActor.stop
```

Reference:

- `ActorBox::Actor.new(name: nil, mailbox_size: nil) { |message, actor| ... }`
  creates an actor in the `:ready` state. `-actor` is appended to the name
  unless it already ends that way. The mailbox is unbounded unless you pass
  `mailbox_size`.
- `start` spawns the actor's thread.
- `send_message(message)` returns `:ok`, or `:rejected` if a bounded mailbox
  is full or the actor has stopped. It never blocks.
- `await` joins the actor's thread.
- `name`, `address`, `state`, `stopped?`, `stats`.
- `address` is the actor's `object_id` until an actor system registers it,
  then an [`ActorAddress`](#actoraddress).

### Supervisor

A supervisor is an actor whose job is to run a pool of child actors that all
share one block. It does no work itself: every message it receives is passed
to the next child in round-robin order, so up to `concurrency` messages are
handled in parallel. Stopping a supervisor stops the whole pool.

Create one through `SystemActor`:

```ruby
require "actor_box"

squares = SystemActor.supervisor(name: 'squares', concurrency: 4) do |message|
  puts message * message
end

10.times { |i| SystemActor.send_message(squares, i) }
SystemActor.stop
```

`SystemActor.supervisor` registers every child with `SystemActor`, so each
child has its own address you can message directly, and `SystemActor.stop`
reaches the children as well as the supervisor.

Reference:

- `ActorBox::Supervisor.new(name: nil, concurrency: 1, mailbox_size: nil, system: nil) { |message, actor| ... }`.
  `-supervisor` is appended to the name, and each child is named
  `<name>-actor`.
- `mailbox_size:` sets the size of each child's mailbox. Children have
  unbounded mailboxes when it is omitted. The supervisor's own mailbox is
  always unbounded.
- With bounded child mailboxes, if a child rejects a message the supervisor
  tries the next one. After a full pass with no taker it backs off
  exponentially (starting at 100ms) before trying again.
- On `ControlMessage::STOP`, the supervisor sends `STOP` to every child, waits
  for all of them to finish, cleans them up, and stops itself.
- With several children, output order depends on thread scheduling.

### ActorSystem

An actor system is a registry of actors keyed by address. Registering an
actor gives it an [`ActorAddress`](#actoraddress) that is unique to that
system and host. After that, code that only knows the address can send the
actor messages, and the system can stop or wait for all of its actors at
once. The system is not an actor itself: it has no mailbox or thread.

You normally use the global [`SystemActor`](#systemactor) rather than
creating your own. `actor` and `supervisor` create, register and start an
actor in one step and return its address:

```ruby
require "actor_box"

logger = SystemActor.actor(name: 'logger') { |line| puts line }
SystemActor.send_message(logger, 'booting')   # => :ok

SystemActor.send_message(ActorBox::ActorAddress.build(1, 'deadbeef', 'nowhere'), 'hi')
# warns "Actor not found for address ..." and returns nil
```

To use options that `actor` doesn't take, such as `mailbox_size:`, build the
actor yourself and register it before starting it:

```ruby
bounded = ActorBox::Actor.new(name: 'bounded', mailbox_size: 10) { |m| puts m }
SystemActor.register_actor(bounded)
bounded.start

SystemActor.send_message(bounded.address, 'hi')
SystemActor.lookup_actor(bounded.address)   # => the same actor object
```

A long-running program can hand control to the system and let a signal end
it:

```ruby
SystemActor.actor(name: 'heartbeat') { |m| puts m }
SystemActor.wait   # blocks until SIGINT or SIGTERM, then stops every actor
```

Reference:

- `actor(name: nil) { |message, actor| ... }` returns the new actor's address.
- `supervisor(name: nil, concurrency: 1) { |message, actor| ... }` returns
  the new supervisor's address. Its children are registered too, so each has
  its own address.
- `send_message(address, message)` returns what the actor's `send_message`
  returns, or `nil` (with a warning) if no actor has that address.
- `register_actor(actor)` gives the actor an address and adds it to the
  registry. Call it before `start` so log lines use the final address.
- `lookup_actor(address)` returns the actor, or `nil`.
- `stop` sends `STOP` to every registered actor and waits for them.
- `await` waits for every registered actor without stopping them.
- `wait` traps `INT` and `TERM`, blocks until one arrives, then calls `stop`.

`actor` and `supervisor` always register with `SystemActor`, even when called
on another `ActorSystem` instance, so stick to `SystemActor`.

### ActorAddress

An address names an actor inside an actor system. It has three parts, the
actor's id, the id of the actor system (8 random hex characters picked when
the system is created) and the hostname, written as
`<actor_id>@<system_id>.<hostname>`. Two systems on the same host, or the same
program on two hosts, produce different addresses for their actors. An actor
gets its address when an actor system registers it.

Addresses are `Data` values, so two addresses with the same parts are equal
and work as hash keys. You rarely build one yourself: keep the address that
`SystemActor.actor` or `SystemActor.supervisor` returned and pass it around.

```ruby
require "actor_box"

address = SystemActor.actor(name: 'echo') { |m| puts m }

address.actor_id   # => 1234
address.system_id  # => "9f2c41ab"
address.hostname   # => "build-box"
address.to_s       # => "1234@9f2c41ab.build-box"
```

`build` checks the result against `ADDRESS_PATTERN` and raises
`ActorAddress::InvalidAddressError` if it doesn't match:

```ruby
ActorBox::ActorAddress.build(42, '9f2c41ab', 'build-box')   # => valid address
ActorBox::ActorAddress.build(42, 'nothex!', 'build-box')    # raises InvalidAddressError
ActorBox::ActorAddress.valid?(address)                      # => true
```

`ActorAddress.from_s("1234@9f2c41ab.build-box")` parses a string back into an
address. It is not yet a reliable way to find an actor: it keeps the actor id
as a string where registered addresses hold an integer, and it drops every
hostname label after the first, so the result may not equal the registered
address.

### MailBox

Every actor has a mailbox: a FIFO queue that holds messages until the actor's
thread is ready for them. Senders never wait on it. An unbounded mailbox
accepts everything, and a bounded one rejects messages once it is full, which
pushes back on producers that outpace the actor. The actor's thread is the
only reader and blocks on the mailbox while it is empty.

You don't create mailboxes when you use actors: pass `mailbox_size:` to
`ActorBox::Actor.new` or `ActorBox::Supervisor.new` instead. The class is useful on
its own, or when testing:

```ruby
require "actor_box/mailbox"

unbounded = ActorBox::MailBox.new
unbounded.enqueue('a')   # => :ok, always

bounded = ActorBox::MailBox.new(2)
bounded.enqueue('a')     # => :ok
bounded.enqueue('b')     # => :ok
bounded.enqueue('c')     # => :rejected, and warns on stderr
bounded.length           # => 2
bounded.dequeue          # => "a"
```

Reference:

- `MailBox.new` creates an unbounded mailbox backed by `Queue`.
- `MailBox.new(max_size)` creates a bounded mailbox backed by `SizedQueue`.
- `enqueue(message)` never blocks. It returns `:ok`, or `:rejected` when a
  bounded mailbox is full.
- `dequeue` blocks until a message is available.
- `empty?`, `length` (aliased as `size` and `count`), `max_size`.

### SystemActor

`SystemActor` is a single `ActorBox::ActorSystem` created when you
`require "actor_box"`, shared by the whole program. It is the safe default way
to work with actors: every actor it creates is started, has an address, and
is stopped by one `SystemActor.stop`, so none are left running when the
program ends. Code anywhere in the program can reach an actor through its
address without passing objects around.

A typical program creates its actors and supervisors up front, sends work,
and stops the system at the end:

```ruby
require "actor_box"

results = SystemActor.actor(name: 'results') do |line|
  puts line
end

workers = SystemActor.supervisor(name: 'workers', concurrency: 4) do |n|
  SystemActor.send_message(results, "#{n} squared is #{n * n}")
end

10.times { |n| SystemActor.send_message(workers, n) }

SystemActor.stop
```

Actors talk to each other the same way: pass addresses, not objects. Here the
`results` address is captured by the workers' block. `stop` stops actors in
the order they were registered, so messages a worker sends to `results` after
`results` has stopped are rejected. Register consumers after producers, or
stop producers first by hand, when that matters.

A service that runs until it is told to stop uses `wait`:

```ruby
require "actor_box"

SystemActor.supervisor(name: 'jobs', concurrency: 8) do |job|
  puts "processing #{job}"
end

SystemActor.wait   # Ctrl-C or SIGTERM stops every actor, then returns
```

`actor_box.rb` also registers an `at_exit` hook that prints `"Stopping actor
system"`. It doesn't stop anything, so still call `stop` or `wait` yourself.

### ControlMessage

Control messages are plain symbols with two jobs. `STOP` is a message you
send to an actor to end its life cycle rather than to give it work. `OK` and
`REJECTED` are what `send_message` and `MailBox#enqueue` return, so senders
can tell whether a message was accepted. Compare against the constants rather
than the bare symbols.

| Constant | Value | Meaning |
| --- | --- | --- |
| `STOP` | `:stop` | Tells an actor to stop once it reaches this message |
| `OK` | `:ok` | The message was accepted |
| `REJECTED` | `:rejected` | The message was dropped: the mailbox was full or the actor has stopped |

`STOP` goes through the mailbox like any other message, so it doesn't
interrupt the actor. Everything queued before it is handled first, and the
block never sees `STOP` itself. With `SystemActor` you rarely send it
directly, because `SystemActor.stop` sends it to every registered actor. You
can still stop one actor by address:

```ruby
require "actor_box"

worker = SystemActor.actor(name: 'worker') { |job| puts "doing #{job}" }

SystemActor.send_message(worker, 'job 1')
SystemActor.send_message(worker, 'job 2')
SystemActor.send_message(worker, ActorBox::ControlMessage::STOP)  # after job 2
SystemActor.lookup_actor(worker).await
SystemActor.send_message(worker, 'job 3')                      # => :rejected
```

Sending `STOP` to a supervisor stops its children first: it passes `STOP` to
every child, waits for them to finish their queued work, then stops itself.

Check the result of `send_message` when the mailbox is bounded or the actor
may already have stopped:

```ruby
actor = ActorBox::Actor.new(name: 'bounded', mailbox_size: 1) { |m| sleep 1 }
actor.start

case actor.send_message('work')
when ActorBox::ControlMessage::OK       then puts 'queued'
when ActorBox::ControlMessage::REJECTED then puts 'full or stopped, try later'
end
```

`SystemActor.send_message` returns `nil` instead of either value when no
actor has the address.

Because `STOP` is just `:stop`, an actor that receives the symbol `:stop` as
ordinary data will stop. Wrap such values, for example in a hash or a string,
if your messages can contain it.

## Using the library from another project

Add it as a path dependency:

```sh
cd ../myapp
spin add actor_box --path ../actors
```

Then `require "actor_box"`. Scripts inside this repo, like [main.rb](main.rb), use
`require_relative 'actor_box'`.

## Running the example

```sh
spinel main.rb    # compiles to ./main
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
spin test                  # run all tests
spin test mailbox_test.rb  # run one test
spin test --regen          # refresh .expected snapshots
```

Build output goes to `build/`.

### With CRuby

Add the repo root to the load path so `require "actor_box/..."` resolves the same
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
require "actor_box/mailbox"

def check(name, ok)
  raise "FAIL: #{name}" unless ok
  puts "ok - #{name}"
end

mailbox = ActorBox::MailBox.new
check("returns ok on enqueue", mailbox.enqueue("hello") == ActorBox::ControlMessage::OK)
```

Keep output identical between runs:

- Don't print object IDs or `inspect` output that contains addresses.
- Leave `DEBUG_MODE` unset.
- With several actors, collect results, `await` the actors, then print the
  results sorted.
- Wait with `await`, not `sleep`.
