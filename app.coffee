Telegram = require 'telegram-bot'
_ = require 'underscore'
logic = require './logic'

if not process.env.TELEGRAM_API_TOKEN?
  console.warn "Please set the API token of the bot using 'export TELEGRAM_API_TOKEN=YOUR_TOKEN'"
  process.exit()

tg = new Telegram(process.env.TELEGRAM_API_TOKEN)

tg.on 'message', (msg) ->
  msg.reply = (options) ->
    if typeof options isnt 'object'
      options = {text: options}

    tg.sendMessage _.defaults options,
      chat_id: @chat.id
      reply_markup:
        hide_keyboard: true

  msg.from.getName = -> @first_name.split(" ")[0]

  logic.handleMessage msg

tg.start()