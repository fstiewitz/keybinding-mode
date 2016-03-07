modes = require '../lib/regex-modes'

fdescribe 'Mode Provider - Regular Expressions', ->

  beforeEach ->
    modes.activate()

  afterEach ->
    modes.deactivate()

  describe 'Test validMode', ->
    it 'simple matching', ->
      expect(modes.validMode '+k/^ctrl-/').toBe true
    it 'chained matching', ->
      expect(modes.validMode '+k/^ctrl-/&+s/^atom-text-editor/').toBe true
    it 'simple replace', ->
      expect(modes.validMode '+k/^ctrl-//').toBe true
    it 'chained replace', ->
      expect(modes.validMode '+k/^ctrl-//&+k/y/z/').toBe true
    it 'simple fail (wrong attribute)', ->
      expect(modes.validMode '+f/^ctrl-//').toBe false
    it 'simple fail (wrong separator)', ->
      expect(modes.validMode '+c/^ctrl-z#').toBe false
    it 'simple fail (wrong second separator)', ->
      expect(modes.validMode '+k/^ctrl-z/#').toBe false
    it 'chained fail (wrong attribute)', ->
      expect(modes.validMode '+k/^ctrl-/&-b#abc#').toBe false
    it 'chained fail (wrong operator)', ->
      expect(modes.validMode '+k/^ctrl-/^+s/^atom-text-editor/').toBe false
    it 'faulty chained fail (wrong separator)', ->
      expect(modes.validMode '+k/^ctrl-#&+s/^atom-text-editor/').toBe true
