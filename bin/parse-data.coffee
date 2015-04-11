#!/usr/bin/env coffee

fs = require 'fs'
p = require 'p-promise'
json = require 'jsonfile'

flavors = require '../lib/flavor'

writeFile = p.denodeify json.writeFile

parserDir = '../lib/parsers'
outputFile = 'results.json'

# register parsers
parsers = [
  require "#{parserDir}/tfa"
]

# invoke the parsers
for parser in parsers
  parser.getFlavors()
  .then (flavors) -> parser.getDetails(flavors)
  .then (flavors) -> writeFile "#{parser.name}-result.json", flavors
  .done()