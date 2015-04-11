class Flavor
  constructor: (options) -> {
    @id
    @name
    @supplier
    @sku
    @pricing
    @msdsUri
    @productUri
  } = options

flavors = []

module.exports =
  add: (options) ->
    flavor = new Flavor(options)
    flavors.push flavor
    flavor
  get: -> flavors