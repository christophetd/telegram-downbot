http = require 'http'
config = require './config'
prettySeconds = require 'pretty-seconds'

class Worker
  constructor: ->
    @urls = []
    @lastCheckedIndex = -1
    setInterval @checkOne, config.checkInterval * 1000

  monitor: (url, msgObject) ->
    #todo handle multiple persons watching on one url
    data =
      url: url
      msg: msgObject

    holeFound = false

    for index, value of @urls
      if not value?
        @urls[index] = data
        holeFound = true

    @urls.push data if not holeFound

  unmonitor: (url) ->
    for index, value of @urls
      if value.url is url
        delete @urls[index] # we don't want to shift indexes
        return true

    return false

  checkOne: =>
    nbUrls = @urls.length
    return if nbUrls is 0

    firstTriedIndex = index = (@lastCheckedIndex + 1) % nbUrls
    currentTime =  new Date().getTime()

    # get next url to monitor as long as we have
    # - a hole in our array
    # - a url that we now unreachable and we shouldn't yet check
    while not @urls[index]? or (@urls[index].checking is true or @urls[index].down_notified is true and @urls[index].next_check > currentTime)
      index = (index + 1) % nbUrls
      return if index is firstTriedIndex # no url to check

    @lastCheckedIndex = index

    console.log "Checking #{@urls[index].url}"
    @urls[index].checking = true
    http.get @urls[index].url, @responseCallback.bind(this, index)
      .on 'error', @unreachable.bind(this, index)

  responseCallback: (index, res) ->
    # avoid race conditions
    return if not @urls[index]?

    @urls[index].checking = false
    @unreachable index if res.statusCode >= 400

  unreachable: (index) ->
    # avoid race conditions
    return if not @urls[index]?
    @urls[index].checking = false
    text = config.messages.website_down_message
      .replace ":url", @urls[index].url
      .replace ":time", prettySeconds(config.retryInterval)
    @urls[index].msg.reply text
    @urls[index].down_notified = true
    @urls[index].next_check = new Date().getTime() + config.retryInterval*1000


module.exports =
  create: -> new Worker()