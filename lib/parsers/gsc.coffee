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
  'aaa'
  'ama'
  'baa'
  'bja'
  'caa'
  'cja'
  'daa'
  'dii'
  'eaa'
  'eua'
  'faa'
  'fda'
  'gaa'
  'gia'
  'haa'
  'hfa'
  'iaa'
  'jk'
  'laa'
  'lfa'
  'maa'
  'met'
  'naa'
  'nja'
  'oaa'
  'oea'
  'paa'
  'pia'
  'qaa'
  'raa'
  'ros'
  'saa'
  'sod'
  'taa'
  'tia'
  'uaa'
  'vaa'
  'vba'
  'wx'
  'yaa'
  'zaa'
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
    request "#{baseUri}/allprd-#{code}.htm"
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
      console.log "got details for #{component.name}"
      $ = cheerio.load doc

      mapSynonyms = (i, v) -> $(v).text().trim()

      rows = $('#chemdata').find('tr')
      details =
        name: $(rows.get(0)).find('a').text().replace(/\(Click\)/g, '').trim()
        casNumber: $(rows.get(1)).find('a').text().replace(/\(Click\)/g, '').trim()
        synonyms: $('#rhtable tr[itemscope]').map(mapSynonyms).get()

      fetched.resolve merge(component, details)
    .catch (err) -> fetched.reject err

  fetched.promise

module.exports = parsers.create
  name: 'gsc'
  getFlavors: ->
    promises = []
    promises.push(fetchPage(pageCode)) for pageCode in pageCodes

    p.all promises
  getDetails: (pages) ->
    # merge pages back into a single array
    components = []
    components = components.concat.apply components, pages

    console.log "found #{components.length} components in total"

    promises = []
    promises.push(fetchDetails(component, components.length)) for component in components

    p.allSettled promises
    .then (results) ->
      # cull any broken promises
      results
        .filter (v) -> v.state is 'fulfilled'
        .map (v) -> v.value