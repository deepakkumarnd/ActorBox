# Actors

An actor model framework written in Ruby and compiled to a native binary with
[Spinel](../spinel/source_code), an ahead-of-time Ruby compiler.

Each actor owns a mailbox and processes its messages one at a time on its own
thread. A supervisor runs a pool of actors and hands incoming messages to them
in round-robin order.

## Components

| File | What it does |
| --- | --- |
| [mailbox.rb](mailbox.rb) | `MailBox`: a bounded queue (`MAX_SIZE = 100`) of messages for one actor. `ControlMessage` and `StopActor`: messages that control an actor instead of carrying work. |
| [actor.rb](actor.rb) | `Actor`: runs a block for each message in its mailbox on a dedicated thread, and stops when it receives `StopActor`. |
| [supervisor.rb](supervisor.rb) | `Supervisor`: an actor that starts `concurrency` child actors and forwards each message it receives to the next child in round-robin order. |
| [main.rb](main.rb) | Example program that uses a single actor and a supervisor. |

### Mailbox

- `enqueue(message)` returns `:ok`, or `:rejected` when the mailbox already
  holds `MAX_SIZE` messages.
- `dequeue` blocks until a message is available.

### Actor

An actor moves through three states: `:ready` → `:running` → `:stopped`.

```ruby
require_relative 'actor'

actor = Actor.new(name: 'printer') do |message|
  puts "Got #{message}"
end

actor.start                         # spawn the actor's thread
actor.send_message('hello')         # => :ok, or :rejected if the mailbox is full
actor.send_message(StopActor.new)   # finish queued messages, then stop
actor.await                         # wait for the thread to exit
```

Sending a message to a stopped actor raises an error.

### Supervisor

```ruby
require_relative 'supervisor'

pool = Supervisor.new(name: 'fib', concurrency: 10) do |message|
  fibonacci(message)
end

pool.start
100.times { |i| pool.send_message(i) }
pool.send_message(StopActor.new)
pool.await
```

Scheduling is round-robin: the supervisor cycles through its child actors and
gives each new message to the next one. If that child's mailbox is full, the
supervisor sleeps with a short backoff and tries the next child, until one
accepts the message.

When the supervisor receives `StopActor`, it sends `StopActor` to every child,
waits for all of them to finish, cleans them up, and then stops itself.

## Running

With the standard Ruby interpreter (Ruby 3.4+, because the code uses the `it`
block parameter):

```sh
ruby main.rb
```

Compiled to a native binary with Spinel:

```sh
./spinel main.rb          # produces ./main
./main
```

`spinel` is a symlink to `../spinel/source_code/spinel`; run `./spinel --help`
for its other options.

Debug logging is controlled by the global `$debug_mode` in
[actor.rb](actor.rb).
