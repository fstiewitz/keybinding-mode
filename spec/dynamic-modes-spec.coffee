modes = require '../lib/dynamic-modes'

describe 'Mode Provider - Dynamic', ->
  describe 'Test validMode', ->
    it 'not dynamic', ->
      expect(modes.validMode 'custom').toBe false
    it 'core mode', ->
      expect(modes.validMode '-user-packages').toBe true
    it 'loaded package', ->
      waitsForPromise -> atom.packages.activatePackage('tree-view')
      runs -> expect(modes.validMode '-tree-view').toBe true
    it 'unloaded package', ->
      expect(modes.validMode '-foo-bar').toBe false
