_ = require 'underscore-plus'
path = require 'path'

service_maps = require './service_maps'

module.exports =

  matchesKeymap: (key) ->
    /^[-+][A-Za-z0-9-]+$/.test(key) or service_maps.matchesStaticKeymap(key)

  getKeymap: (key) ->
    return k if (k = @resolveByStaticServiceKeymap(key))?
    op = key[0]
    name = key.substr(1)
    return j if (j = @resolveByDynamicServiceKeymap(op is '+', name))?
    if name in ['user-packages', 'core-packages', 'all-core', 'custom', 'lower', 'upper', 'numbers']
      return this[name](op is '+')
    else
      return @resolveKeymap(op is '+', name)

  resolveKeymap: (op, name) ->
    pack = atom.packages.getLoadedPackage(name)
    return @resolveByFilter(op, name) unless pack?
    def = pack.keymapActivated
    return execute: (reset = false) ->
      console.log atom.packages.getLoadedPackage(name)
      if (op ^ reset) or (reset and def)
        atom.packages.getLoadedPackage(name).activateKeymaps()
      else
        atom.packages.getLoadedPackage(name).deactivateKeymaps()

  resolveByStaticServiceKeymap: (name) ->
    service_maps.resolveStaticKeymap name

  resolveByDynamicServiceKeymap: (op, name) ->
    service_maps.resolveDynamicKeymap op, name

  resolveByFilter: (op, name) ->
    filter = new RegExp(name)
    keys = null
    for keybinding in atom.keymaps.getKeyBindings()
      if filter.test(keybinding.command) or filter.test(keybinding.keystrokes)
        keys ?= {}
        keys[keybinding.selector] ?= {}
        if op
          keys[keybinding.selector][keybinding.keystrokes] = keybinding.command
        else
          keys[keybinding.selector][keybinding.keystrokes] = 'unset!'
    return keymap: keys if keys?
    return {}

  'user-packages': (op) ->
    def = {}
    for pack in atom.packages.getLoadedPackages()
      continue if atom.packages.isBundledPackage pack.name
      def[pack.name] = pack.keymapActivated
    return execute: (reset = false) ->
      _op = op ^ reset
      for pack in atom.packages.getLoadedPackages()
        continue if atom.packages.isBundledPackage pack.name
        if _op or (reset and def[pack.name])
          pack.activateKeymaps?()
        else
          pack.deactivateKeymaps?()

  'core-packages': (op) ->
    def = {}
    for pack in atom.packages.getLoadedPackages()
      continue unless atom.packages.isBundledPackage pack.name
      def[pack.name] = pack.keymapActivated
    return execute: (reset = false) ->
      _op = op ^ reset
      for pack in atom.packages.getLoadedPackages()
        continue unless atom.packages.isBundledPackage pack.name
        if _op or (reset and def[pack.name])
          pack.activateKeymaps?()
        else
          pack.deactivateKeymaps?()

  'all-core': (op) ->
    keys = {}
    for keybinding in atom.keymaps.keyBindings
      continue if keybinding.source.indexOf(path.join('app.asar', 'keymaps')) is -1
      keys[keybinding.selector] ?= {}
      if op
        keys[keybinding.selector][keybinding.keystrokes] = keybinding.command
      else
        keys[keybinding.selector][keybinding.keystrokes] = 'unset!'
    return keymap: keys

  'custom': (op) ->
    keys = {}
    for keybinding in atom.keymaps.keyBindings
      continue unless keybinding.source is atom.keymaps.getUserKeymapPath()
      keys[keybinding.selector] ?= {}
      if op
        keys[keybinding.selector][keybinding.keystrokes] = keybinding.command
      else
        keys[keybinding.selector][keybinding.keystrokes] = 'unset!'
    return keymap: keys

  'lower': ->
    keys = 'atom-text-editor:not(.mini)': {}
    for key in 'abcdefghijklmnopqrstuvwxyz'.split('')
      keys['atom-text-editor:not(.mini)'][key] = 'abort!'
    return keymap: keys

  'upper': ->
    keys = 'atom-text-editor:not(.mini)': {}
    for key in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')
      keys['atom-text-editor:not(.mini)'][key] = 'abort!'
    return keymap: keys

  'numbers': ->
    keys = 'atom-text-editor:not(.mini)': {}
    for key in [0..9]
      keys['atom-text-editor:not(.mini)'][key + ''] = 'abort!'
    return keymap: keys
