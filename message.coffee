exports = exports ? this

class Message
  # TODO: Add error handling
  @parse: (msg) ->
    msg = JSON.parse(msg)
    new Message msg.type, msg.data
  constructor: (@type, @data='') ->
  stringify: -> JSON.stringify(this)

exports.WebPongJSMessage = Message
