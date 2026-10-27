require 'securerandom'


module ActorAddress
  Address = Data.define(:actor_id, :system_id, :hostname) do
    def to_s
      "#{actor_id}@#{system_id}.#{hostname}"
    end
  end

  class InvalidAddressError < StandardError; end

  ADDRESS_PATTERN = /\A[1-9][0-9]*@[0-9a-f]{8}(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+\z/
  
  def self.from_s(address_str)
    parts =  address_str.split('@')
    actor_id = parts[0]
    system_id, hostname = parts[1].split('.')
    build(actor_id, system_id, hostname)
  end

  def self.build(actor_id, system_id, hostname)
    address = Address.new(actor_id, system_id, hostname)
    raise InvalidAddressError unless valid?(address)
    address
  end

  def self.valid?(address)
    address.to_s.match?(ADDRESS_PATTERN)
  end
end

address = ActorAddress.build('1', SecureRandom.hex(4), 'localhost')

p address
puts address

p ActorAddress.from_s(address.to_s)

system_id = SecureRandom.hex(4)
p system_id

a1 = ActorAddress.build(object_id, system_id, 'localhost')
puts a1