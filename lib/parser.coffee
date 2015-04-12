class Parser
  constructor: (options) -> {
    @getFlavors # this function is used to iterate over pages of products
    @getDetails # this function is used to make one-off requests for each product
  } = options

module.exports =
  create: (options) -> new Parser options