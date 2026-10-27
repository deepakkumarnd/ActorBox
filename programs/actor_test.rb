require_relative '../actor'

my_actor = SystemActor.actor do |message|
  p "Working on #{message}"
end


SystemActor.send_message(my_actor, "Hi")

sleep