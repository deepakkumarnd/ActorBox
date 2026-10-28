require 'securerandom'
require 'socket'

require 'actor_box/actor'

Actor = ActorBox::Actor

def check(name, ok)
  raise "FAIL: #{name}" unless ok
  puts "ok - #{name}"
end

actor = Actor.new {}
check("creates a new actor", actor.name.end_with?('-actor'))

actor = Actor.new
check("creates a new actor with optional block", actor.name.end_with?('-actor'))

actor = Actor.new(name: 'printer') {}
check("creates a new actor with a name", actor.name == 'printer-actor')

actor = Actor.new(name: 'printer-actor') {}
check("creates a new actor with name suffix '-actor'", actor.name == 'printer-actor')

actor = Actor.new() {}
check("creates a new actor with an initial READY state", actor.state == Actor::READY)

actor = Actor.new(name: 'any') {}
stats = {
  name: 'any-actor',
  address: actor.object_id,
  state: Actor::READY,
  message_count: 0
}
check("#stats returns the statistics as a hash", actor.stats == stats)

actor = Actor.new(name: 'printer') {}
check("#ref returns the actor object reference", actor.ref == actor)

actor = Actor.new(name: 'printer') {}
check("#ref returns the actor object reference", actor.ref == actor)

actor = Actor.new(name: 'printer') {}
check("actor address is the object id by default", actor.address == actor.object_id)

actor = Actor.new(name: 'printer') {}
address = ActorBox::Address.new(1, SecureRandom.hex(4), Socket.gethostname)
actor.set_address!(address)
check("#set_address! set actor address within the actor system", actor.address == address)

actor = Actor.new(name: 'printer') {}
3.times { actor.send_message('Hello') }
check("#send_message send a new message to the actor mailbox", actor.stats[:message_count] == 3)

actor = Actor.new(name: 'printer') { }
actor.start
sleep 0.05
check("#start will start the actor thread", actor.state == Actor::WAITING)

actor = Actor.new(name: 'printer') { }
2.times { actor.send_message('Hello') }
check("#start will process the messages send to the actor", actor.stats[:message_count] == 2)
actor.start
sleep 0.05
check("#start will process the messages send to the actor", actor.stats[:message_count] == 0)

actor = Actor.new(name: 'printer') { }
actor.start
actor.send_message(ActorBox::ControlMessage::STOP)
sleep 0.05
check("an actor can be stopped by sending ControlMessage::STOP", actor.state == ActorBox::Actor::STOPPED)


actor = Actor.new(name: 'printer') { }
actor.start
actor.send_message(ActorBox::ControlMessage::STOP)
sleep 0.05
response = actor.send_message('Hello')
check("A stopped actor does not accept any new messages", response == ActorBox::ControlMessage::REJECTED)


actor = Actor.new(name: 'printer') { }
actor.start
actor.send_message(ActorBox::ControlMessage::STOP)
sleep 0.05
actor.start
check("A stopped actor cannot be restarted", actor.state == ActorBox::Actor::STOPPED)

actor = Actor.new(name: 'printer') { }
actor.send_message("Hello")
actor.cleanup
check("#cleanup actor will empty the mailbox", actor.stats[:message_count] == 0)
