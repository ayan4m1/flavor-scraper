#!/usr/bin/env coffee

fs = require 'fs'
p = require 'p-promise'
json = require 'jsonfile'
cheerio = require 'cheerio'
Qty = require 'js-quantities'

readFile = p.denodeify fs.readFile
writeFile = p.denodeify json.writeFile

currencyUnit = '$'
volumeUnit = 'ml'

unitTransforms = [
  regex: /^double case \(8\) 2 week lead time$/
  result: '8gal'
,
  regex: /^([0-9]+)\s*oz$/
  result: '$1floz'
,
  regex: /^case \(4\) 2week lead time$/
  result: '4gal'
,
  regex: /5 gallon pail/
  result: '5gal'
,
  regex: /Box of 140/
  result: '2100ml'
,
  regex: /half kilo/
  result: '.5kg'
,
  regex: /gallon/
  result: '1gal'
,
  regex: /1 kilo/
  result: '1kg'
,
  regex: /drum/
  result: '55gal'
,
  regex: /box/
  result: '576ml'
]

outputData = (flavors) ->
  writeFile('result.json',
    volumeUnit: volumeUnit
    currencyUnit: currencyUnit
    flavors: flavors
  )

parseDocument = (doc) ->
  $ = cheerio.load doc

  mapProducts = (i, v) ->
    elem = $(v)
    # todo: filter this to remove empty entries
    options = elem.find('.variants li a')

    id: elem.find('a[name]').attr('name')
    name: $(v).find('h4 a').text().replace(/\s+\*+$/, '')
    prices: options.map(mapPrices).get()

  mapPrices = (i, v) ->
    # tokenize raw quantity descriptor
    text = $(v).text().split(' - ')

    # skip non-volume units
    rawVolume = text[0].trim()
    return if rawVolume is 'discontinued' or rawVolume.search(/net wt/) isnt -1

    # handle the ugly exceptions in the units provided...
    for transform in unitTransforms
      continue if rawVolume.search(transform.regex) is -1

      # matched, so apply the transformation

      rawVolume = rawVolume.replace transform.regex, transform.result
      break

    # ensure we have a volume
    volume = Qty.parse(rawVolume)
    throw new Error("#{$(v).parent().parent().parent().find('h4 a').text()} - #{rawVolume}") unless volume?
    return unless volume?.kind() is 'volume'

    # search through remaining tokens for a potential USD price
    price = null
    for rawPrice in text.slice(1)
      parsedPrice = rawPrice.replace /[a-z\(\)\s\$]/gi, ''
      continue unless parsedPrice.indexOf('.') > -1 and parseFloat(parsedPrice)
      price = parseFloat(parsedPrice)
      break if price isnt null

    # return an object with pertinent pricing properties
    volume: volume.to(volumeUnit).scalar.toFixed(4)
    price: price?.toFixed(2)
    unitPrice: if price? then (price / volume.to(volumeUnit).scalar).toFixed(4) else null

  # return array of flavor objects
  $('.productBlock').map(mapProducts).get()

# create one parse promise for each page of flavor data
promises = []
for file in ['./bulk1.html', './bulk2.html', './bulk3.html']
  promises.push(
    readFile(file)
      .then parseDocument, (err) -> console.error err
  )

# process all flavor data, then output results
p.all(promises)
  .then outputData, (err) -> console.error err
.done()