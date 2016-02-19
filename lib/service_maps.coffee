{Disposable} = require 'atom'

module.exports =
  modes: {}

  consumeKeybindingMode: (modes) ->
    for mode in Object.keys(modes)
      @modes[mode] = modes[mode]
    new Disposable(=>
      for mode in Object.keys(modes)
        @modes[mode] = null
    )

  resolveKeymap: (op, name) ->
    return m op if (m = @modes[name])?
    return null
