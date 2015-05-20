fs = require 'fs'
p = require 'p-promise'
merge = require 'merge'
cheerio = require 'cheerio'
Qty = require 'js-quantities'
request = require 'request-promise'

parsers = require '../parser'
queues = require '../queue'

# todo: do this inline
# one-liner to get pages:
# $('#ui-accordion-accordion-panel-4').find('.ui-tabs-nav').find('li').find('a')
# .each(function(i, v) { console.log($(v).attr('href')) });

baseUri = 'http://www.thegoodscentscompany.com'

pageQueue = queues.create
  loadFactor: 4
  delay: 250

ingredientQueue = queues.create
  loadFactor: 20
  delay: 500

fetchPage = (uri) ->
  fetched = p.defer()

  pageQueue.queue ->
    request uri
    .then (doc) ->
      $ = cheerio.load doc

      mapComponents = (i, v) ->
        # ensure we are on a name row (they use two rows per component... thanks for that)
        cells = $($(v).find('td')).get(1)
        return unless cells?
        anchor = $(cells).find('a')
        return unless anchor.attr('onclick')?

        # not pretty...
        idRegex = /openMainWindow\('http:\/\/www\.thegoodscentscompany\.com\/data\/([a-zA-Z0-9]+)\.html'\);return false;/
        idScrape = anchor.attr('onclick').match(idRegex)
        return unless idScrape[1]?

        id: idScrape[1]
        name: anchor.text().trim()

      # parse all components on page
      components = $('table tbody tr').map(mapComponents).get()
      console.log "parsed #{components.length} components"
      fetched.resolve components
    .catch (err) -> fetched.reject err

  fetched.promise

fetchDetails = (ingredient, ingredientCount) ->
  fetched = p.defer()

  ingredientQueue.totalRequests = ingredientCount
  ingredientQueue.queue ->
    request "#{baseUri}/data/#{ingredient.id}.html"
    .then (doc) ->
      $ = cheerio.load doc
      console.log "parsing details for #{ingredient.name}"

      # try and parse the label for this row into a hashable key
      data = {}
      dataKey = (label) ->
        label.toLowerCase().trim().replace(/[^\w\d\s-]/g, '').trim().replace(/[\s_]/g, '-')

      # enumerate each data row
      $('#chemdata').find('tr').each (i, v) ->
        cells = $(v).find('td')
        return unless cells.length is 2
        key = dataKey($(cells.get(0)).text())
        value = $(cells.get(1)).text().trim()
        # todo: make this a real exclusion list, for now this is ok
        return if value is 'Predict' or value is 'Search'
        data[key] = value

      mapSynonyms = (i, v) -> $(v).text().trim()
      details =
        name: $('td.prodname').text().trim()
        notes: $('.fotq').text().trim()
        synonyms: $('#rhtable tr[itemscope]').map(mapSynonyms).get()
        demoUri: $('.demstrafrm').find('a').attr('href').trim()
        data: data

      fetched.resolve merge(ingredient, details)
    .catch (err) -> fetched.reject err

  fetched.promise

module.exports = parsers.create
  name: 'gsc'
  processes: [
    -> # fetch the list of flavor ingredient pages to query
      fetched = p.defer()

      request baseUri
      .then (doc) ->
        $ = cheerio.load doc

        mapHrefs = (i, v) ->
          # todo: cleaner way of skipping the 'href="#"'
          href = $(v).attr('href').trim().replace('#', '')
          if href is '' then null else href

        # tab index 15 is "flonly-" or Flavor Ingredients
        fetched.resolve $($('div.tabs').get(15)).find('li').find('a').map(mapHrefs).get()
        #fetched.resolve ['http://www.thegoodscentscompany.com/flonly-d.htm']
      .catch (err) ->
        console.error err
        fetched.reject err

      fetched.promise
    , (uris) -> # create a promise to fetch each page of ingredients
      pageQueue.totalRequests = uris.length

      promises = []
      promises.push(fetchPage(uri)) for uri in uris

      p.allSettled promises
      .then (results) ->
        # cull any broken promises
        results
          .filter (v) -> v.state is 'fulfilled'
          .map (v) -> v.value
    , (pages) -> # create a promise to fetch details for each ingredient
      # first, merge pages of ingredients back into a single array
      ingredients = []
      ingredients = ingredients.concat.apply ingredients, pages

      console.log "found #{ingredients.length} ingredients in total"

      promises = []
      promises.push(fetchDetails(ingredient, ingredients.length)) for ingredient in ingredients

      p.allSettled promises
      .then (results) ->
        # cull any broken promises
        results
          .filter (v) -> v.state is 'fulfilled'
          .map (v) -> v.value
  ]