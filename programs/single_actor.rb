require_relative '../actor'
require_relative 'fib'

puts "Process ID: #{$$}"
$debug_mode = true

main_actor = Actor::Actor.new(name: 'main-actor') do |message|
  result = fib(message)
  puts "Result #{result}"
end

main_actor.start

main_actor.send_message(10)
main_actor.send_message(20)
main_actor.send_message(Actor::ControlMessage::STOP)

sleep 0.1
main_actor.send_message("Magic wand 3")

p "Main actor stats"
p main_actor.stats

p "Outer id #{object_id}"


another_actor = Actor::Actor.new do
  'do nothing' 
end

p another_actor.stats
another_actor.start

p "Other actor id #{another_actor.address}"
another_actor.send_message("Test without block")
another_actor.send_message("Test without block")
another_actor.send_message(Actor::ControlMessage::STOP)

sleep 0.1

[main_actor, another_actor].each(&:await)
