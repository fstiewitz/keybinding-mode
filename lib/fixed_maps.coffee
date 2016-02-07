_ = require 'underscore-plus'
path = require 'path'

module.exports =

  matchesKeymap: (key) ->
    /^[-+][A-Za-z0-9-]+$/.test(key)

  getKeymap: (key) ->
    op = key[0]
    name = key.substr(1)
    if name in ['user-packages', 'core-packages', 'core', 'custom', 'lower', 'upper', 'numbers']
      return this[name](op)
    else
      return @resolveKeymap(op, name)

  resolveKeymap: (op, name) ->
    pack = atom.packages.getLoadedPackage(name)
    return {} unless pack?
    return keymap: pack.keymaps[1]

  'user-packages': (op) ->
    execute: ->
      for pack in atom.packages.getLoadedPackages()
        continue if atom.packages.isBundledPackage pack.name
        if op is '+'
          pack.activateKeymaps()
        else
          pack.deactivateKeymaps()

  'core-packages': (op) ->
    execute: ->
      for pack in atom.packages.getLoadedPackages()
        continue unless atom.packages.isBundledPackage pack.name
        if op is '+'
          pack.activateKeymaps()
        else
          pack.deactivateKeymaps()

  'core': (op) ->
    keys = {}
    for keybinding in atom.keymaps.keyBindings
      continue if keybinding.source.indexOf(path.join('app.asar', 'keymaps')) is -1
      keys[keybinding.selector] ?= {}
      if op is '+'
        keys[keybinding.selector][keybinding.keystrokes] = keybinding.command
      else
        keys[keybinding.selector][keybinding.keystrokes] = 'unset!'
    return keymap: keys

  'custom': (op) ->
    keys = {}
    for keybinding in atom.keymaps.keyBindings
      continue if keybinding.source is atom.keymaps.getUserKeymapPath()
      keys[keybinding.selector] ?= {}
      if op is '+'
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
