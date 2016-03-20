module.exports =
  name: 'not'
  extensions:
    not:
      activate: (@db) ->

      deactivate: ->
        @db = null

      isSpecial: (inh) ->
        return (typeof inh[0]) is 'string' and inh[0] is '!not'

      getSpecial: (inh, sobj) ->
        inh.shift()
        sobj.flags.no_filter = true
        sobj.flags.resolved = true
        mode = keymap: {}
        for i in inh
          nsobj = @db.cloneSourceObject(sobj)
          nsobj.flags.not = true
          @db.resolveFilter mode, i, nsobj, sobj
        return mode
