{Emitter} = require 'atom'

extensions = require './extensions'
dynamicModes = require './dynamic-modes'
regexModes = require './regex-modes'
serviceModes = require './service-modes'

crypto = require('crypto')

path = require 'path'
fs = require 'fs'

CSON = require 'season'

_ = require('underscore-plus')

debug = (type, obj) ->
  console.log {type, obj} if atom.config.get('keybinding-mode.debugger')

report = (msg) ->
  atom.notifications?.addError msg
  console.log msg

pick = (o, f) ->
  r = {}
  for k in Object.keys(o)
    r[k] = o[k] if f(k)
  return r

merge = (dest, source) ->
  return unless dest?
  return unless source?
  return if source is '!all'
  dest.keymap = {} unless dest.keymap?
  if source.keymap?
    for selector in Object.keys(source.keymap)
      if dest.keymap[selector]?
        for key in Object.keys(source.keymap[selector])
          dest.keymap[selector][key] = source.keymap[selector][key]
      else
        dest.keymap[selector] = _.clone source.keymap[selector]
  if dest.execute and source?.execute
    dest.execute = ((x, y) -> (r) -> x r; y r)(dest.execute, source.execute)
  else if source?.execute
    dest.execute = source.execute

filter = (dest, source) ->
  return if source is '!all'
  dest.keymap = pick dest.keymap, (k) ->
    return false unless source.keymap[k]?
    dest.keymap[k] = pick dest.keymap[k], (k2) ->
      return source.keymap[k][k2]?
    return true

getKeyBindings = ->
  return atom.keymaps.getKeyBindings() if @source is '!all'
  keymap = @source.keymap
  r = []
  for selector in Object.keys keymap
    for keystrokes in Object.keys keymap[selector]
      r.push {selector, keystrokes, command: keymap[selector][keystrokes]}
  r

plusKeymap = (sobj) ->
  sobj.no_filter = true
  keymap = {}
  for keybinding in sobj.getKeyBindings()
    keymap[keybinding.selector] ?= {}
    keymap[keybinding.selector][keybinding.keystrokes] = keybinding.command
  return {keymap}

minusKeymap = (sobj) ->
  sobj.no_filter = true
  keymap = {}
  for keybinding in sobj.getKeyBindings()
    keymap[keybinding.selector] ?= {}
    keymap[keybinding.selector][keybinding.keystrokes] = 'unset!'
  return {keymap}

