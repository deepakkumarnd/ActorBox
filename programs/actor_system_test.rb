require_relative '../actor'

actor_system = Actor::ActorSystem.new()
actor_system.start

supervisor = Actor::Supervisor.new(name: 'chat')

actor_system.register_actor(supervisor)

supervisor.start
supervisor.send_message("Hello")