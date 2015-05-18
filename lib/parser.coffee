p = require 'p-promise'
delayed = require 'delayed'

class Parser
  constructor: (options = {}) ->
    {
      @name # slug-style name for the parser
      @processes # array of promise-returning functions
    } = options
    # processes should always be an array
    @processes = @processes ? []

  process: ->
    start = @processes.shift()
    @processes.reduce (prev, cur) ->
      prev.then cur
    , start()

module.exports =
  # remove special characters and the word "flavor" from all flavor names, and try to clean up whitespace
  stripSpecials: (name) -> name.replace(/[*-]+|Flavor/g, '').replace(/\s+/g, ' ').trim()
  properCase: (name) ->
    name.split(/\s+/).reduce (prev, cur) ->
      "#{prev} #{cur.substr(0, 1).toUpperCase()}#{cur.substr(1).toLowerCase()}"
    , "" # initial value is an empty string to process first value correctly
  create: (options) -> new Parser options
  loadByName: (name) -> require "./parsers/#{name}"