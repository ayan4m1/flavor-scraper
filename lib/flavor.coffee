class Flavor
  constructor: (options) -> {
    @id
    @name
    @vendor
    @sku
    @pricing
    @msdsUri
    @productUri
  } = options

module.exports =
  create: (options) -> new Flavor options