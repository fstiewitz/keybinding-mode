{CompositeDisposable} = require 'atom'

fs = require 'fs'
path = require 'path'
CSON = require 'season'
_ = require 'underscore-plus'

fixed_maps = require './fixed_maps'

service_maps = null

module.exports = KeybindingMode =
  subscriptions: null
  modes: null
  current_keymap: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'keybinding-mode:open-config': ->
      atom.workspace.open(path.join(path.dirname(atom.config.getUserConfigPath()), 'keybinding-mode.cson'))
    @subscriptions.add atom.commands.add 'atom-workspace', 'keybinding-mode:reload': => @reload()
    @reload()

  deactivate: ->
    @subscriptions.dispose()
    @mode_subscription?.dispose()
    @statusBarTile?.destroy()
    @keybindingElement = null
    @statusBarTile = null
    @deactivateKeymap @current_keymap if @current_keymap?
    @current_keymap = null
    service_maps = null

  serialize: ->

  reload: ->
    filepath = path.join(path.dirname(atom.config.getUserConfigPath()), 'keybinding-mode.cson')
    fs.exists filepath, (exists) =>
      return console.log "#{filepath} does not exist and this package is useless without it" unless exists
      CSON.readFile filepath, (error, contents) =>
        if error?
          atom.notifications?.addError 'Could not read ' + filepath
          return
        @modes = @parse contents
        @mode_subscription?.dispose()
        command_map = {}
        for mode in Object.keys @modes
          command_map['keybinding-mode:' + mode] = ((_this, name) -> -> _this.toggleKeymap(name))(this, mode)
        @mode_subscription = atom.commands.add 'atom-workspace', command_map

  toggleKeymap: (name) ->
    if name is @current_keymap
      @deactivateKeymap name
    else
      @deactivateKeymap @current_keymap if @current_keymap?
      @activateKeymap name

  deactivateKeymap: (name) ->
    @current_keymap = null
    @key_subscription?.dispose()
    @modes[name].execute true
    @keybindingElement?.innerText = 'default'

  activateKeymap: (name) ->
    @current_keymap = name
    @keybindingElement?.innerText = name
    @modes[name].execute()
    @key_subscription = atom.keymaps.add 'keybinding-mode:' + name, @modes[name].keymap

  consumeKeybindingMode: ({name, modes}) ->
    (service_maps ? service_maps = require './service_maps').consumeKeybindingMode name, modes

  parse: (contents) ->
    ret = {}
    for key in Object.keys contents
      @buildKeymap ret, key, contents
    return ret

  buildKeymap: (obj, key, config) ->
    obj[key] ?= {
      keymap: {}
      execute: ->
    }
    if config[key].inherited
      for inh in config[key].inherited
        if obj[inh]
          _.deepExtend obj[key].keymap, obj[inh].keymap
          if obj[inh].execute?
            obj[key].execute = ((x, y) -> (r) -> y(r); x(r))(obj[inh].execute, obj[key].execute)
        else if config[inh]
          @buildKeymap obj, inh, config[inh]
          _.deepExtend obj[key].keymap, obj[inh].keymap
          if obj[inh].execute?
            obj[key].execute = ((x, y) -> (r) -> y(r); x(r))(obj[inh].execute, obj[key].execute)
        else if fixed_maps.matchesKeymap inh
          fm = fixed_maps.getKeymap inh
          _.deepExtend obj[key].keymap, fm.keymap
          if fm.execute?
            obj[key].execute = ((x, y) -> (r) -> y(r); x(r))(fm.execute, obj[key].execute)
        else
          console.log 'Could not resolve name: ' + inh
    _.deepExtend obj[key].keymap, config[key].keymap
    if config[key].execute?
      obj[key].execute = ((x, y) -> (r) -> y(r); x(r))(config[key].execute, obj[key].execute)

  consumeStatusBar: (statusBar) ->
    element = document.createElement 'div'
    element.className = 'inline-block keybinding-mode'
    icon = document.createElement 'span'
    icon.className = 'icon icon-keyboard'
    @keybindingElement = document.createElement 'span'
    element.appendChild icon
    element.appendChild @keybindingElement
    @statusBarTile = statusBar.addRightTile item: element, priority: 50
    @keybindingElement.innerText = 'default'
