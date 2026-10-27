require_relative '../actor'

my_sup_addr = SystemActor.supervisor do |message|
  p "Working on #{message}"
end

puts my_sup_addr


SystemActor.send_message(my_sup_addr, "Hi")