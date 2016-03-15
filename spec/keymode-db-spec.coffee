db = require '../lib/keymode-db'

path = require 'path'

describe 'Keymode DB', ->

  beforeEach ->
    db.activate()

  afterEach ->
    db.deactivate()

  describe '::dryRun', ->
    describe 'on single keymap', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited:
            keymap:
              'atom-text-editor':
                'ctrl-f': 'find-and-replace:toggle'
        expect(db.dryRun 'test').toBe true

    describe 'on single keymap - expected fail', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            {
              'atom-text-editor':
                'ctrl-f': 'find-and-replace:toggle'
            }
          ]
        expect(db.dryRun 'test').toBe false

    describe 'on parallel filters', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '-upper', '-lower', '-numbers'
          ]
        expect(db.dryRun 'test').toBe true

    describe 'on parallel filters - expected fail 1', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '-upper', '-lower', ['-numbers']
          ]
        expect(db.dryRun 'test').toBe false

    describe 'on parallel filters - expected fail 2', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '-upper', '-lower', []
          ]
        expect(db.dryRun 'test').toBe false

    describe 'on parallel filters with explicit source', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '!all'
            [
              '+k/ctrl-/'
              '-'
            ]
          ]
        expect(db.dryRun 'test').toBe true

    describe 'on parallel filters with explicit source - expected fail', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            [
              '+k/ctrl-/'
            ]
          ]
        expect(db.dryRun 'test').toBe false

    describe 'on nested filters with regular expressions - 1', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '-upper', '-lower', '-numbers'
            [
              ['!', 'key', '^ctrl-']
              '-'
              ['!', 'key', '^ctrl-', '']
            ]
          ]
        expect(db.dryRun 'test').toBe true

    describe 'on nested filters with regular expressions - expected fail 1', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '-upper', '-lower', '-numbers'
            [
              ['!', 'k', '^ctrl-']
              '-'
              ['!', 'key', '^ctrl-', '']
            ]
          ]
        expect(db.dryRun 'test').toBe false

    describe 'on nested filters with regular expressions - 2', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '-upper', '-lower', '-numbers'
            ['!-', 'key', '^ctrl-']
          ]
        expect(db.dryRun 'test').toBe true

    describe 'on nested filters with regular expressions - 3', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '-upper', '-lower', '-numbers'
            [
              '+k/^ctrl-/'
              '-'
              '+k/^ctrl-//'
            ]
          ]
        expect(db.dryRun 'test').toBe true

    describe 'on nested filters with regular expressions - expected fail 2', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '-upper', '-lower', '-numbers'
            [
              '+t/^ctrl-/'
              '-'
              '+k/^ctrl-//'
            ]
          ]
        expect(db.dryRun 'test').toBe false

    describe 'on nested filters with explicit source and alternate syntax', ->
      it 'returns the keymap', ->
        db.modes['test'] =
          inherited: [
            '!all'
            [
              {
                keymap:
                  'atom-text-editor':
                    'ctrl-f': 'core:move-right'
                    'ctrl-b': 'core:move-left'
                    'ctrl-p': 'core:move-up'
                    'ctrl-n': 'core:move-down'
                    'ctrl-e': 'editor:move-to-end-of-screen-line'
                    'ctrl-a': 'editor:move-to-beginning-of-screen-line'
              }
              ['-numbers', '&', ['!', 'key', '^ctrl-']]
            ]
          ]
        expect(db.dryRun 'test').toBe true

  describe '::merge', ->
    it 'source is !all', ->
      m = keymap: 1
      db.merge m, '!all'
      expect(m.keymap).toBe 1
    it 'source is null', ->
      m = keymap: 1
      db.merge m, undefined
      expect(m.keymap).toBe 1
    it 'both keymaps given', ->
      a = keymap:
        a:
          a: 1
          b: 2
      b = keymap:
        a:
          a: 2
          c: 1
      db.merge b, a
      expect(b.keymap).toEqual
        a:
          a: 2
          c: 1
          b: 2
    it 'source execute given', ->
      a = {execute: jasmine.createSpy('source')}
      b = {}
      db.merge b, a
      expect(b.execute).toBeDefined()
      b.execute(1)
      expect(a.execute).toHaveBeenCalledWith 1
    it 'dest execute given', ->
      a = {execute: jasmine.createSpy('source')}
      b = {}
      db.merge a, b
      expect(a.execute).toBeDefined()
      a.execute(1)
      expect(a.execute).toHaveBeenCalledWith 1
    it 'source and execute given', ->
      a = {execute: jasmine.createSpy('source')}
      s = jasmine.createSpy('dest')
      b = {execute: s}
      db.merge b, a
      expect(b.execute).toBeDefined()
      b.execute(1)
      expect(a.execute).toHaveBeenCalledWith 1
      expect(s).toHaveBeenCalledWith 1

  describe '::filter', ->
    it 'source is !all', ->
      m = keymap: 1
      db.filter m, '!all'
      expect(m.keymap).toBe 1
    it 'both keymaps given', ->
      a = keymap:
        a:
          a: 1
          c: 1
      b = keymap:
        a:
          a: 1
          b: 2
          c: 2
      db.filter b, a
      expect(b.keymap).toEqual
        a:
          a: 1
          c: 2

  describe '::resolve', ->
    it 'simple keymap', ->
      db.modes['test1'] = inherited: [
        keymap:
          a:
            b: 'c'
      ]
      m = db.resolve 'test1'
      expect(m.keymap).toEqual a: b: 'c'
    it 'simple import', ->
      db.modes['test1'] = inherited: [
        keymap:
          a:
            b: 'c'
      ]
      db.modes['test2'] = inherited: ['!all', 'test1']
      m = db.resolve 'test2'
      expect(m.keymap).toEqual a: b: 'c'
    it 'import + -numbers', ->
      db.modes['test1'] = inherited: [
        keymap:
          a:
            b: 'c'
          'atom-text-editor:not(.mini)':
            '0': 'd'
      ]
      db.modes['test2'] = inherited: ['!all', 'test1', '-numbers']
      m = db.resolve 'test2'
      expect(m.keymap).toEqual
        a:
          b: 'c'
        'atom-text-editor:not(.mini)':
          0: 'd'
          1: 'abort!'
          2: 'abort!'
          3: 'abort!'
          4: 'abort!'
          5: 'abort!'
          6: 'abort!'
          7: 'abort!'
          8: 'abort!'
          9: 'abort!'
    it 'import + regular expression', ->
      db.modes['test1'] = inherited: [
        keymap:
          a:
            b: 'c'
      ]
      db.modes['test2'] = inherited: ['!all', 'test1', '-k/^(.+?) up/ctrl-u $1/']
      m = db.resolve 'test2'
      expect(m.keymap).toEqual
        a:
          b: 'c'
        'body':
          'ctrl-k up': 'unset!'
          'ctrl-u ctrl-k': 'pane:split-up'
    it 'combined merge (import + regular expression)', ->
      db.modes['test1'] = inherited: [
        keymap:
          a:
            b: 'c'
      ]
      db.modes['test2'] = inherited: ['!all', ['test1', '|', '-k/^(.+?) up/ctrl-u $1/']]
      m = db.resolve 'test2'
      expect(m.keymap).toEqual
        a:
          b: 'c'
        'body':
          'ctrl-k up': 'unset!'
          'ctrl-u ctrl-k': 'pane:split-up'
    it 'combined filter (regular expression + import)', ->
      db.modes['test1'] = inherited: ['!all', ['-k/^ctrl-//', '&', '+k/ctrl-8/']]
      m = db.resolve 'test1'
      expect(m.keymap).toEqual
        'atom-workspace atom-text-editor:not([mini])':
          'ctrl-k ctrl-8': 'unset!'
          'k ctrl-8': 'editor:fold-at-indent-level-8'

    it 'plus and replace', ->
      db.modes['test1'] = inherited: [
        '!all'
        [
          '+k/ctrl-8/'
          '+'
          '+k/^ctrl-//'
        ]
      ]
      m = db.resolve 'test1'
      expect(m.keymap).toEqual
        'atom-workspace atom-text-editor:not([mini])':
          'ctrl-k ctrl-8': 'editor:fold-at-indent-level-8'
          'k ctrl-8': 'editor:fold-at-indent-level-8'
    it 'minus and replace', ->
      db.modes['test1'] = inherited: [
        '!all'
        [
          '+k/ctrl-8/'
          '-'
          '+k/^ctrl-//'
        ]
      ]
      m = db.resolve 'test1'
      expect(m.keymap).toEqual
        'atom-workspace atom-text-editor:not([mini])':
          'ctrl-k ctrl-8': 'unset!'
          'k ctrl-8': 'editor:fold-at-indent-level-8'

  describe '::reload', ->

    beforeEach ->
      waitsForPromise -> db.reload path.join(atom.project.getPaths()[0], 'syntax.cson')

    it 'loads the keymode config', ->
      expect(db.modes.simple_emacs).toBeDefined()
      expect(db.modes.import_keymap).toBeDefined()
      expect(db.modes.dynamic_keymaps).toBeDefined()
      expect(db.modes.german_layout).toBeDefined()
      expect(db.modes.localize_emacs).toBeDefined()
      expect(db.modes.unctrl_all).toBeDefined()
      expect(db.modes.unctrl_fold).toBeDefined()

    it 'simple_emacs', ->
      m = db.resolveWithTest 'simple_emacs'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        'atom-text-editor':
          'ctrl-f': 'core:move-right'
          'ctrl-b': 'core:move-left'
          'ctrl-n': 'core:move-down'
          'ctrl-p': 'core:move-up'

    it 'import_keymap', ->
      m = db.resolveWithTest 'import_keymap'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        'atom-text-editor':
          'ctrl-f': 'core:move-right'
          'ctrl-b': 'core:move-left'
          'ctrl-n': 'core:move-down'
          'ctrl-p': 'core:move-up'
          'ctrl-s': 'find-and-replace:toggle'

    it 'dynamic_keymaps', ->
      m = db.resolveWithTest 'dynamic_keymaps'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        'atom-text-editor:not(.mini)':
          'a': 'abort!'
          'b': 'abort!'
          'c': 'abort!'
          'd': 'abort!'
          'e': 'abort!'
          'f': 'abort!'
          'g': 'abort!'
          'h': 'abort!'
          'i': 'abort!'
          'j': 'abort!'
          'k': 'abort!'
          'l': 'abort!'
          'm': 'abort!'
          'n': 'abort!'
          'o': 'abort!'
          'p': 'abort!'
          'q': 'abort!'
          'r': 'abort!'
          's': 'abort!'
          't': 'abort!'
          'u': 'abort!'
          'v': 'abort!'
          'w': 'abort!'
          'x': 'abort!'
          'y': 'abort!'
          'z': 'abort!'
          'A': 'abort!'
          'B': 'abort!'
          'C': 'abort!'
          'D': 'abort!'
          'E': 'abort!'
          'F': 'abort!'
          'G': 'abort!'
          'H': 'abort!'
          'I': 'abort!'
          'J': 'abort!'
          'K': 'abort!'
          'L': 'abort!'
          'M': 'abort!'
          'N': 'abort!'
          'O': 'abort!'
          'P': 'abort!'
          'Q': 'abort!'
          'R': 'abort!'
          'S': 'abort!'
          'T': 'abort!'
          'U': 'abort!'
          'V': 'abort!'
          'W': 'abort!'
          'X': 'abort!'
          'Y': 'abort!'
          'Z': 'abort!'
          '0': 'abort!'
          '1': 'abort!'
          '2': 'abort!'
          '3': 'abort!'
          '4': 'abort!'
          '5': 'abort!'
          '6': 'abort!'
          '7': 'abort!'
          '8': 'abort!'
          '9': 'abort!'

    it 'german_layout', ->
      m = db.resolveWithTest 'german_layout'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        body:
          'ctrl-z': 'core:redo'
          'ctrl-y': 'core:undo'
        'atom-workspace atom-text-editor:not([mini])':
          'ctrl-alt-y': 'editor:checkout-head-revision'
        'body .native-key-bindings':
          'ctrl-y': 'native!'

    it 'localize_emacs', ->
      m = db.resolveWithTest 'localize_emacs'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        'atom-text-editor':
          'ctrl-f': 'core:move-right'
          'ctrl-b': 'core:move-left'
          'ctrl-n': 'core:move-down'
          'ctrl-p': 'core:move-up'
