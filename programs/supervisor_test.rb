require_relative '../actor'

my_sup = SystemActor.supervisor do |message|
  p "Working on #{message}"
end


SystemActor.send_message(my_sup, "Hi")

SystemActor.start
