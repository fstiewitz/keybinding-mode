FixedMaps = require '../lib/fixed_maps'
ServiceMaps = require '../lib/service_maps'

{Disposable} = require 'atom'

createPackage = (n) ->
  name: n
  activateKeymaps: jasmine.createSpy('activateKeymaps')
  deactivateKeymaps: jasmine.createSpy('deactivateKeymaps')

describe 'Fixed Maps', ->

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

  describe '::matchesKeymap', ->
    describe 'on correct input', ->
      it 'returns true', ->
        expect(FixedMaps.matchesKeymap '+test-09').toBe true
    describe 'on wrong input', ->
      it 'returns false', ->
        expect(FixedMaps.matchesKeymap 'test-09').toBe false

  describe 'on service keymap', ->
    disp = null
    k = null

    beforeEach ->
      k =
        service_1: jasmine.createSpy('service_1').andCallFake ->
          keymap:
            s1:
              k2: 'foo'
        service_2:
          keymap:
            s0:
              k3: 'bar'
      disp = ServiceMaps.consumeKeybindingMode 'spec', k

    afterEach ->
      disp.dispose()
      expect(FixedMaps.resolveKeymap true, 'service_1').toEqual {}

    it 'returns a disposable', ->
      expect(disp instanceof Disposable).toBe true

    describe 'on ::resolveByStaticServiceKeymap', ->
      it 'returns the service keymap', ->
        expect(FixedMaps.getKeymap 'service_2').toEqual k.service_2

    describe 'on ::resolveByDynamicServiceKeymap', ->
      it 'returns the service keymap', ->
        expect(FixedMaps.getKeymap '-service_1').toEqual
          keymap:
            s1:
              k2: 'foo'
        expect(k.service_1).toHaveBeenCalledWith false

  describe '::resolveKeymap', ->
    describe 'on wrong input', ->
      it 'returns {}', ->
        expect(FixedMaps.resolveKeymap true, 'test3').toEqual {}
    describe 'on filter', ->
      it 'returns the filtered keymap', ->
        expect(FixedMaps.resolveKeymap false, '^k0$').toEqual
          keymap:
            s0:
              k0: 'unset!'
            s1:
              k0: 'unset!'
        expect(FixedMaps.resolveKeymap false, '^command0:').toEqual
          keymap:
            s0:
              k0: 'unset!'
            s1:
              k0: 'unset!'
    describe 'on correct input', ->
      it 'returns a keymap', ->
        k = FixedMaps.resolveKeymap false, 'test2'
        expect(k.keymap).toBeUndefined()
        expect(k.inherited).toBeUndefined()
        expect(k.execute).toBeDefined()
        k.execute(false)
        expect(atom.packages.getLoadedPackage('test2').deactivateKeymaps).toHaveBeenCalled()
        k.execute(true)
        expect(atom.packages.getLoadedPackage('test2').activateKeymaps).toHaveBeenCalled()

  describe '::user-packages', ->
    it 'returns a keymap', ->
      k = FixedMaps['user-packages'] false
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
      k = FixedMaps['core-packages'] false
      expect(k.keymap).toBeUndefined()
      expect(k.inherited).toBeUndefined()
      expect(k.execute).toBeDefined()
      k.execute(false)
      expect(atom.packages.getLoadedPackage('test2').deactivateKeymaps).toHaveBeenCalled()
      k.execute(true)
      expect(atom.packages.getLoadedPackage('test2').activateKeymaps).toHaveBeenCalled()

  describe '::all-core', ->
    it 'returns a keymap', ->
      k = FixedMaps['all-core'] false
      expect(k.keymap).toBeDefined()
      expect(k.inherited).toBeUndefined()
      expect(k.execute).toBeUndefined()
      expect(k.keymap).toEqual {s1: k0: 'unset!'}

  describe '::custom', ->
    it 'returns a keymap', ->
      k = FixedMaps['custom'] false
      expect(k.keymap).toBeDefined()
      expect(k.inherited).toBeUndefined()
      expect(k.execute).toBeUndefined()
      expect(k.keymap).toEqual
        s0:
          k0: 'unset!'
          k1: 'unset!'
