require_relative 'actor/actor'
require_relative 'actor/supervisor'
require_relative 'actor/actor_system'

$debug_mode = ENV['DEBUG_MODE'] == 'true'
# singleton actor system initialized on load

SystemActor = Actor::ActorSystem.new

at_exit do
  p "Stopping actor system"
end