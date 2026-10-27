require_relative 'stage/actor'
require_relative 'stage/supervisor'
require_relative 'stage/actor_system'

$debug_mode = ENV['DEBUG_MODE'] == 'true'
# singleton actor system initialized on load

SystemActor = Stage::ActorSystem.new

at_exit do
  p "Stopping actor system"
end