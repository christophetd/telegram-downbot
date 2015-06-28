fs = require 'fs'

config =
  # (in seconds)
  checkInterval: 1

  # (in seconds)
  retryInterval: 10

config.messages = JSON.parse(fs.readFileSync './messages.json', 'utf8')
module.exports = config