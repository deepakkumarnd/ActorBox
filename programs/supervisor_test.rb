require_relative '../actor'

my_sup = $actor_system.supervisor do |message|
  p "Working on #{message}"
end


$actor_system.send_message(my_sup, "Hi")

$actor_system.start
