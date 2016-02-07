{CompositeDisposable} = require 'atom'

path = require 'path'
CSON = require 'season'
_ = require 'underscore-plus'
fixed_maps = require './fixed_maps'

module.exports = KeybindingMode =
  subscriptions: null
  modes: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'keybinding-mode:open-config': ->
      atom.workspace.open(path.join(path.dirname(atom.config.getUserConfigPath()), 'keybinding-mode.cson'))
    @subscriptions.add atom.commands.add 'atom-workspace', 'keybinding-mode:reload': => @reload()

  deactivate: ->
    @subscriptions.dispose()
    @mode_subscription?.dispose()

  serialize: ->

  reload: ->
    filepath = path.join(path.dirname(atom.config.getUserConfigPath()), 'keybinding-mode.cson')
    CSON.readFile filepath, (error, contents) =>
      if error?
        atom.notifications?.addError 'Could not read ' + filepath
        return
      @modes = @parse contents
      @mode_subscription?.dispose()
      command_map = {}
      for mode in Object.keys @modes
        command_map['keybinding-mode:' + mode] = ((_this, name) -> -> _this.activateKeymap(name))(this, mode)
      @mode_subscription = atom.commands.add 'atom-workspace', command_map

  activateKeymap: (name) ->
    @key_subscription?.dispose()
    @modes[name].execute()
    @key_subscription = atom.keymaps.add 'keybinding-mode:' + name, @modes[name].keymap

  parse: (contents) ->
    ret = {}
    for key in Object.keys contents
      @buildKeymap ret, key, contents
    console.log ret
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
            obj[key].execute = ((x, y) -> -> x(); y())(obj[inh].execute, obj[key].execute)
        else if config[inh]
          @buildKeymap obj, inh, config[inh]
          _.deepExtend obj[key].keymap, obj[inh].keymap
          if obj[inh].execute?
            obj[key].execute = ((x, y) -> -> x(); y())(obj[inh].execute, obj[key].execute)
        else if fixed_maps.matchesKeymap inh
          fm = fixed_maps.getKeymap inh
          _.deepExtend obj[key].keymap, fm.keymap
          if fm.execute?
            obj[key].execute = ((x, y) -> -> x(); y())(fm.execute, obj[key].execute)
        else
          console.log 'Could not resolve name: ' + inh
    _.deepExtend obj[key].keymap, config[key].keymap
    if config[key].execute?
      obj[key].execute = ((x, y) -> -> x(); y())(fm.execute, config[key].execute)
