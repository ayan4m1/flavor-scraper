# Flavor Scraper

This script extracts price information using a set of modular parsers for flavor supplier data.

## Dependencies

* node.js

## Usage

First, install node modules by running:

> npm install

Out of an abundance of caution, the script intentionally does not fetch the required TFA data for you.
You must be logged in with a wholesale-enabled account to get the the bulk pricing.

Save each of the three bulk flavor pages to bulk1.html, bulk2.html, and bulk3.html. Not elegant but it works.

Now run:

> ./bin/parse-data.coffee

A JSON object with detailed pricing information will be written to a file called result.json in the current working directory.