module.exports =
  modes: {} # Stores keybinding modes
  mode_subscription: null # Stores atom.commands.add bindings
  key_subscription: null # Stores current keybinding subscription
  current_keymap: null # Stores current keymap name
  emitter: null

  activate: ->
    if atom.inSpecMode()
      @merge = merge
      @filter = filter
    @emitter = new Emitter
    extensions.activate()
    regexModes.activate()
    serviceModes.activate()

  deactivate: ->
    @modes = {}
    @mode_subscription?.dispose()
    @mode_subscription = null
    @deactivateKeymap @current_keymap if @current_keymap?
    extensions.deactivate()
    regexModes.deactivate()
    serviceModes.deactivate()
    @emitter?.dispose()
    @emitter = null

  onReload: (cb) ->
    @emitter.on 'reload', cb

  onToggle: (cb) ->
    @emitter.on 'toggle', cb

  onDeactivate: (cb) ->
    @emitter.on 'deactivate', cb

  onActivate: (cb) ->
    @emitter.on 'activate', cb

  reload: (f) ->
    @deactivateKeymap(@current_keymap) if @current_keymap?
    filepath = f ? path.join(path.dirname(atom.config.getUserConfigPath()), 'keybinding-mode.cson')
    new Promise((resolve, reject) =>
      fs.exists filepath, (exists) =>
        return unless exists
        CSON.readFile filepath, (error, contents) =>
          if error? or not contents?
            report 'Could not read ' + filepath
            reject 'Could not read ' + filepath
            return
          @mode_subscription?.dispose()
          @modes = {}
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
          resolve()
    )

  toggleKeymap: (name) ->
    if atom.config.get('keybinding-mode.debugger')
      @resolveWithTest name
      return
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
    mode.execute?(true)
    @emitter.emit 'deactivate', name

  activateKeymap: (name) ->
    @current_keymap = name
    mode = @resolveWithTest(name)
    return unless mode?
    mode.execute?()
    @key_subscription = atom.keymaps.add 'keybinding-mode:' + name, mode.keymap
    @emitter.emit 'activate', name

  resolveWithTest: (name) ->
    return @modes[name] if @modes[name]?.resolved
    return unless @dryRun name
    m = @diff(@_resolve name)
    if atom.config.get('keybinding-mode.debugger')
      CSON.writeFileSync path.join(path.dirname(atom.config.getUserConfigPath()), 'keybinding-mode-dump.cson'), m.keymap
    return m

  diff: (mode) ->
    m = mode.keymap
    all = {}
    for {selector, keystrokes, command} in atom.keymaps.getKeyBindings()
      all[selector] ?= {}
      all[selector][keystrokes] = command

    for s in Object.keys m
      selector = m[s]
      for k in Object.keys selector
        exists = all[s]?[k]?
        if ((not exists) and s isnt '*' and selector[k] is 'unset!') or all[s]?[k] is selector[k]
          delete selector[k]

    return mode

  resolve: (name, sobj) ->
    return @modes[name] if @modes[name]?.resolved
    return @_resolve name, sobj

  _resolve: (name, _sobj) ->
    inh = @modes[name].inherited.slice()
    inh = @replacePatterns inh, name
    _sobj ?= {}
    _sobj.is_static = false
    if inh.length > 1
      source = @getSource inh.shift(), _sobj
    else if _sobj.source?
      source = _sobj.source
    else
      source = '!all'
    debug 'source', source
    debug 'inh', inh
    is_static = _sobj.is_static
    for i in inh
      sobj = {source, getKeyBindings, filter, merge, is_static: false, no_filter: false}
      if (typeof i) is 'string'
        if @isStatic i
          m = @getStatic i, sobj
        else
          m = @getDynamic i, sobj
      else if i instanceof Array
        if @isSpecial i
          m = @getSpecial i, sobj
        else if @isCombined i
          m = @getCombined i, sobj
        else
          m = @process i, sobj
      else
        sobj.is_static = true if i?.keymap?
        m = i
      is_static = true if sobj.is_static
      debug 'pre-filter', {i, m}
      unless sobj.no_filter
        filter m, source
        debug 'post-filter', m
      else
        debug 'no-filter', m
      merge @modes[name], m
      debug 'post-merge', {mode: @modes[name], m}
    @modes[name].resolved = is_static
    return @modes[name]

  getSource: (inh, sobj) ->
    return inh if inh is '!all'
    name = @getName inh
    @modes[name] ?= inherited: [inh]
    @resolve name, sobj

  isStatic: (inh) ->
    return not /^[!+-]/.test inh[0]

  getStatic: (inh, sobj) ->
    if (@modes[inh])?
      sobj.is_static = true
      return @resolve inh, sobj
    if (@modes[inh] = extensions.getStatic inh, sobj)?
      return @resolve inh, sobj
    if (@modes[inh] = serviceModes.getStaticMode inh, sobj)?
      return @resolve inh, sobj
    report "Assertion: getStatic must work on #{inh}"
    return null

  getDynamic: (name, sobj) ->
    return plusKeymap(sobj) if name is '+'
    return minusKeymap(sobj) if name is '-'
    if extensions.isValidMode name
      @modes[name] = inherited: extensions.getDynamic name, sobj
      return @resolve name, sobj
    if serviceModes.isValidMode name
      @modes[name] = inherited: serviceModes.getDynamicMode name, sobj
      return @resolve name, sobj
    if dynamicModes.isValidMode name
      @modes[name] = inherited: dynamicModes.getDynamicMode name, sobj
      return @resolve name, sobj
    if regexModes.isValidMode name
      @modes[name] = inherited: regexModes.getDynamicMode name, sobj
      return @resolve name, sobj
    report "Assertion: getDynamic must work on #{name}"
    return null

  getSpecial: (inh, sobj) ->
    name = @getName inh
    if (m = extensions.getSpecial inh, sobj)?
      @modes[name] = inherited: m
      return @resolve name, sobj
    if (m = regexModes.getSpecial inh, sobj)?
      @modes[name] = inherited: m
      return @resolve name, sobj
    report "Assertion: getSpecial must work on #{inh}"
    return null

  getCombined: (inh, sobj) ->
    sobj.no_filter = true
    name = @getName inh
    @modes[name] = inherited: @_getCombined(inh.slice())
    @resolve name, sobj

  replacePatterns: (mode, name) ->
    m = []
    for inh in mode
      if @isPattern inh
        m = m.concat @getStaticModes inh, name
      else
        m.push inh
    return m

  getStaticModes: (inh, name) ->
    if inh is '~'
      inh = "~^#{name}_"
    r = new RegExp(inh.substr(1))
    return (mode for mode in @getStaticNames() when r.test(mode) and mode isnt name)

  process: (inh, sobj) ->
    sobj.no_filter = true
    name = @getName inh
    @modes[name] = inherited: inh
    @resolve name, sobj

  getName: (name) ->
    return name if (typeof name) is 'string'
    md5 = crypto.createHash('md5')
    md5.update(JSON.stringify(name), 'utf8')
    md5.digest('hex')

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

  getStaticNames: ->
    modes = {}
    modes[k] = true for k in Object.keys(@modes)
    modes[k] = true for k in extensions.getStaticNames()
    modes[k] = true for k in serviceModes.getStaticNames()
    return Object.keys(modes)

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

  isPattern: (inh) ->
    return (typeof inh) is 'string' and inh[0] is '~'

  validMode: (name) ->
    return true if name is '!all'
    return true if @isPattern name
    return true if @modes[name]?
    return true if extensions.isValidMode name
    return true if serviceModes.isValidMode name
    return true if dynamicModes.isValidMode name
    return true if regexModes.isValidMode name
    return false

  validSpecial: (inh) ->
    return true if extensions.isSpecial inh
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
