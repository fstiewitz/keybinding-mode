modes = require '../lib/service-modes'

describe 'Mode Provider - Service', ->
  mode = null
  disp = null

  beforeEach ->
    modes.activate()
    mode =
      name: 'test'
      modes:
        mode1:
          keymap:
            'atom-text-editor':
              'ctrl-k': 'foo'
        mode2: (op) ->
          keymap:
            'atom-text-editor':
              'ctrl-k': 'foo'
    disp = modes.consume mode

  afterEach ->
    expect(modes.smodes['mode1']).toEqual mode.modes.mode1
    expect(modes.dmodes['mode2']).toEqual mode.modes.mode2
    disp.dispose()
    expect(modes.smodes['mode1']).toBe null
    expect(modes.dmodes['mode2']).toBe null
    modes.deactivate()

  describe 'Test validMode', ->
    it 'valid static', ->
      expect(modes.isValidMode 'mode1').toBe true
    it 'valid dynamic', ->
      expect(modes.isValidMode '+mode2').toBe true
    it 'invalid', ->
      expect(modes.isValidMode 'foobar').toBe false
