fs = require 'fs'
p = require 'p-promise'
merge = require 'merge'
delayed = require 'delayed'
cheerio = require 'cheerio'
Qty = require 'js-quantities'
request = require 'request-promise'

parsers = require '../parser'

readFile = p.denodeify fs.readFile

volumeUnit = 'ml'
baseUri = 'http://shop.perfumersapprentice.com'
detailListUri = "#{baseUri}/specsheetlist.aspx"
componentListUri = (flavor) -> "#{baseUri}/componentlist.aspx?sku_search=#{flavor.sku}"

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

sanitizeFlavorName = (name) -> name.replace(/\s+\*+$/, '').trim()
sanitizeComponentName = (name) ->
  name.split(/\s+/).reduce (prev, cur) ->
    "#{prev} #{cur.substr(0, 1).toUpperCase()}#{cur.substr(1).toLowerCase()}"
  , "" # initial value is an empty string to process first value correctly

# get a normal distribution of randomness for our delay
gaussianRandom = ->
  rand = Math.random
  Math.abs((rand() + rand() + rand() + rand() + rand() + rand() - 3) / 3)

readProductList = (doc) ->
  $ = cheerio.load doc

  mapProducts = (i, v) ->
    elem = $(v)
    # todo: filter this to remove empty entries
    options = elem.find('.variants li a')

    # return an object representing the product info
    id: elem.find('a[name]').attr('name')
    vendor: 'tfa'
    name: sanitizeFlavorName $(v).find('h4 a').text()
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
      parsedPrice = rawPrice.replace /[a-z\(\)\s\$\,]/gi, ''
      continue unless parsedPrice.indexOf('.') > -1 and parseFloat(parsedPrice)
      price = parseFloat(parsedPrice)
      break if price isnt null

    # return an object with pertinent pricing properties
    volume: volume.to(volumeUnit).scalar.toFixed(4)
    price: price?.toFixed(2)
    unitPrice: if price? then (price / volume.to(volumeUnit).scalar).toFixed(4) else null

  # return array of flavor objects
  $('.productBlock').map(mapProducts).get()

# query the MSDS/spec sheet page and look up extra information
lookupSpecs = (pages) ->
  deferred = p.defer()

  # join the flavor pages together
  flavors = []
  flavors = flavors.concat.apply flavors, pages

  console.log "parsing details for #{flavors.length} flavors"

  request detailListUri
  .then (doc) ->
    $ = cheerio.load doc

    # extract product specific metadata from the cells in each row
    mapDetails = (i, v) ->
      cells = $(v).find('td')

      # return an object with mapped information from this page
      name: sanitizeFlavorName $(cells.get(0)).text()
      msdsUri: baseUri + $(cells.get(2)).find('a').attr('href')
      sku: $(cells.get(3)).find('a').attr('href').replace(/.*?=([0-9]+)/, '$1') # assumes sku is the last qs parameter

    # the product table doesn't have an id attribute, so we have to use this somewhat brittle fallback
    # also need to skip the header row, not in a <thead> so we have to hope it's always first
    rows = $('.content table').last().find('tr').not(':first-child')
    details = rows.map(mapDetails).get()

    # resolve promise by joining flavor and detail arrays together
    # because the spec list page does not have page IDs,
    # we have to use a nested loop to match things up by name
    result = flavors.map (flavor) ->
      for detail in details
        continue unless flavor.name is detail.name
        return merge flavor, detail
      flavor

    deferred.resolve result
  .catch (err) -> deferred.reject err

  deferred.promise

# query the product specific component list
lookupDetails = (flavor) ->
  deferred = p.defer()

  delayed.delay ->
    request componentListUri(flavor)
    .then (doc) ->
      $ = cheerio.load doc

      mapComponents = (i, v) ->
        cells = $(v).find('td')

        # return an object with mapped information from this page
        name: sanitizeComponentName $(cells.get(0)).text().trim()
        casNumber: $(cells.get(1)).text().trim()
        percentage: $(cells.get(2)).text().trim()
        description: $(cells.get(3)).text().trim()

      rows = $('#ctl00_PageContent_componentList').find('table').find('tr').not(':first-child')
      components = rows.map(mapComponents).get()

      console.log "parsed #{components.length} components for #{flavor.name}"

      deferred.resolve merge flavor, {components: components}
    .catch (err) -> deferred.reject err
  , (gaussianRandom() * 20000) + 250 # fuzzy random delay

  deferred.promise

module.exports = parsers.create
  getFlavors: ->
    # one promise per page of products
    files = ['./bulk1.html', './bulk2.html', './bulk3.html']
    promises = []
    promises.push(readFile(file).then(readProductList)) for file in files

    # return promise to parse each document and then look up product details
    p.all(promises).then(lookupSpecs)
  getDetails: (flavors) ->
    # one promise per flavor
    promises = []
    promises.push(lookupDetails(flavor)) for flavor in flavors

    # return promise to fetch components for each flavor
    p.all(promises)
