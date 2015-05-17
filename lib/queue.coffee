delayed = require 'delayed'

secondsToMillis = 1000

class Queue
  constructor: (options) -> {
    @totalRequests
    @loadFactor
    @delay
  } = options
  toString: -> "queue info: #{queue.totalRequests} requests, estimating #{queue.runtime()}s runtime"
  runtime: -> (@totalRequests / @loadFactor) * secondsToMillis
  step: -> (@runtime() - @delay) / @totalRequests
  multiplier: -> Math.ceil @runtime() / @step()
  queue: (cb) ->
    # todo: use a normal distribution random source
    thisDelay = (Math.random() * @multiplier() * @step()) + @delay
    delayed.delay cb, thisDelay

module.exports =
  create: (options) -> new Queue options