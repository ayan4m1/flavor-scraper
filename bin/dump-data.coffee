#!/bin/sh
":" //# comment; exec /usr/bin/env coffee --nodejs --max-old-space-size=4096 "$0" "$@"

p = require 'p-promise'
json = require 'jsonfile'

parsers = require '../lib/parser'

# register parsers
parserList = [
  parsers.loadByName 'gsc'
  #parsers.loadByName 'tfa'
]

# invoke the parsers
for parser in parserList
  parser.process()
  .then (data) ->
    p.denodeify(json.writeFile)("#{parser.name}-result.json", data)
  .done()
