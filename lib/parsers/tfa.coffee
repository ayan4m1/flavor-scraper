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

parseDocument = (doc) ->
  $ = cheerio.load doc

  mapProducts = (i, v) ->
    elem = $(v)
    # todo: filter this to remove empty entries
    options = elem.find('.variants li a')

    # return an object representing the product info
    id: elem.find('a[name]').attr('name')
    supplier: 'TFA'
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

# query the MSDS/spec sheet page and look up extra information
lookupSpecs = (pages) ->
  deferred = p.defer()

  # join the flavor pages together
  flavors = []
  flavors = flavors.concat.apply flavors, pages

  console.log "looking up specs for #{flavors.length} tfa flavors"

  request detailListUri
  .then (doc) ->
    $ = cheerio.load doc

    mapDetails = (i, v) ->
      cells = $(v).find('td')

      # return an object with mapped information from this page
      name: sanitizeFlavorName $(cells.get(0)).text()
      msdsUri: baseUri + $(cells.get(2)).find('a').attr('href')
      sku: $(cells.get(3)).find('a').attr('href').replace(/.*?=([0-9]+)/, '$1') # assumes sku is the last qs parameter

    # the product table doesn't have an id attribute, so we have to use this somewhat brittle fallback
    # also need to skip the header row, not in a <thead> so we have to hope it's always first
    rows = $('.content table').last().find('tr').not(':first-child')

    # map product details into an object array
    details = rows.map(mapDetails).get()

    # add details information to existing flavor object
    # because the spec list page does not have IDs, we have to do a name comparison
    result = {}
    for flavor in flavors
      hash = "#{flavor.supplier.toLowerCase()}-#{flavor.id}"
      for detail in details
        continue unless flavor.name is detail.name
        console.log "added tfa flavor #{hash} - #{flavor.name}"
        result[hash] = merge flavor, detail

    deferred.resolve result
  .catch (err) -> deferred.reject err

  deferred.promise

lookupDetails = (flavor) ->
  deferred = p.defer()

  delayed.delay ->
    request componentListUri(flavor)
    .then (doc) ->
      $ = cheerio.load doc

      mapComponents = (i, v) ->
        cells = $(v).find('td')

        # return an object with mapped information from this page
        name: $(cells.get(0)).text().trim()
        casNumber: $(cells.get(1)).text().trim()
        percentage: $(cells.get(2)).text().trim()
        description: $(cells.get(3)).text().trim()

      console.log "parsing components for #{flavor.name}"

      rows = $('#ctl00_PageContent_componentList > table').find('tr').not(':first-child')
      components = rows.map(mapComponents).get()

      console.log "found #{components.length} components"

      deferred.resolve merge flavor, {components: components}
    .catch (err) -> deferred.reject err
  , (Math.random() * 20000) + 250 # fuzzy random delay

  deferred.promise

module.exports = parsers.create
  name: 'tfa'
  getFlavors: ->
    # one promise per page of products
    files = ['./bulk1.html', './bulk2.html', './bulk3.html']
    promises = []
    for file in files
      promises.push readFile(file).then(parseDocument, (err) -> console.error err)

    # return promise to parse each document and then look up product details
    p.all(promises).then lookupSpecs, (err) -> console.error err
  getDetails: (flavors) ->
    # one promise per flavor
    promises = []
    for hash, flavor of flavors
      promises.push lookupDetails(flavor)

    # return promise to fetch components for each flavor
    p.all(promises)
