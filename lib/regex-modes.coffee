report = (msg) ->
  atom.notifications?.addError msg
  console.log msg

module.exports =

  activate: ->
    @regex_cache = {}

  deactivate: ->
    @regex_cache = null

  getDynamicMode: (name) ->

  validMode: (name) ->
    while name isnt ''
      unless (m = /^([+-])([cks])(.)/.exec name)?
        report "Couldn't match regex start #{name}"
        return false
      name = name.substr(3)
      unless (n = (r = @getRegexWithSeparator(m[3])).exec name)?
        report "Couldn't match regex body #{name}"
        return false
      name = name.substr(n[1].length + 1)
      if (n = /^([&|]|$)/.exec name)?
        name = name.substr(n[1].length)
        continue
      if (n = r.exec name)?
        name = name.substr(n[1].length + 1)
        unless (n = /^([&|]|$)/.exec name)?
          report "Couldn't match substitution regex #{name}"
          return false
        name = name.substr(n[1].length)
      else
        report "Couldn't match regex #{name}"
        return false
    return true

  getRegexWithSeparator: (sep) ->
    return @regex_cache[sep] if @regex_cache[sep]?
    @regex_cache[sep] = new RegExp("^([^#{sep}]*?)#{sep}")
