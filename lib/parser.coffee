delayed = require 'delayed'

class Parser
  constructor: (options) -> {
    # name of module for tagging output and logging
    @name
    # this function is used to iterate over pages of products
    @getFlavors
    # this function is used to make one-off requests for each product
    @getDetails
  } = options

module.exports =
  fuzzyDelay: (min, max, requests = 1, cb) ->
    quant = (max - min) / requests
    scalar = Math.ceil(max / quant)
    delay = (Math.random() *  scalar * quant) + min

    console.log "will execute a delayed task after #{delay}ms"
    delayed.delay cb, delay
  # remove special characters and the word "flavor" from all flavor names, and try to clean up whitespace
  stripSpecials: (name) -> name.replace(/[*-]+|Flavor/g, '').replace(/\s+/g, ' ').trim()
  properCase: (name) ->
    name.split(/\s+/).reduce (prev, cur) ->
      "#{prev} #{cur.substr(0, 1).toUpperCase()}#{cur.substr(1).toLowerCase()}"
    , "" # initial value is an empty string to process first value correctly
  create: (options) -> new Parser options