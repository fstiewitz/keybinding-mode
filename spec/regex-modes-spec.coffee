modes = require '../lib/regex-modes'

getKeyBindings = ->
  atom.keymaps.getKeyBindings()

sobj = {getKeyBindings, flags: {no_filter: false}}

describe 'Mode Provider - Regular Expressions', ->

  beforeEach ->
    modes.activate()

  afterEach ->
    modes.deactivate()

  describe 'Test validMode', ->
    it 'simple matching', ->
      expect(modes.isValidMode '+k/^ctrl-/').toBe true
    it 'simple replace', ->
      expect(modes.isValidMode '+k/^ctrl-//').toBe true
    it 'simple fail (wrong attribute)', ->
      expect(modes.isValidMode '+f/^ctrl-//').toBe false
    it 'simple fail (wrong separator)', ->
      expect(modes.isValidMode '+c/^ctrl-z#').toBe false
    it 'simple fail (wrong second separator)', ->
      expect(modes.isValidMode '+k/^ctrl-z/#').toBe false

  describe 'Test getDynamicMode', ->
    it 'simple matching', ->
      expect(modes.getDynamicMode '+k/^ctrl-n/', sobj).toEqual keymap: body: 'ctrl-n': 'application:new-file'
    it 'simple replace', ->
      expect(modes.getDynamicMode '+k/^ctrl-k ctrl-alt-//', sobj).toEqual keymap: body: w: 'pane:close-other-items'

  describe 'Test getSpecial', ->
    it '+match', ->
      expect(modes.getSpecial ['!+', 'key', '^home$'], sobj).toEqual
        keymap:
          'atom-text-editor':
            'home': 'editor:move-to-first-character-of-line'
    it '-match', ->
      expect(modes.getSpecial ['!-', 'key', '^home$'], sobj).toEqual
        keymap:
          'atom-text-editor':
            'home': 'unset!'
    it '+replace', ->
      expect(modes.getSpecial ['!+', 'key', '^(.+?) up', 'ctrl-u $1'], sobj).toEqual
        keymap:
          'body':
            'ctrl-u ctrl-k': 'pane:split-up-and-copy-active-item'
    it '-replace', ->
      expect(modes.getSpecial ['!-', 'key', '^(.+?) up', 'ctrl-u $1'], sobj).toEqual
        keymap:
          'body':
            'ctrl-k up': 'unset!'
            'ctrl-u ctrl-k': 'pane:split-up-and-copy-active-item'

  describe 'Test isSpecial', ->
    it 'simple matching', ->
      expect(modes.isSpecial ['!+', 'key', '^ctrl-', undefined]).toBe true
    it 'simple replace', ->
      expect(modes.isSpecial ['!+', 'selector', '^ctrl-', '']).toBe true
    it 'simple fail - length', ->
      expect(modes.isSpecial [1, 2]).toBe false
    it 'simple fail - operator', ->
      expect(modes.isSpecial [1, 2, 3]).toBe false
    it 'simple fail - typeof', ->
      expect(modes.isSpecial [1, 'key', 3, 4]).toBe false
      expect(modes.isSpecial [1, 'key', 'bla', 4]).toBe false
