modes = require '../lib/regex-modes'

describe 'Mode Provider - Regular Expressions', ->

  beforeEach ->
    modes.activate()

  afterEach ->
    modes.deactivate()

  describe 'Test validMode', ->
    it 'simple matching', ->
      expect(modes.validMode '+k/^ctrl-/').toBe true
    it 'simple replace', ->
      expect(modes.validMode '+k/^ctrl-//').toBe true
    it 'simple fail (wrong attribute)', ->
      expect(modes.validMode '+f/^ctrl-//').toBe false
    it 'simple fail (wrong separator)', ->
      expect(modes.validMode '+c/^ctrl-z#').toBe false
    it 'simple fail (wrong second separator)', ->
      expect(modes.validMode '+k/^ctrl-z/#').toBe false
