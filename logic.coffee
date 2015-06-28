validUrl = require 'valid-url'
config = require './config'
worker = require('./worker').create()

logic = {}
sessions = {}

logic.confirm = (msg) =>
  if msg.text.toLowerCase() isnt 'yes'
    delete sessions[msg.chat.id].data.url
    sessions[msg.chat.id].next = 'readUrl'
    msg.reply "Aborting."
    msg.reply config.messages.prompt_url
    return

  delete sessions[msg.chat.id].next
  url = sessions[msg.chat.id].data.url
  worker.monitor(url, msg)
  sessions[msg.chat.id].data.monitored_urls.push(url)
  msg.reply config.messages.monitor_successful

logic.readUrl = (msg) =>
  url = String(msg.text).trim()

  if url.indexOf "http://" isnt 0 and url.indexOf "https://" isnt 0
    url = "http://"+url

  if validUrl.isWebUri url
    sessions[msg.chat.id].next = 'confirm'
    sessions[msg.chat.id].data.url = url
    msg.reply
      text: config.messages.confirm.join("\n").replace ":url", url
      reply_markup:
        keyboard: [["Yes"],["No"]]
  else
    msg.reply config.messages.prompt_url
    sessions[msg.chat.id].next = 'readUrl'

logic.unmonitor = (msg) =>
  return logic.unmonitorUrl msg if validUrl.isWebUri msg.text

  monitored_urls = sessions[msg.chat.id].data.monitored_urls
  if monitored_urls.length is 0
    msg.reply config.messages.no_monitored_url
    return

  answers = []
  for i,url of monitored_urls
    answers.push [url]

  msg.reply
    text: config.messages.prompt_unmonitor_url
    reply_markup:
      keyboard: answers

  sessions[msg.chat.id].next = 'unmonitorUrl'

logic.unmonitorUrl = (msg) =>
  url = msg.text
  monitored_urls = sessions[msg.chat.id].data.monitored_urls

  if url not in monitored_urls
    delete sessions[msg.chat.id].next
    msg.reply config.messages.not_monitoring
    return

  logic._unmonitorUrl url, msg
  delete sessions[msg.chat.id].next

logic._unmonitorUrl = (url, msg) =>
  if worker.unmonitor(url) isnt true
    msg.reply config.messages.generic_error
    return

  index = sessions[msg.chat.id].data.monitored_urls.indexOf url
  sessions[msg.chat.id].data.monitored_urls.splice index, 1
  msg.reply config.messages.unmonitor_successful.replace ":url", url

logic.help = (msg) =>
  msg.reply config.messages.help.join "\n"

logic.list = (msg) =>
  monitored_urls = sessions[msg.chat.id].data.monitored_urls

  return msg.reply config.messages.no_monitored_url if monitored_urls.length is 0

  text = config.messages.monitored_urls_list
  for i,url of monitored_urls
    text += "#{1+parseInt(i)}. #{url}\n"

  msg.reply text

logic.rickroll = (msg) =>
  msg.reply config.messages.rickroll

logic.about = (msg) =>
  msg.reply config.messages.about.join "\n"

logic.handleMessage = (msg) =>
  if not sessions[msg.chat.id]?
    sessions[msg.chat.id] = { data: {monitored_urls: []} }

    answers = []
    for label,string of config.messages.welcome_answers
      answers.push [string]

    msg.reply
      text: config.messages.welcome.join("\n").replace ":name", msg.from.getName()
      reply_markup:
        keyboard: answers

  else
    # Either read command from message, or execute next step
    next = sessions[msg.chat.id].next
    if next?
      logic[next] msg
      return

    commands =
      readUrl: ['monitor', config.messages.welcome_answers.monitor.toLowerCase()]
      unmonitor: ['unmonitor']
      help: ['help', config.messages.welcome_answers.help.toLowerCase()]
      list: ['list']
      about: ['about', config.messages.welcome_answers.about.toLowerCase()]
      rickroll: ['lolz']

    loweredMessage = msg.text.toLowerCase()

    for func, triggers of commands
      for trigger in triggers
        if matches = new RegExp("^\/?"+trigger+" ?(.*)").exec(loweredMessage)
          msg.text = matches[1]
          logic[func] msg
          return

    # Command not found
    msg.reply config.messages.command_not_found

module.exports = logic