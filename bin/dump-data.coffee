#!/usr/bin/env coffee
p = require 'p-promise'
json = require 'jsonfile'

writeJsonFile = p.denodeify(json.writeFile)
parserWithName = (name) -> "../lib/parsers/#{name}"

# register parsers
parsers = [
  require parserWithName('gsc')
  #require parserWithName('tfa')
]

# invoke the parsers
for parser in parsers
  parser.getFlavors()
    .then (flavors) -> parser.getDetails flavors
    .then (flavors) -> writeJsonFile "#{parser.name}-result.json", flavors
  .done()
