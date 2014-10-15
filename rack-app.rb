#!/usr/bin/env ruby

require 'rubygems'
require 'rack'
require 'json'

require_relative './lib'
require_relative './resolver'

class RedisDictatorRackApp
  def call(env)
    req = Rack::Request.new(env)
    if req.path == "/master"
      if req.put?
        master(req)
      else
        [405, {'Content-Type' => 'text/plain'}, ["Method Not Allowed\n"]]
      end
    else
      [404, {'Content-Type' => 'text/plain'}, ["Object Not Found\n"]]
    end
  end

  private

    def master(req)
      begin
        json = req.body.read
        body = JSON.parse(json)
        master = resolve(host: body["master"]["address"], port: body["master"]["port"])
        slaves = body["slaves"].inject([]) { |acc, s| acc << resolve(host: s["address"], port: s["port"]) }
        all = slaves.unshift(master)
        begin
          rg = RedisGroup.new(services: all)
          rg.dictate_master(service: master)
          [200, {'Content-Type' => 'text/plain'}, ["OK\n"]]
        rescue Exception => e
          $stderr.puts "#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
          [500, {'Content-Type' => 'text/plain'}, ["#{e.class}: #{e.message}\n"]]
        end
      rescue Exception => e
        $stderr.puts "#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
        [400, {'Content-Type' => 'text/plain'}, ["#{e.class}: #{e.message}\n"]]
      end
    end

    def resolve(host: nil, port: nil)
      nameservers = (ENV['NAMESERVERS'] || '').split
      searchlist = (ENV['SEARCHLIST'] || '').split
      resolver = Resolver.new(nameservers: nameservers, searchlist: searchlist)
      if host.nil? or host !~ /^[0-9.]$/
        if answer = resolver.resolve(host)
          {host: answer.address, port: (port or answer.port)}
        else
          raise "can't resolve #{host}"
        end
      else
        {host: host, port: port}
      end
    end
end

Rack::Handler::WEBrick.run(RedisDictatorRackApp.new, :Port => 8080)
