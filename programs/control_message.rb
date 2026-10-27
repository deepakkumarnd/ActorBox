module ControlMessage
  CType = Data.define(:message)

  OK = CType[:ok]
  REJECTED = CType[:rejected]
  STOP = CType[:stop]
end

p ControlMessage::OK