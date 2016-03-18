{Disposable} = require 'atom'

report = (msg) ->
  atom.notifications?.addError msg
  console.log msg

module.exports =

  activate: ->
    @smodes = {}
    @dmodes = {}
    @consumed = {}

  deactivate: ->
    @remove name for name in Object.keys(@consumed)
    @smodes = null
    @dmodes = null
    @consumed = null

  remove: (name) ->
    return unless @consumed[name]?
    @smodes[mode] = null for mode in @consumed[name].smodes
    @dmodes[mode] = null for mode in @consumed[name].dmodes
    delete @consumed[name]

  consume: ({name, modes}) ->
    unless name?
      report 'Service did not provide name'
      return
    unless modes?
      report 'Service did not provide any keybinding modes'
      return
    unless (typeof modes) is 'object'
      report "Service's modes is not an object"
      return
    if @consumed[name]?
      report "Service #{name} already exists"
      return
    r =
      smodes: []
      dmodes: []
    for key in Object.keys(modes)
      if (typeof modes[key]) is 'object'
        if @smodes[key]? or @dmodes[key]?
          report "Mode #{key} already exists"
          continue
        @smodes[key] = modes[key]
        r.smodes.push key
      else if (typeof modes[key]) is 'function'
        if @smodes[key]? or @dmodes[key]?
          report "Mode #{key} already exists"
          continue
        @dmodes[key] = modes[key]
        r.dmodes.push key
      else
        report "#{key} of unsupported type: #{typeof modes[key]}"
        return
    @consumed[name] = r
    new Disposable(=> @remove(name))

  getStaticMode: (name, sobj) ->
    sobj.is_static = true
    return @smodes[name] if @smodes[name]?

  getStaticNames: ->
    return Object.keys(@smodes)

  getDynamicMode: (name, sobj) ->
    _name = name.substr(1)
    return @dmodes[_name](name[0] is '+', sobj) if @dmodes[_name]?

  isStaticMode: (name) ->
    return @smodes[name]?

  isValidMode: (name) ->
    if /^(\+|\-)/.test name
      return @dmodes[name.substr(1)]?
    else
      return @smodes[name]?
