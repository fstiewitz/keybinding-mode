db = require '../lib/keymode-db'
extensions = require '../lib/extensions'
_not = require '../lib/not'

path = require 'path'

results = null

equals = (got, exp) ->
  for k in Object.keys got
    expect(exp[k]).toBeDefined()
    if exp[k]?
      for k2 in Object.keys got[k]
        expect("#{k}.#{k2}:#{got[k][k2]}").toBe "#{k}.#{k2}:#{exp[k]?[k2]}"

describe 'Keymode DB', ->
  disp = null

  beforeEach ->
    results ?= require('season').readFileSync path.join(atom.project.getPaths()[0], 'results.cson')
    db.activate()
    disp = extensions.consume _not

  afterEach ->
    disp.dispose()
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
          a: 1
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
    it 'inverted keymaps', ->
      a = keymap:
        a:
          a: 1
          c: 1
      b = keymap:
        a:
          a: 1
          b: 2
          c: 2
        b:
          d: 3
      db.filter a, b, true
      expect(a.keymap).toEqual
        a:
          b: 2
        b:
          d: 3

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
      db.modes['test2'] = inherited: ['!all', '-numbers', 'test1']
      m = db.resolve 'test2'
      expect(m.keymap).toEqual
        'body':
          0: 'no-command'
          1: 'no-command'
          2: 'no-command'
          3: 'no-command'
          4: 'no-command'
          5: 'no-command'
          6: 'no-command'
          7: 'no-command'
          8: 'no-command'
          9: 'no-command'
        'atom-workspace atom-text-editor[mini]':
          0: 'native!'
          1: 'native!'
          2: 'native!'
          3: 'native!'
          4: 'native!'
          5: 'native!'
          6: 'native!'
          7: 'native!'
          8: 'native!'
          9: 'native!'
        a:
          b: 'c'
        'atom-text-editor:not(.mini)':
          0: 'd'
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
          'ctrl-u ctrl-k': 'pane:split-up-and-copy-active-item'
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
          'ctrl-u ctrl-k': 'pane:split-up-and-copy-active-item'
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

    it 'patterns', ->
      db.modes['test1'] = inherited: [
        '!all'
        keymap:
          'atom-text-editor':
            'ctrl-f': 'foo'
      ]
      db.modes['test2'] = inherited: [
        '!all'
        keymap:
          'atom-text-editor':
            'ctrl-j': 'bar'
      ]
      db.modes['test3'] = inherited: [
        '!all'
        '~\\d+$'
      ]
      db.names = ['test2']
      m = db.resolve 'test3'
      expect(m.keymap).toEqual
        'atom-text-editor':
          'ctrl-j': 'bar'

    it 'already resolved', ->
      db.modes['test1'] = inherited: [
        '!all'
        keymap:
          'atom-text-editor':
            'ctrl-f': 'foo'
      ]
      m = db.resolveWithTest 'test1'
      expect(m.resolved).toBe true
      db.modes['test1'].inherited = ['!all', '-']
      n = db.resolveWithTest 'test1'
      expect(n.keymap).toEqual
        'atom-text-editor':
          'ctrl-f': 'foo'

    it 'dynamic resolved', ->
      db.modes['test1'] = inherited: [
        '!all'
        '-k/^ctrl-f/'
        '+s/body \.native-key-bindings/'
        'test2'
      ]
      db.modes['test2'] = inherited: [
        keymap:
          'atom-text-editor':
            'ctrl-f': 'foo'
      ]
      m = db.resolveWithTest 'test1'
      expect(m.resolved).toBe false
      db.modes['test1'].inherited = ['!all', keymap:
        'atom-text-editor':
          'ctrl-f': 'bar'
      ]
      n = db.resolveWithTest 'test1'
      expect(n.keymap).toEqual
        'atom-text-editor':
          'ctrl-f': 'bar'

    it '!not', ->
      db.modes['test1'] = inherited: [
        '!all'
        ['+k/^alt-/', ['!not', '-c/editor:/']]
        '+s/native-key-bindings/'
      ]
      m = db.resolveWithTest 'test1'
      expect(m.keymap).toEqual
        body:
          'alt-1': 'unset!'
          'alt-2': 'unset!'
          'alt-3': 'unset!'
          'alt-4': 'unset!'
          'alt-5': 'unset!'
          'alt-6': 'unset!'
          'alt-7': 'unset!'
          'alt-8': 'unset!'
          'alt-9': 'unset!'

  describe '::reload', ->

    beforeEach ->
      waitsForPromise -> db.reload path.join(atom.project.getPaths()[0], 'syntax.cson')

    it 'loads the keymode config', ->
      expect(db.modes.simple_emacs).toBeDefined()
      expect(db.modes.import_keymap).toBeDefined()
      expect(db.modes.dynamic_keymaps).toBeDefined()
      expect(db.modes['.german_layout']).toBeDefined()
      expect(db.modes.localize_emacs).toBeDefined()
      expect(db.modes.unctrl_all).toBeDefined()
      expect(db.modes.unctrl_fold).toBeDefined()
      expect(db.modes['my-a']).toBeDefined()
      expect(db.modes['my-b']).toBeDefined()

    it 'loads commands', ->
      m = atom.commands.getSnapshot()
      expect(m['keybinding-mode:simple_emacs']).toBeDefined()
      expect(m['keybinding-mode:import_keymap']).toBeDefined()
      expect(m['keybinding-mode:dynamic_keymaps']).toBeDefined()
      expect(m['keybinding-mode:localize_emacs']).toBeDefined()
      expect(m['keybinding-mode:unctrl_all']).toBeDefined()
      expect(m['keybinding-mode:unctrl_fold']).toBeDefined()
      expect(m['keybinding-mode:my-a']).toBeDefined()
      expect(m['keybinding-mode:my-b']).toBeDefined()
      expect(m['keybinding-mode:.german-layout']).toBeUndefined()

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
      equals m.keymap, results.dynamic_keymaps

    it 'german_layout', ->
      m = db.resolveWithTest '.german_layout'
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

    it 'unctrl_all', ->
      m = db.resolveWithTest 'unctrl_all'
      expect(m).toBeDefined()
      equals m.keymap, results.unctrl_all

    it 'unctrl_fold', ->
      m = db.resolveWithTest 'unctrl_fold'
      expect(m).toBeDefined()
      equals m.keymap, results.unctrl_fold

    it 'my-a', ->
      m = db.resolveWithTest 'my-a'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        'atom-text-editor':
          'alt-f': 'foo'

    it 'my-b', ->
      m = db.resolveWithTest 'my-b'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        'atom-text-editor':
          'alt-f': 'foo'
          'alt-p': 'bar'
