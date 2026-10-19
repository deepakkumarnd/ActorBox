# Test sized queue

MAX_SIZE = 10

@queue = SizedQueue.new(10)

def enqueue(item)
  # sized queue reject with nil when timeout is 0 or it
  # wait for the queue to make some space
  if (@queue.size < MAX_SIZE) && @queue.push(item, timeout: 0)
    :ok 
  else 
    :rejected
  end
end

p @queue.empty?

13.times.each do
  Thread.new do
    size = @queue.size
    p "Queue size #{size}"
    p enqueue(it)
  end
end

sleep