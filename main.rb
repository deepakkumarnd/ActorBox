require_relative 'actor'
require_relative 'supervisor'

puts "Process ID: #{$$}"

# computation
def fibonacci(n)
  a = 0
  b = 1
  c = 1

  (n-1).times do
    c = a + b
    a = b
    b = c
  end

  c
end

computation = -> () { fibonacci(rand(300000..400000)).to_s.length }


main_actor = Actor.new(name: 'main-actor') do |message|
  result = fibonacci(message)
  puts "Result #{result}"
end

main_actor.start

main_actor.send_message(10)
main_actor.send_message(20)
main_actor.send_message(StopActor.new)


# sleep 0.1
# main_actor.send_message("Magic wand 3")
p "Main actor id #{main_actor.address}"
p "Outer id #{object_id}"
another_actor = Actor.new do
  'do nothing' 
end




another_actor.start
p "Other actor id #{another_actor.address}"
another_actor.send_message("Test without block")
another_actor.send_message("Test without block")
another_actor.send_message(StopActor.new)

sleep 0.1

p "=" * 100
supervisor = Supervisor.new(name: 'fib', concurrency: 10) do |message|
  computation.call
end

supervisor.start

100.times do |i|
  supervisor.send_message("Message #{i}")
  sleep 0.01
end


supervisor.send_message(StopActor.new)

# sleep 0.2

# supervisor.send_message("Message")

sleep