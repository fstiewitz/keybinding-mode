modes = require '../lib/dynamic-modes'

describe 'Mode Provider - Dynamic', ->

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('tree-view')

  describe 'Test validMode', ->
    it 'not dynamic', ->
      expect(modes.validMode 'custom').toBe false
    it 'core mode', ->
      expect(modes.validMode '-user-packages').toBe true
    it 'loaded package', ->
      expect(modes.validMode '-tree-view').toBe true
    it 'unloaded package', ->
      expect(modes.validMode '-foo-bar').toBe false
