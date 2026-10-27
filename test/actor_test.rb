require 'actor/actor'

def check(name, ok)
  raise "FAIL: #{name}" unless ok
  puts "ok - #{name}"
end

actor = Actor::Actor.new {}
check("creates a new actor", actor.name.end_with?('-actor'))

actor = Actor::Actor.new
check("creates a new actor with optional block", actor.name.end_with?('-actor'))

actor = Actor::Actor.new(name: 'printer') {}
check("creates a new actor with a name", actor.name == 'printer-actor')

actor = Actor::Actor.new(name: 'printer-actor') {}
check("creates a new actor with suffix '-actor'", actor.name == 'printer-actor')

actor = Actor::Actor.new() {}
check("creates a new actor with an initial READY state", actor.state == Actor::Actor::READY)

actor = Actor::Actor.new(name: 'any') {}
stats = {
  name: 'any-actor',
  address: actor.object_id,
  state: Actor::Actor::READY,
  message_count: 0
}
check("returns the stats as a hash", actor.stats == stats)
