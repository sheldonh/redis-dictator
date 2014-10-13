require 'rubygems'
require 'net/dns'

class Resolver
  def initialize(nameservers: [], searchlist: [])
    @resolver = Net::DNS::Resolver.new
    @resolver.nameservers = nameservers unless nameservers.empty?
    @resolver.searchlist = searchlist unless searchlist.empty?
  end

  def resolve(name)
    puts "DEBUG: resolve(#{name})"
    packet = @resolver.search(name, Net::DNS::SRV)
    addresses = packet.additional.select { |rr| rr.type == "A" }.inject({}) { |m, a| m[a.name] = a.address.to_s; m }
    answers = packet.answer.map do |rr|
      address = addresses[rr.host]
      Answer.new(address: address, port: rr.port)
    end
    answers.first.tap do |answer|
      if answers.size > 0
        $stderr.puts "WARNING: #{name} resolved to multiple addresses; using #{answer}"
      end
    end
  end
end

class Answer
  attr_reader :address, :port

  def initialize(address: nil, port: nil)
    @address, @port = address, port
  end

  def to_s
    "#{address}:#{port}"
  end
end

