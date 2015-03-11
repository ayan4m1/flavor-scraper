#!/usr/bin/env coffee

fs = require 'fs'
p = require 'p-promise'
cheerio = require 'cheerio'

readFile = p.denodeify fs.readFile
writeFile = p.denodeify fs.writeFile

outputData = (data) ->
  writeFile('result.json', JSON.stringify data)

parseDocument = (doc) ->
  $ = cheerio.load doc

  $('.productBlock').map (i, v) ->
    elem = $(v)

    id: elem.find('a[name]').attr('name')
    name: $(v).find('h4 a').text()
    prices: elem.find('.variants li a').map (i, v) ->
      text = $(v).text().split(' - ')

      volume: text[0]
      price: text[1]
    .get()
  .get()

promises = []
for file in ['./bulk1.html', './bulk2.html', './bulk3.html']
  promises.push(
    readFile(file)
      .then parseDocument, (err) -> console.error err
  )

console.log promises
p.all(promises)
  .then outputData, (err) -> console.error err
.done()