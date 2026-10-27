require_relative '../actor'
require_relative 'fib'

puts "Process ID: #{$$}"

supervisor = Actor::Supervisor.new(name: "1m", concurrency: 1_000_00) do |message|
  message.to_s
end

1_000_000.times.each do |it|
  supervisor.send_message(it)
end

supervisor.send_message(Actor::ControlMessage::STOP)

supervisor.start

supervisor.await