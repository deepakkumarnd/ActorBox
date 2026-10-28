require 'actor_box/supervisor'

Supervisor = ActorBox::Supervisor

def check(name, ok)
  raise "FAIL: #{name}" unless ok
  puts "ok - #{name}"
end

supervisor = Supervisor.new {}
check("creates a new supervisor", supervisor.name.end_with?('-supervisor'))

supervisor = Supervisor.new {}
check("concurrency is 1 by default", supervisor.concurrency == 1)

supervisor = Supervisor.new {}
check("#messages_count returns number of messages in the mailbox", supervisor.message_count == 0)

supervisor = Supervisor.new {}
check("#state is ready by default", supervisor.state == ActorBox::Actor::READY)

supervisor = Supervisor.new {}
stats = supervisor.stats
expectations = (stats[:name] == supervisor.name && 
stats[:address] == supervisor.address && 
stats[:message_count] == supervisor.message_count &&
stats[:actors].length == 1)
check("#stats returns the statistics as a hash", expectations)

supervisor = Supervisor.new {}
3.times { supervisor.send_message('hello') }
check("#send_message send messages to mailbox", supervisor.message_count == 3)
