# Calling a user-defined method on an object returned by Enumerator#next.
#
# CRuby prints "Works" on every line. Spinel (5144f3699) answers `class`
# correctly but raises NoMethodError for the user-defined method:
#
#   ./bin/spinel -E programs/cycle.rb
#   ruby programs/cycle.rb

class Greeter
  def greet
    'Works'
  end
end

greeters = Array.new(3) { Greeter.new }

def check(label)
  puts "#{label}: #{yield}"
rescue NoMethodError => e
  puts "#{label}: NoMethodError (#{e.message})"
end

check('Array#[]                ') { greeters[0].greet }
check('Enumerator#next  (class)') { greeters.cycle.next.class }
check('Array#cycle  then #next ') { greeters.cycle.next.greet }
check('Array#each   then #next ') { greeters.each.next.greet }

# Reported Issue https://github.com/matz/spinel/issues/9620