# A control message is a special message that can be used to control
# life cycle of an actor

module ActorBox
  module ControlMessage
    CType = Data.define(:message)

    # Define control messages as objects
    OK = CType[:ok]
    REJECTED = CType[:rejected]
    STOP = CType[:stop]
  end
end