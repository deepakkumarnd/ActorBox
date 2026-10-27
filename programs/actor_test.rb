require_relative '../actor'

my_actor = $actor_system.actor do |message|
  p "Working on #{message}"
end


$actor_system.send_message(my_actor, "Hi")

sleep