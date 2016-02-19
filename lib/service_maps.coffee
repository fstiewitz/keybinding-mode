{Disposable} = require 'atom'

module.exports =
  modes: {}

  registry: {}

  consumeKeybindingMode: (name, modes) ->
    for mode in Object.keys(modes)
      @addKeymode name, mode, modes[mode]
    new Disposable(=>
      for mode in Object.keys(modes)
        @removeKeymode name, mode
    )

  addKeymode: (name, key, mode) ->
    @registry[key] ?= []
    @registry[key].push [name, mode]
    @modes[key] = mode

  removeKeymode: (name, key) ->
    if @registry[key][@registry[key].length - 1][0] is name
      @registry[key].pop()
      @modes[key] = @registry[key][@registry[key].length - 1]?[1]
      return
    new_registry_item = []
    for item in @registry[key]
      if item[0] is name and @registry[key].length is 1
        @registry[key] = []
        @modes[key] = null
      else
        new_registry_item.push item
    @registry[key] = new_registry_item

  resolveStaticKeymap: (name) ->
    return m if (m = @modes[name])? and m instanceof Object
    return null

  resolveDynamicKeymap: (op, name) ->
    return m op if (m = @modes[name])? and m instanceof Function
    return null

  matchesStaticKeymap: (name) ->
    @modes[name]?
