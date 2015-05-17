#!/bin/sh
":" //# comment; exec /usr/bin/env coffee --nodejs --max-old-space-size=4096 "$0" "$@"

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
