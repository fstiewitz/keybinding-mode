{Emitter} = require 'atom'

dynamicModes = require './dynamic-modes'
regexModes = require './regex-modes'
serviceModes = require './service-modes'

md5 = require('crypto').createHash('md5')

report = (msg) ->
  atom.notifications?.addError msg
  console.log msg

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
          @modes[mode] =
            inherited: ['!all', contents[mode]]
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
      if (typeof inh) is 'string'
        if @isStatic inh
          m = @getStatic inh
        else
          m = @getDynamic inh
      else if inh instanceof Array
        if @isSpecial inh
          m = @getSpecial inh
        else if @isCombined inh
          m = @getCombined inh
        else
          m = @process inh
      else
        m = inh
      @filter m, source
      @merge @modes[name], m
    return @modes[name]

  getSource: (inh) ->
    name = @getName inh
    @modes[name] = inherited: [inh]
    @resolve name

  isStatic: (inh) ->
    return not /^[+-]/.test inh[0]

  getStatic: (inh) ->
    if (@modes[inh])?
      return @resolve inh
    if (@modes[inh] = serviceModes.getStaticMode inh)?
      return @resolve inh
    report "Assertion: getStatic must work on #{inh}"
    return null

  getDynamic: (inh) ->
    op = inh[0] is '+'
    name = inh.substr(1)
    if (m = serviceModes.getDynamicMode op, name)?
      @modes[inh] = inherited: m
      return @resolve inh
    if (m = dynamicModes.getDynamicMode op, name)?
      @modes[inh] = inherited: m
      return @resolve inh
    if (m = regexModes.getDynamicMode op, name)?
      @modes[inh] = inherited: m
      return @resolve inh
    report "Assertion: getDynamic must work on #{inh}"
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
    md5.update(JSON.stringify(name))
    md5.digest('hex')

  merge: (dest, source) ->
    return dest.keymap if source is '!all'
    return dest if source is null
    _.deepExtend dest.keymap, source.keymap
    return unless dest? and source?
    if dest.execute and source?.execute
      dest.execute = ((x, y) -> (r) -> x r; y r)(dest.execute, source.execute)
    else if source?.execute
      dest.execute = source.execute

  filter: (dest, source) ->
    return dest if source is '!all'
    dest.keymap = _.pick dest.keymap, (v, k) ->
      return false unless source.keymap[k]?
      dest.keymap[k] = _.pick dest.keymap[k], (v, k2) ->
        return false unless source.keymap[k][k2]?
        return true
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
      return [a, '+', b]

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
