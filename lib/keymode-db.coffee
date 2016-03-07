{Emitter} = require 'atom'

dynamicModes = require './dynamic-modes'
regexModes = require './regex-modes'
serviceModes = require './service-modes'

module.exports =
  all: {} # Dummy for "all keybindings"
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
        @modes = contents
        @mode_subscription?.dispose()
        command_map = {}
        for mode in Object.keys @modes
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
    mode = @resolve(name)
    return unless mode?
    mode.execute true
    @emitter.emit 'deactivate', name

  activateKeymap: (name) ->
    @current_keymap = name
    mode = @resolve(name)
    return unless mode?
    mode.execute()
    @key_subscription = atom.keymaps.add 'keybinding-mode:' + name, mode._keymap
    @emitter.emit 'activate', name

  resolve: (name) ->
    return @modes[name] if @modes[name]?.resolved
    return unless @dryRun name
    return @_resolve name, @modes[name], @all

  _resolve: (name, mode, source) ->
    return unless mode?
    return mode._keymap if mode.resolved

    inherited = mode.inherited.slice()
    unless name?
      source = @sourceFromElement inherited.shift(), source

    strictly_static = true

    for inh in inherited
      if (typeof inh) is 'string'
        if @isStaticMode inh
          _mode = @getStaticMode inh, source
        else
          _mode = @getDynamicMode inh, source
          strictly_static = false
      else
        _mode = @_resolve null, inh, source
      @filter _mode, source
      @merge mode._keymap, _mode._keymap
      mode.execute = ((x, y) -> (r) -> x r; y r)(mode.execute, _mode.execute)

    @merge mode._keymap, mode.keymap
    mode.execute = ((x, y) -> (r) -> x r; y r)(inh_execute, mode.execute)
    mode.resolved = true if strictly_static
    return mode

  sourceFromElement: (el, source) ->
    if (typeof el) is 'string'
      if @isStaticMode el
        _mode = @getStaticMode el, source
      else
        _mode = @getDynamicMode el, source
    else
      _mode = @_resolve null, el, source
    @filter _mode, source
    return _mode

  getDynamicMode: (name, source) ->
    if (m = serviceModes.getDynamicMode name)? or (m = dynamicModes.getDynamicMode name)? or (m = regexModes.getDynamicMode name)?
      return @_resolve name, m, source
    return null

  getStaticMode: (name, source) ->
    if (m = @modes[name])? or (m = serviceModes.getStaticMode name)?
      return @_resolve name, m, source
    return null

  isStaticMode: (name) ->
    return true if @modes[name]?
    return true if serviceModes.isStaticMode name
    return false

  merge: (dest, source) ->
    _.deepExtend dest, source

  filter: (dest, source) ->
    return dest if source is @all
    dest._keymap = _.pick dest._keymap, (v, k) ->
      return false unless source[k]?
      dest._keymap[k] = _.pick dest._keymap[k], (v, k2) ->
        return false unless source[k][k2]?
        return true
      return true

  dryRun: (name) ->
    mode = @modes[name]
    return true if mode?._keymap?
    if mode.inherited
      if (typeof mode.inherited) isnt 'object'
        atom.notifications?.addError "Unknown type of inherited array: #{typeof mode.inherited}"
        return false
      return @dryRunInh mode.inherited
    return true

  dryRunInh: (inherited, first = 1) ->
    for inh, index in inherited
      if (typeof inh) is 'string'
        return false unless @validMode inh
      else if (typeof inh) is 'object'
        if (inh.length + first) is 0
          atom.notifications?.addError "Empty array in #{inherited.toString()} at #{index}"
          return false
        else if (inh.length + first) is 1
          atom.notifications?.addWarning "One-element-array in #{inherited.toString()} at #{index}"
          return false
        return false unless @dryRunInh inh, 0
      else
        atom.notifications?.addError "Unknown type in #{inherited.toString()} at #{index}: #{typeof inh}"
        return false
    return true

  validMode: (name) ->
    return true if @modes[name]?
    return true if serviceModes.validMode name
    return true if dynamicModes.validMode name
    return true if regexModes.validMode name
    return false
