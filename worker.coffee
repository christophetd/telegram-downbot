http = require 'http'
HTTPStatus = require 'http-status'
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
    # - a url that we know unreachable and we shouldn't yet check
    while not @urls[index]? or (@urls[index].checking is true or @urls[index].down_notified is true and @urls[index].next_check > currentTime)
      index = (index + 1) % nbUrls
      return if index is firstTriedIndex # no url to check

    @lastCheckedIndex = index

    console.log "Checking #{@urls[index].url}"
    timeoutErrorString = config.messages.website_timed_out
      .replace ':timeout', config.checkTimeout

    @urls[index].checking = true
    http.get @urls[index].url, @responseCallback.bind(this, index)
      .on 'error', @unreachable.bind(this, index)
      .setTimeout 1000 * config.checkTimeout, @unreachable.bind(this, index, timeoutErrorString)

  responseCallback: (index, res) ->
    # avoid race conditions
    return if not @urls[index]?

    @urls[index].checking = false

    if res.statusCode >= 400
      reason = config.messages.http_error_code
        .replace ':code', res.statusCode
        .replace ':description', HTTPStatus[res.statusCode]
      @unreachable index, reason

  unreachable: (index, reason) ->
    # avoid race conditions
    return if not @urls[index]?
    @urls[index].checking = false
    text = config.messages.website_down_message
      .replace ":url", @urls[index].url
      .replace ":time", prettySeconds(config.retryInterval)

    if reason?
      text += "\n\nReason: #{reason}"

    @urls[index].msg.reply text
    @urls[index].down_notified = true
    @urls[index].next_check = new Date().getTime() + config.retryInterval*1000


module.exports =
  create: -> new Worker()