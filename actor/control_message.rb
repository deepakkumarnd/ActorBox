# A control message is a special message that can be used to control
# life cycle of an actor

module Actor
  module ControlMessage
    OK = :ok
    REJECTED = :rejected
    STOP = :stop
  end
end