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
