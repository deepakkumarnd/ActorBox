require_relative 'actor'
require_relative 'programs/fib'

puts "Process ID: #{$$}"

# An expensive computation
computation = -> () { fib(rand(300000..400000)).to_s.length }

main_actor = Actor::Actor.new(name: 'main-actor') do |message|
  result = fib(message)
  puts "Result #{result}"
end

main_actor.start

main_actor.send_message(10)
main_actor.send_message(20)
main_actor.send_message(Actor::ControlMessage::STOP)


# sleep 0.1
# main_actor.send_message("Magic wand 3")
p "Main actor id #{main_actor.address}"
p "Outer id #{object_id}"
another_actor = Actor::Actor.new do
  'do nothing' 
end




another_actor.start
p "Other actor id #{another_actor.address}"
another_actor.send_message("Test without block")
another_actor.send_message("Test without block")
another_actor.send_message(Actor::ControlMessage::STOP)

sleep 0.1

p "=" * 100
supervisor = Actor::Supervisor.new(name: 'fib', concurrency: 10) do |message|
  computation.call
end

supervisor.start

100.times do |i|
  supervisor.send_message("Message #{i}")
  sleep 0.01
end


supervisor.send_message(Actor::ControlMessage::STOP)

# sleep 0.2

# supervisor.send_message("Message")

sleep