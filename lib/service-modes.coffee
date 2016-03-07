module.exports =

  activate: ->
    @smodes = {}
    @dmodes = {}

  deactivate: ->
    @smodes = null
    @dmodes = null

  consume: (input) ->

  getStaticMode: (name) ->
    return @smodes[name] if @smodes[name]?

  getDynamicMode: (name) ->
    _name = name.substr(1)
    return @dmodes[_name] if @dmodes[_name]?

  isStaticMode: (name) ->
    return @smodes[name]?

  isValidMode: (name) ->
    if /^(\+|\-)/.test name
      return @dmodes[name.substr(1)]?
    else
      return @smodes[name]?
