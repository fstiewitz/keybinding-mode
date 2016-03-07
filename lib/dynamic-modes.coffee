module.exports =
  getDynamicMode: (name) ->

  validMode: (name) ->
    return false unless /^(\+|\-)/.test name
    _name = name.substr(1)
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
