#!/usr/bin/env coffee
p = require 'p-promise'
json = require 'jsonfile'

parserDir = '../lib/parsers'

# register parsers
parsers = [
  require "#{parserDir}/tfa"
]

# invoke the parsers
for parser in parsers
  parser.getFlavors()
  .then (flavors) -> parser.getDetails(flavors)
  .then (flavors) -> p.denodeify(json.writeFile)("#{parser.name}-result.json", flavors)
  .done()