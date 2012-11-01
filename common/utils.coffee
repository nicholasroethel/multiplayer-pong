exports = exports ? this

dictLength = (d) ->
  return Object.keys(d).length

isEmpty = (d) ->
  return dictLength(d) == 0

exports.dictLength = dictLength
exports.isEmpty = isEmpty
