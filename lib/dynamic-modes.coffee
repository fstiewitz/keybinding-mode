path = require 'path'

module.exports =
  getDynamicMode: (name, source) ->
    source.flags.resolved = true
    op = name[0]
    name = name.substr(1)
    asKeymap = name[0] is '!'
    name = name.substr(1) if asKeymap
    if name in [
      'core-packages'
      'user-packages'
      'all-core'
      'custom'
      'upper'
      'lower'
      'numbers'
    ]
      return this[name](op is '+', asKeymap)
    else
      return @getPackageMode op is '+', name, asKeymap

  getPackageMode: (op, name, asKeymap) ->
    def = atom.packages.getLoadedPackage(name)?.keymapActivated
    return unless def?
    if asKeymap
      m = {}
      for [p, keymap] in atom.packages.getLoadedPackage(name).keymaps
        for s in Object.keys(keymap)
          m[s] = {}
          for k in Object.keys(keymap[s])
            if op
              m[s][k] = keymap[s][k]
            else
              m[s][k] = 'unset!'
      return keymap: m
    else
      return {
        execute: (reset = false) ->
          if (op ^ reset) or (reset and def)
            atom.packages.getLoadedPackage(name)?.activateKeymaps?()
          else
            atom.packages.getLoadedPackage(name)?.deactivateKeymaps?()
      }

  isValidMode: (name) ->
    return false unless /^(\+|\-)/.test name
    _name = name.substr(1)
    _name = _name.substr(1) if _name[0] is '!'
    return true if _name is ''
    return true if _name in [
      'core-packages'
      'user-packages'
      'all-core'
      'custom'
      'upper'
      'lower'
      'numbers'
    ]
    return true for pack in atom.packages.getLoadedPackages() when pack.name is _name
    return false

  'user-packages': (op, asKeymap) ->
    if asKeymap
      m = {}
      for p in atom.packages.getLoadedPackages()
        continue if atom.packages.isBundledPackage p.name
        for [_, keymap] in p.keymaps
          for s in Object.keys(keymap)
            m[s] ?= {}
            for k in Object.keys(keymap[s])
              if op
                m[s][k] = keymap[s][k]
              else
                m[s][k] = 'unset!'
      return keymap: m
    else
      def = {}
      for pack in atom.packages.getLoadedPackages()
        continue if atom.packages.isBundledPackage pack.name
        def[pack.name] = pack.keymapActivated
      return {
        execute: (reset = false) ->
          _op = op ^ reset
          for pack in atom.packages.getLoadedPackages()
            continue if atom.packages.isBundledPackage pack.name
            if _op or (reset and def[pack.name])
              pack.activateKeymaps?()
            else
              pack.deactivateKeymaps?()
      }

  'core-packages': (op, asKeymap) ->
    if asKeymap
      m = {}
      for p in atom.packages.getLoadedPackages()
        continue unless atom.packages.isBundledPackage p.name
        for [_, keymap] in p.keymaps
          for s in Object.keys(keymap)
            m[s] ?= {}
            for k in Object.keys(keymap[s])
              if op
                m[s][k] = keymap[s][k]
              else
                m[s][k] = 'unset!'
      return keymap: m
    else
      def = {}
      for pack in atom.packages.getLoadedPackages()
        continue unless atom.packages.isBundledPackage pack.name
        def[pack.name] = pack.keymapActivated
      return {
        execute: (reset = false) ->
          _op = op ^ reset
          for pack in atom.packages.getLoadedPackages()
            continue unless atom.packages.isBundledPackage pack.name
            if _op or (reset and def[pack.name])
              pack.activateKeymaps?()
            else
              pack.deactivateKeymaps?()
      }

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
    keys =
      'body': {}
      'atom-workspace atom-text-editor[mini]': {}
    for key in 'abcdefghijklmnopqrstuvwxyz'.split('')
      keys['body'][key] = 'no-command'
      keys['atom-workspace atom-text-editor[mini]'][key] = 'native!'
    return keymap: keys

  'upper': ->
    keys =
      'body': {}
      'atom-workspace atom-text-editor[mini]': {}
    for key in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')
      keys['body'][key] = 'no-command'
      keys['atom-workspace atom-text-editor[mini]'][key] = 'native!'
    return keymap: keys

  'numbers': ->
    keys =
      'body': {}
      'atom-workspace atom-text-editor[mini]': {}
    for key in [0..9]
      keys['body'][key] = 'no-command'
      keys['atom-workspace atom-text-editor[mini]'][key] = 'native!'
    return keymap: keys
