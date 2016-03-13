{Emitter} = require 'atom'

dynamicModes = require './dynamic-modes'
regexModes = require './regex-modes'
serviceModes = require './service-modes'

crypto = require('crypto')

_ = require('underscore-plus')

report = (msg) ->
  atom.notifications?.addError msg
  console.log msg

pick = (o, f) ->
  r = {}
  for k in Object.keys(o)
    r[k] = o[k] if f(k)
  return r

module.exports =
  modes: {} # Stores keybinding modes
  mode_subscription: null # Stores atom.commands.add bindings
  key_subscription: null # Stores current keybinding subscription
  current_keymap: null # Stores current keymap name
  emitter: null

  activate: ->
    @emitter = new Emitter
    dynamicModes.activate?()
    regexModes.activate()
    serviceModes.activate()

  deactivate: ->
    @modes = {}
    @mode_subscription?.dispose()
    @mode_subscription = null
    @deactivateKeymap @current_keymap if @current_keymap?
    dynamicModes.deactivate?()
    regexModes.deactivate()
    serviceModes.deactivate()
    @emitter.dispose()
    @emitter = null

  onReload: (cb) ->
    @emitter.on 'reload', cb

  onToggle: (cb) ->
    @emitter.on 'toggle', cb

  onDeactivate: (cb) ->
    @emitter.on 'deactivate', cb

  onActivate: (cb) ->
    @emitter.on 'activate', cb

  reload: ->
    filepath = path.join(path.dirname(atom.config.getUserConfigPath()), 'keybinding-mode.cson')
    fs.exists filepath, (exists) =>
      return console.log "#{filepath} does not exist and this package is useless without it" unless exists
      CSON.readFile filepath, (error, contents) =>
        if error?
          atom.notifications?.addError 'Could not read ' + filepath
          return
        @mode_subscription?.dispose()
        command_map = {}
        for mode in Object.keys contents
          if contents[mode] instanceof Array
            contents[mode].splice(0, 0, '!all')
          else
            contents[mode] = ['!all', contents[mode]]
          @modes[mode] =
            inherited: contents[mode]
            resolved: false
            execute: null
            keymap: null
          command_map['keybinding-mode:' + mode] = ((_this, name) -> -> _this.toggleKeymap(name))(this, mode)
        @mode_subscription = atom.commands.add 'atom-workspace', command_map
        @emitter.emit 'reload'

  toggleKeymap: (name) ->
    if name is @current_keymap
      @deactivateKeymap name
    else
      @deactivateKeymap @current_keymap if @current_keymap?
      @activateKeymap name
    @emitter.emit 'toggle', name

  deactivateKeymap: (name) ->
    @current_keymap = null
    @key_subscription?.dispose()
    mode = @resolveWithTest(name)
    return unless mode?
    mode.execute true
    @emitter.emit 'deactivate', name

  activateKeymap: (name) ->
    @current_keymap = name
    mode = @resolveWithTest(name)
    return unless mode?
    mode.execute()
    @key_subscription = atom.keymaps.add 'keybinding-mode:' + name, mode.keymap
    @emitter.emit 'activate', name

  resolveWithTest: (name) ->
    return @modes[name] if @modes[name]?.resolved
    return unless @dryRun name
    return @_resolve name

  resolve: (name) ->
    return @modes[name] if @modes[name]?.resolved
    return @_resolve name

  _resolve: (name) ->
    inh = @modes[name].inherited.slice()
    if inh.length > 1
      source = @getSource inh.shift()
    else
      source = '!all'
    for i in inh
      if (typeof i) is 'string'
        if @isStatic i
          m = @getStatic i
        else
          m = @getDynamic i
      else if i instanceof Array
        if @isSpecial i
          m = @getSpecial i
        else if @isCombined i
          m = @getCombined i
        else
          m = @process i
      else
        m = i
      @filter m, source
      @merge @modes[name], m
    return @modes[name]

  getSource: (inh) ->
    return inh if inh is '!all'
    name = @getName inh
    @modes[name] ?= inherited: [inh]
    @resolve name

  isStatic: (inh) ->
    return not /^[!+-]/.test inh[0]

  getStatic: (inh) ->
    if (@modes[inh])?
      return @resolve inh
    if (@modes[inh] = serviceModes.getStaticMode inh)?
      return @resolve inh
    report "Assertion: getStatic must work on #{inh}"
    return null

  getDynamic: (name) ->
    if serviceModes.isValidMode name
      @modes[name] = inherited: serviceModes.getDynamicMode name
      return @resolve name
    if dynamicModes.isValidMode name
      @modes[name] = inherited: dynamicModes.getDynamicMode name
      return @resolve name
    if regexModes.isValidMode name
      @modes[name] = inherited: regexModes.getDynamicMode name
      return @resolve name
    report "Assertion: getDynamic must work on #{name}"
    return null

  getSpecial: (inh) ->
    name = @getName inh
    if (m = regexModes.getSpecial inh)?
      @modes[name] = inherited: m
      return @resolve name
    report "Assertion: getSpecial must work on #{inh}"
    return null

  getCombined: (inh) ->
    name = @getName inh
    @modes[name] = inherited: @_getCombined(inh.slice())
    @resolve name

  process: (inh) ->
    name = @getName inh
    @modes[name] = inherited: inh
    @resolve name

  getName: (name) ->
    return name if (typeof name) is 'string'
    md5 = crypto.createHash('md5')
    md5.update(JSON.stringify(name), 'utf8')
    md5.digest('hex')

  merge: (dest, source) ->
    return unless dest?
    return unless source?
    return if source is '!all'
    dest.keymap = {} unless dest.keymap?
    if source.keymap?
      for selector in Object.keys(source.keymap)
        if dest.keymap[selector]?
          for key in Object.keys(source.keymap[selector])
            continue if dest.keymap[selector][key]?
            dest.keymap[selector][key] = source.keymap[selector][key]
        else
          dest.keymap[selector] = _.clone source.keymap[selector]
    if dest.execute and source?.execute
      dest.execute = ((x, y) -> (r) -> x r; y r)(dest.execute, source.execute)
    else if source?.execute
      dest.execute = source.execute

  filter: (dest, source) ->
    return if source is '!all'
    dest.keymap = pick dest.keymap, (k) ->
      return false unless source.keymap[k]?
      dest.keymap[k] = pick dest.keymap[k], (k2) ->
        return source.keymap[k][k2]?
      return true

  _getCombined: (inh) ->
    a = inh.shift()
    op = inh.shift()
    b = inh.shift()

    if a instanceof Array and @isCombined a
      a = @_getCombined a
    if b instanceof Array and @isCombined b
      b = @_getCombined b

    if op is '&'
      return [a, b]
    else
      return ['!all', a, b]

  dryRun: (name) ->
    mode = @modes[name]
    return false unless mode?
    return true if mode?.resolved
    return @_dryRun mode.inherited

  _dryRun: (inh) ->
    if (typeof inh) is 'string'
      return @validMode inh
    else if inh instanceof Array
      return @validSpecial inh if @isSpecial inh
      return @validCombined inh if @isCombined inh
      if inh.length is 0
        report 'Empty array not allowed'
        return false
      else if inh.length is 1
        report 'One-element-array not allowed'
        return false
      return false for i in inh when not @_dryRun i
    else
      unless inh.keymap or inh.execute
        report "Object #{inh} does not contain keymap or function"
        return false
    return true

  isCombined: (inh) ->
    for i in inh
      return true if (typeof i) is 'string' and /^[&|]$/.test i
    return false

  isSpecial: (inh) ->
    return (typeof inh[0]) is 'string' and inh[0][0] is '!' and inh[0] isnt '!all'

  validMode: (name) ->
    return true if name is '!all'
    return true if @modes[name]?
    return true if serviceModes.isValidMode name
    return true if dynamicModes.isValidMode name
    return true if regexModes.isValidMode name
    return false

  validSpecial: (inh) ->
    return true if regexModes.isSpecial inh
    report "#{inh} is not a valid special form"
    return false

  validCombined: (inh) ->
    next_is_filter = true
    for i in inh
      if next_is_filter
        return false unless @_dryRun i
      else
        unless (typeof i) is 'string' and /^[&|]$/.test i
          report "#{i} supposed to be operator"
          return false
      next_is_filter = not next_is_filter
    return true
