# redis-dictator

Takes a redis master/slave topology as the JSON body of an HTTP PUT, and applies that topology to the given redis instances.

It works with NATted and/or containerized redis instances, because it does not read slave addresses from the master. This
was a shortcoming in redis-sentinel at the time of writing.

It does not monitor the topology and does not implement automatic fail-over. It simply applies the intended topology.
A consumer of this service could use it to apply a new topology as part of automatic fail-over.

The algorithm is as follows:

* On any instance that must become a slave but is currently SLAVEOF NO ONE:
  * Configure the instance to deny writes.
  * Wait for the instance's current slaves to reach its replication offset.
* Make the instance that must become master SLAVEOF NO ONE.
* Make every instance that must become a slave SLAVEOF the new master.
* Wait for every slave to see pub/sub messages written to the new master.
* Configure slaves to allow writes again (should they later be made SLAVEOF NO ONE).

## Usage

`rack-app.rb` takes no arguments or configuration. It listens for HTTP PUT to `/master`. It expects the body of the request
to be a json representation of the desired redis topology (see example below).

## Example

```
ruby rack-app.rb &

cat > topology.json <<EOF
{
  "master": {
    "address": "10.0.0.2",
    "port": 6379
  },
  "slaves": [
    {
      "address": "10.0.0.3",
      "port": 6379
    },
    {
      "address": "10.0.0.4",
      "port": 6379
    }
  ]
}
EOF

curl -XPUT -d @topology.json http://127.0.0.1:8080/master
```
