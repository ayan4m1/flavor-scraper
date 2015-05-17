#!/usr/bin/env coffee
p = require 'p-promise'
json = require 'jsonfile'

parserWithName = (name) -> "../lib/parsers/#{name}"

# register parsers
parsers = [
  require parserWithName('tfa')
]

# invoke the parsers
for parser in parsers
  parser.getFlavors()
  .then (flavors) -> parser.getDetails(flavors)
  .then (flavors) -> p.denodeify(json.writeFile)("#{parser.name}-result.json", flavors)
  .done()
