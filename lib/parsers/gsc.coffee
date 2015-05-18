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
pageCodes = [
  'a'
  'b'
  'c'
  'd'
  'e'
  'f'
  'g'
  'h'
  'i'
  'jk'
  'l'
  'm'
  'n'
  'o'
  'p'
  'q'
  'r'
  's'
  't'
  'u'
  'v'
  'wx'
  'y'
  'z'
]

pageQueue = queues.create
  totalRequests: pageCodes.length
  loadFactor: 4
  delay: 250

componentQueue = queues.create
  loadFactor: 20
  delay: 500

fetchPage = (code) ->
  fetched = p.defer()

  pageQueue.queue ->
    request "#{baseUri}/flonly-#{code}.htm"
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

fetchDetails = (component, componentCount) ->
  fetched = p.defer()

  componentQueue.totalRequests = componentCount
  componentQueue.queue ->
    request "#{baseUri}/data/#{component.id}.html"
    .then (doc) ->
      $ = cheerio.load doc
      console.log "parsing details for #{component.name}"

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
        data: data

      # todo: look up flavors if a demo link is provided
      #demoUri = $('.demstrafrm').find('a').attr('href')

      fetched.resolve merge(component, details)
    .catch (err) -> fetched.reject err

  fetched.promise

module.exports = parsers.create
  name: 'gsc'
  processes: [
    ->
      promises = []
      promises.push(fetchPage(pageCode)) for pageCode in pageCodes

      p.all promises
    , (pages) ->
      # merge pages back into a single array
      components = []
      components = components.concat.apply components, pages

      console.log "found #{components.length} components in total"

      promises = []
      promises.push(fetchDetails(component, components.length)) for component in components

      p.allSettled promises
      .then (results) ->
        # cull any failed promises
        results
          .filter (v) -> v.state is 'fulfilled'
          .map (v) -> v.value
  ]