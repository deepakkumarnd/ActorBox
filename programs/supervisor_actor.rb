require_relative '../actor'
require_relative 'fib'

puts "Process ID: #{$$}"

$debug_mode = true

# An expensive computation
computation = -> () { fib(rand(300000..400000)).to_s.length }

supervisor = Actor::Supervisor.new(name: 'fibonacci', mailbox_size: 2, concurrency: 2) do |message|
  computation.call
end

supervisor.start

10.times do |i|
  supervisor.send_message("Message #{i}")
  sleep 0.01
end

Thread.new do
  loop do
    sleep(5)
    p supervisor.stats
  end
end

supervisor.send_message(Actor::ControlMessage::STOP)

supervisor.await
p supervisor.stats