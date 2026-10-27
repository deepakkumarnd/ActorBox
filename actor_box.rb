require_relative 'actor_box/actor'
require_relative 'actor_box/supervisor'
require_relative 'actor_box/actor_system'

$debug_mode = ENV['DEBUG_MODE'] == 'true'
# singleton actor system initialized on load

SystemActor = ActorBox::ActorSystem.new

at_exit do
  p "Stopping actor system"
end