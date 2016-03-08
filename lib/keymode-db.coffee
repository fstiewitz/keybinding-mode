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
            inherited: contents[mode]
            resolved: false
            execute: null
            keymap: null
          @modes[mode].inh.splice(0, 0, '!all')
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
    @key_subscription = atom.keymaps.add 'keybinding-mode:' + name, mode.keymap
    @emitter.emit 'activate', name

  resolve: (name) ->
    return @modes[name] if @modes[name]?.resolved
    return unless @dryRun name
    return @_resolve name, @modes[name], '!all'

  _resolve: (name, mode, source, _static) ->
    return unless mode?
    return @modes[name] if @modes[name].resolved

    __static = [true]

    inherited = mode.inherited.slice()
    source = @sourceFromElement inherited.shift(), source, __static

    strictly_static = __static[0]

    for inh in inherited
      switch (typeof inh)
        when 'string'
          if @isStaticMode inh
            _mode = @getStaticMode inh
          else
            _mode = @getDynamicMode inh
            strictly_static = false
        else
          if @isKeymap inh
            _mode =
              inherited: []
              resolved: false
              execute: inh.execute
              keymap: inh.keymap
          else if @isCombined inh
            _mode = @getCombined inh
          else if @isSpecial inh
            _mode = @getSpecial inh, __static
            strictly_static = false unless __static[0]
          else
            _mode =
              inherited: inh
              resolved: false
              execute: null
              keymap: null
      _mode = @_resolve @getName(inh), _mode, source, __static
      strictly_static = false unless __static[0]
      @filter _mode, source
      @merge mode, _mode
      @mergeFunctions mode.execute, _mode.execute

    @mode[name] = mode
    @mode[name].resolved = true if strictly_static
    _static[0] = strictly_static if _static?
    return mode

  sourceFromElement: (el, source, _strict) ->
    return source unless el?
    return '!all' if el is source
    mode =
      inherited: [el]
      resolved: false
      execute: null
      keymap: null
    return @_resolve @getName(inh), mode, source

  getDynamicMode: (name, source) ->
    if (m = serviceModes.getDynamicMode name)? or (m = dynamicModes.getDynamicMode name)? or (m = regexModes.getDynamicMode name)?
      return @_resolve name, m, source
    return null

  getStaticMode: (name, source) ->
    if (m = @modes[name])? or (m = serviceModes.getStaticMode name)?
      return @_resolve name, m, source
    return null

  getCombined: (inh) ->
    r = []
    left = inh.shift
    op = inh.shift
    right = inh.shift
    if op is '&'
      return {inherited: [left, right]}
    else
      return {inherited: [left, '+', right]}

  getSpecial: (inh, _static) ->
    return regexModes.getSpecial inh, _static

  isCombined: (inh) ->
    for i in inh
      return true if (typeof i) is 'string' and /^[&|]$/.test i
    return false

  isSpecial: (inh) ->
    return inh[0][0] is '!'

  isKeymap: (mode) ->
    return mode.keymap? or mode.execute?

  isStaticMode: (name) ->
    return true if @modes[name]?
    return true if serviceModes.isStaticMode name
    return false

  getName: (name) ->
    return name if (typeof name) is 'string'
    md5.update(JSON.stringify(name))
    md5.digest('hex')

  mergeFunctions: (mode, a, b) ->
    if a? and b?
      mode.execute = ((x, y) -> (r) -> x r; y r)(a, b)
    else if a?
      mode.execute = a
    else if b?
      mode.execute = b

  merge: (dest, source) ->
    return dest.keymap if source is '!all'
    _.deepExtend dest.keymap, source.keymap

  filter: (dest, source) ->
    return dest if source is '!all'
    dest.keymap = _.pick dest.keymap, (v, k) ->
      return false unless source[k]?
      dest.keymap[k] = _.pick dest.keymap[k], (v, k2) ->
        return false unless source[k][k2]?
        return true
      return true

  dryRun: (name) ->
    mode = @modes[name]
    return false unless mode?
    return true if mode?.resolved
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
