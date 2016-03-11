modes = require '../lib/dynamic-modes'

describe 'Mode Provider - Dynamic', ->

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('tree-view')

  describe 'Test validMode', ->
    it 'not dynamic', ->
      expect(modes.isValidMode 'custom').toBe false
    it 'core mode', ->
      expect(modes.isValidMode '-user-packages').toBe true
    it 'loaded package', ->
      expect(modes.isValidMode '-tree-view').toBe true
    it 'unloaded package', ->
      expect(modes.isValidMode '-foo-bar').toBe false
