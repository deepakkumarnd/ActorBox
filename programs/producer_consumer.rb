require_relative '../actor'

user1 = Actor::Actor.new(name: 'Consumer1', mailbox_size: 10) do |message, ref|
  if message[:text] == '/stop'
    p "User1 received /stop stopping"
    ref.send_message(Actor::ControlMessage::STOP)
  else
    sleep(1)
    message[:sender].send_message({sender: ref, text: "/stop"}) if Time.now.to_i % 17 == 0
    message[:sender].send_message({sender: ref, text: "Pong"})

    p "User1 sending Pong"
  end
end

user2 = Actor::Actor.new(name: 'Consumer2', mailbox_size: 10) do |message, ref|
  if message[:text] == '/stop'
    p "User2 received /stop stopping"
    ref.send_message(Actor::ControlMessage::STOP)
  else
    sleep(1)
    message[:sender].send_message({sender: ref, text: "/stop"}) if Time.now.to_i % 11 == 0
    message[:sender].send_message({sender: ref, text: "Ping"})
    p "User2 sending Ping"
  end
end

user1.send_message({sender: user2, text: 'Ping'})

user1.start
user2.start

user1.await
user2.await
