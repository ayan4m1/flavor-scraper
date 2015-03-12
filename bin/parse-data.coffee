#!/usr/bin/env coffee

fs = require 'fs'
p = require 'p-promise'
json = require 'jsonfile'
cheerio = require 'cheerio'
Qty = require 'js-quantities'

readFile = p.denodeify fs.readFile
writeFile = p.denodeify json.writeFile

outputData = (data) ->
  writeFile('result.json', data)

parseDocument = (doc) ->
  $ = cheerio.load doc

  $('.productBlock').map (i, v) ->
    elem = $(v)

    id: elem.find('a[name]').attr('name')
    name: $(v).find('h4 a').text()
    prices: elem.find('.variants li a').map (i, v) ->
      text = $(v).text().split(' - ')
      volumeQty = Qty.parse(text[0].replace(/oz/, ' floz'))
      price = null
      for rawPrice in text.slice(1)
        break if price isnt null
        parsedPrice = rawPrice.replace /[a-zA-Z\(\)\s\$]/g, ''
        continue unless parsedPrice.indexOf('.') > -1 and parseFloat(parsedPrice)
        price = parsedPrice

      volume: if volumeQty is null then text[0] else volumeQty.to('l').toPrec('1 floz').toString()
      price: price
    .get()
  .get()

promises = []
for file in ['./bulk1.html', './bulk2.html', './bulk3.html']
  promises.push(
    readFile(file)
      .then parseDocument, (err) -> console.error err
  )

p.all(promises)
  .then outputData, (err) -> console.error err
.done()