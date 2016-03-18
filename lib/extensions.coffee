{Disposable} = require 'atom'

report = (msg) ->
  atom.notifications?.addError msg
  console.log msg

module.exports =

  activate: ->
    @extensions = {}
    @static_ext = {}
    @dynamic_ext = {}
    @special_ext = {}

  deactivate: ->
    @remove name for name in Object.keys(@extensions)
    @extensions = null
    @static_ext = null
    @dynamic_ext = null
    @special_ext = null

  remove: (name) ->
    return unless @extensions[name]?
    @static_ext[ext] = null for ext in @extensions[name].static
    @dynamic_ext[ext] = null for ext in @extensions[name].dynamic
    @special_ext[ext] = null for ext in @extensions[name].special
    delete @consumed[name]

  consume: ({name, extensions}) ->
    unless name?
      report 'Service did not provide name'
      return
    unless extensions?
      report 'Service did not provide any extensions'
      return
    unless extensions instanceof Array
      report 'Service\'s extensions is not an array'
      return
    if @extensions[name]?
      report "Service #{name} already exists"
      return
    r =
      static: []
      dynamic: []
      special: []
      all: []
    s = 0
    d = 0
    sp = 0
    a = 0
    for extension in extensions
      unless extension.isValidMode?
        report 'Extension must provide ::isValidMode(name)'
        continue

      if extension.getSpecial?
        unless extension.isSpecial?
          report 'Extension must provide ::isSpecial(inh)'
          continue

      if extension.getStaticMode? and extension.getDynamicMode?
        unless extension.isStaticMode?
          report 'Extension must provide ::isStaticMode(name)'
          continue
      else if extension.getStaticMode?
        extension.isStaticMode = -> true
      else if extension.getDynamicMode?
        extension.isStaticMode = -> false

      r.all.push name + a
      a = a + 1
      if extension.getStaticMode?
        r.static.push name + s
        @static_ext[name + s] = extension
        s = s + 1
      if extension.getDynamicMode?
        r.dynamic.push name + d
        @dynamic_ext[name + d] = extension
        d = d + 1
      if extension.getSpecial?
        r.special.push name + sp
        @special_ext[name + sp] = extension
        sp = sp + 1

    @extensions[name] = r
    new Disposable(=> @remove(name))

  getStatic: (inh, sobj) ->
    sobj.is_static = true
    for k in Object.keys(@static_ext)
      if (m = @static_ext[k].getStaticMode inh, sobj)?
        return m
    return null

  getDynamic: (inh, sobj) ->
    for k in Object.keys(@dynamic_ext)
      if (m = @dynamic_ext[k].getDynamicMode inh, sobj)?
        return m
    return null

  getSpecial: (inh, sobj) ->
    for k in Object.keys(@special_ext)
      if (m = @special_ext[k].getSpecial inh, sobj)?
        return m
    return null

  isSpecial: (inh) ->
    for k in Object.keys(@special_ext)
      if @special_ext[k].isSpecial inh
        return true
    return false

  isValidMode: (inh) ->
    for k in Object.keys(@extensions)
      for ext in @extensions[k].all
        if ext.isValidMode inh
          return true
    return false

  isStaticMode: (inh) ->
    for k in Object.keys(@static_ext)
      if @static_ext[k].isStaticMode inh
        return true
    return false
