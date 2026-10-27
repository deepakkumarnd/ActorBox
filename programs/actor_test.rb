require_relative '../actor_box'

my_actor = SystemActor.actor do |message|
  p "Working on #{message}"
end


SystemActor.send_message(my_actor, "Hi")

sleep