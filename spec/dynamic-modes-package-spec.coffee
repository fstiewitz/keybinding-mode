modes = require '../lib/dynamic-modes'

{Disposable} = require 'atom'

createPackage = (n) ->
  name: n
  activateKeymaps: jasmine.createSpy('activateKeymaps')
  deactivateKeymaps: jasmine.createSpy('deactivateKeymaps')

describe 'Dynamic Modes - Package Test', ->

  p = null
  s = null

  beforeEach ->
    p = [
      createPackage('test0')
      createPackage('test1')
      createPackage('test2')
    ]
    s = atom.packages
    atom.packages =
      getLoadedPackage: jasmine.createSpy('getLoadedPackage').andCallFake (n) -> return _ for _ in p when _.name is n
      getLoadedPackages: jasmine.createSpy('getLoadedPackages').andCallFake -> p
      isBundledPackage: jasmine.createSpy('isBundledPackage').andCallFake (t) -> t is 'test2'
    atom.keymaps.keyBindings = [
      {
        source: 'test0.cson'
        selector: 's0'
        keystrokes: 'k0'
        command: 'command0:foo'
      }
      {
        source: 'test0.cson'
        selector: 's0'
        keystrokes: 'k1'
        command: 'command1'
      }
      {
        source: 'app.asar/keymaps'
        selector: 's1'
        keystrokes: 'k0'
        command: 'command0:bla'
      }
      {
        source: 'test2.cson'
        selector: 's0'
        keystrokes: 'k1'
        command: 'command1'
      }
    ]
    spyOn(atom.keymaps, 'getUserKeymapPath').andCallFake -> 'test0.cson'

  afterEach ->
    atom.packages = s

  describe '::getPackageMode', ->
    it 'returns a keymap', ->
      k = modes.getPackageMode false, 'test2'
      expect(k.keymap).toBeUndefined()
      expect(k.inherited).toBeUndefined()
      expect(k.execute).toBeDefined()
      k.execute(false)
      expect(atom.packages.getLoadedPackage('test2').deactivateKeymaps).toHaveBeenCalled()
      k.execute(true)
      expect(atom.packages.getLoadedPackage('test2').activateKeymaps).toHaveBeenCalled()

  describe '::user-packages', ->
    it 'returns a keymap', ->
      k = modes['user-packages'] false
      expect(k.keymap).toBeUndefined()
      expect(k.inherited).toBeUndefined()
      expect(k.execute).toBeDefined()
      k.execute(false)
      expect(atom.packages.getLoadedPackage('test0').deactivateKeymaps).toHaveBeenCalled()
      expect(atom.packages.getLoadedPackage('test1').deactivateKeymaps).toHaveBeenCalled()
      k.execute(true)
      expect(atom.packages.getLoadedPackage('test0').activateKeymaps).toHaveBeenCalled()
      expect(atom.packages.getLoadedPackage('test1').activateKeymaps).toHaveBeenCalled()

  describe '::core-packages', ->
    it 'returns a keymap', ->
      k = modes['core-packages'] false
      expect(k.keymap).toBeUndefined()
      expect(k.inherited).toBeUndefined()
      expect(k.execute).toBeDefined()
      k.execute(false)
      expect(atom.packages.getLoadedPackage('test2').deactivateKeymaps).toHaveBeenCalled()
      k.execute(true)
      expect(atom.packages.getLoadedPackage('test2').activateKeymaps).toHaveBeenCalled()

  describe '::all-core', ->
    it 'returns a keymap', ->
      k = modes['all-core'] false
      expect(k.keymap).toBeDefined()
      expect(k.inherited).toBeUndefined()
      expect(k.execute).toBeUndefined()
      expect(k.keymap).toEqual {s1: k0: 'unset!'}

  describe '::custom', ->
    it 'returns a keymap', ->
      k = modes['custom'] false
      expect(k.keymap).toBeDefined()
      expect(k.inherited).toBeUndefined()
      expect(k.execute).toBeUndefined()
      expect(k.keymap).toEqual
        s0:
          k0: 'unset!'
          k1: 'unset!'
