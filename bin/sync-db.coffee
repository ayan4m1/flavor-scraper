#!/usr/bin/env coffee

fs = require 'fs'
path = require 'path'
p = require 'p-promise'

# load config based on environment
config = require('konfig')()

# establish database connection
db = require 'pg-redis'
db.init config.db

# load local libraries
requireLib = (module) -> require(path.join(path.dirname(fs.realpathSync(__filename)), '../lib', module))

# initialize sync module with db object
sync = requireLib('sync')(db)

# prepare a parser for each vendor
db.query('select * from vendor where perform_sync = true').then (results) ->
  return unless results.length > 0

  for vendor in results
    # try to load the parser module
    try
      parser = require "../lib/parsers/#{vendor.code}"
    catch err
      console.log "skipped vendor #{vendor.name} due to parser load exception"
      console.error err
      continue

    # build the promise chain to invoke parser and sync results
    parser.getFlavors()
      .then parser.getDetails
      .then sync.sync
    .done()