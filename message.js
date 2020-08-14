// Generated by CoffeeScript 1.12.7
(function() {
  var Message, exports;

  exports = exports != null ? exports : this;

  Message = (function() {
    Message.parse = function(msg) {
      msg = JSON.parse(msg);
      return new Message(msg.type, msg.data);
    };

    function Message(type, data) {
      this.type = type;
      this.data = data != null ? data : '';
    }

    Message.prototype.stringify = function() {
      return JSON.stringify(this);
    };

    return Message;

  })();

  exports.WebPongJSMessage = Message;

}).call(this);