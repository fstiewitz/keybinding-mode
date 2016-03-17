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

    it 'unctrl_all', ->
      m = db.resolveWithTest 'unctrl_all'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        'atom-text-editor:not(.mini)':
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
          A: 'abort!'
          B: 'abort!'
          C: 'abort!'
          D: 'abort!'
          E: 'abort!'
          F: 'abort!'
          G: 'abort!'
          H: 'abort!'
          I: 'abort!'
          J: 'abort!'
          K: 'abort!'
          L: 'abort!'
          M: 'abort!'
          N: 'abort!'
          O: 'abort!'
          P: 'abort!'
          Q: 'abort!'
          R: 'abort!'
          S: 'abort!'
          T: 'abort!'
          U: 'abort!'
          V: 'abort!'
          W: 'abort!'
          X: 'abort!'
          Y: 'abort!'
          Z: 'abort!'
          a: 'abort!'
          b: 'abort!'
          c: 'abort!'
          d: 'abort!'
          e: 'abort!'
          f: 'abort!'
          g: 'abort!'
          h: 'abort!'
          i: 'abort!'
          j: 'abort!'
          k: 'abort!'
          l: 'abort!'
          m: 'abort!'
          n: 'abort!'
          o: 'abort!'
          p: 'abort!'
          q: 'abort!'
          r: 'abort!'
          s: 'abort!'
          t: 'abort!'
          u: 'abort!'
          v: 'abort!'
          w: 'abort!'
          x: 'abort!'
          y: 'abort!'
          z: 'abort!'
        'atom-text-editor:not([mini])':
          'ctrl-shift-C': 'unset!'
          'ctrl-shift-K': 'unset!'
          'shift-C': 'editor:copy-path'
          'shift-K': 'editor:delete-line'
        'body .native-key-bindings':
          'ctrl-up': 'unset!'
          'ctrl-down': 'unset!'
          'ctrl-shift-up': 'unset!'
          'ctrl-shift-down': 'unset!'
          'ctrl-left': 'unset!'
          'ctrl-right': 'unset!'
          'ctrl-shift-left': 'unset!'
          'ctrl-shift-right': 'unset!'
          'ctrl-b': 'unset!'
          'ctrl-f': 'unset!'
          'ctrl-shift-F': 'unset!'
          'ctrl-shift-B': 'unset!'
          'ctrl-h': 'unset!'
          'ctrl-d': 'unset!'
          'ctrl-z': 'unset!'
          'ctrl-shift-Z': 'unset!'
          'ctrl-x': 'unset!'
          'ctrl-c': 'unset!'
          'ctrl-v': 'unset!'
          up: 'native!'
          down: 'native!'
          'shift-up': 'native!'
          'shift-down': 'native!'
          left: 'native!'
          right: 'native!'
          'shift-left': 'native!'
          'shift-right': 'native!'
          b: 'native!'
          f: 'native!'
          'shift-F': 'native!'
          'shift-B': 'native!'
          h: 'native!'
          d: 'native!'
          z: 'native!'
          'shift-Z': 'native!'
          x: 'native!'
          c: 'native!'
          v: 'native!'
        'atom-text-editor':
          'ctrl-alt-f': 'unset!'
          'ctrl-alt-shift-F': 'unset!'
          'ctrl-alt-b': 'unset!'
          'ctrl-alt-shift-B': 'unset!'
          'ctrl-alt-h': 'unset!'
          'ctrl-alt-d': 'unset!'
          'alt-f': 'editor:move-to-next-subword-boundary'
          'alt-shift-F': 'editor:select-to-next-subword-boundary'
          'alt-b': 'editor:move-to-previous-subword-boundary'
          'alt-shift-B': 'editor:select-to-previous-subword-boundary'
          'alt-h': 'editor:delete-to-beginning-of-subword'
          'alt-d': 'editor:delete-to-end-of-subword'
        body:
          '0': 'window:reset-font-size'
          'ctrl-alt-r': 'unset!'
          'ctrl-shift-I': 'unset!'
          'ctrl-alt-p': 'unset!'
          'ctrl-shift-O': 'unset!'
          'ctrl-alt-o': 'unset!'
          'ctrl-shift-pageup': 'unset!'
          'ctrl-shift-pagedown': 'unset!'
          'ctrl-,': 'unset!'
          'ctrl-shift-N': 'unset!'
          'ctrl-shift-W': 'unset!'
          'ctrl-o': 'unset!'
          'ctrl-q': 'unset!'
          'ctrl-shift-T': 'unset!'
          'ctrl-n': 'unset!'
          'ctrl-s': 'unset!'
          'ctrl-shift-S': 'unset!'
          'ctrl-w': 'unset!'
          'ctrl-z': 'unset!'
          'ctrl-y': 'unset!'
          'ctrl-shift-Z': 'unset!'
          'ctrl-x': 'unset!'
          'ctrl-c': 'unset!'
          'ctrl-v': 'unset!'
          'ctrl-insert': 'unset!'
          'ctrl-tab': 'unset!'
          'ctrl-shift-tab': 'unset!'
          'ctrl-pageup': 'unset!'
          'ctrl-pagedown': 'unset!'
          'ctrl-up': 'unset!'
          'ctrl-down': 'unset!'
          'ctrl-shift-up': 'unset!'
          'ctrl-shift-down': 'unset!'
          'ctrl-=': 'unset!'
          'ctrl-+': 'unset!'
          'ctrl--': 'unset!'
          'ctrl-_': 'unset!'
          'ctrl-0': 'unset!'
          'ctrl-k up': 'unset!'
          'ctrl-k down': 'unset!'
          'ctrl-k left': 'unset!'
          'ctrl-k right': 'unset!'
          'ctrl-k ctrl-w': 'unset!'
          'ctrl-k ctrl-alt-w': 'unset!'
          'ctrl-k ctrl-p': 'unset!'
          'ctrl-k ctrl-n': 'unset!'
          'ctrl-k ctrl-up': 'unset!'
          'ctrl-k ctrl-down': 'unset!'
          'ctrl-k ctrl-left': 'unset!'
          'ctrl-k ctrl-right': 'unset!'
          'alt-r': 'window:reload'
          'shift-I': 'window:toggle-dev-tools'
          'alt-p': 'window:run-package-specs'
          'shift-O': 'application:open-folder'
          'alt-o': 'application:add-project-folder'
          'shift-pageup': 'pane:move-item-left'
          'shift-pagedown': 'pane:move-item-right'
          ',': 'application:show-settings'
          'shift-N': 'application:new-window'
          'shift-W': 'window:close'
          o: 'application:open-file'
          q: 'application:quit'
          'shift-T': 'pane:reopen-closed-item'
          n: 'application:new-file'
          s: 'core:save'
          'shift-S': 'core:save-as'
          w: 'core:close'
          z: 'core:undo'
          y: 'core:redo'
          'shift-Z': 'core:redo'
          x: 'core:cut'
          c: 'core:copy'
          v: 'core:paste'
          insert: 'core:copy'
          tab: 'pane:show-next-item'
          'shift-tab': 'pane:show-previous-item'
          pageup: 'pane:show-previous-item'
          pagedown: 'pane:show-next-item'
          up: 'core:move-up'
          down: 'core:move-down'
          'shift-up': 'core:move-up'
          'shift-down': 'core:move-down'
          '=': 'window:increase-font-size'
          '+': 'window:increase-font-size'
          '-': 'window:decrease-font-size'
          _: 'window:decrease-font-size'
          'k up': 'pane:split-up'
          'k down': 'pane:split-down'
          'k left': 'pane:split-left'
          'k right': 'pane:split-right'
          'k ctrl-w': 'pane:close'
          'k ctrl-alt-w': 'pane:close-other-items'
          'k ctrl-p': 'window:focus-previous-pane'
          'k ctrl-n': 'window:focus-next-pane'
          'k ctrl-up': 'window:focus-pane-above'
          'k ctrl-down': 'window:focus-pane-below'
          'k ctrl-left': 'window:focus-pane-on-left'
          'k ctrl-right': 'window:focus-pane-on-right'
        'atom-workspace atom-text-editor':
          'ctrl-left': 'unset!'
          'ctrl-right': 'unset!'
          'ctrl-shift-left': 'unset!'
          'ctrl-shift-right': 'unset!'
          'ctrl-backspace': 'unset!'
          'ctrl-delete': 'unset!'
          'ctrl-home': 'unset!'
          'ctrl-end': 'unset!'
          'ctrl-shift-home': 'unset!'
          'ctrl-shift-end': 'unset!'
          'ctrl-a': 'unset!'
          'ctrl-alt-shift-P': 'unset!'
          'ctrl-k ctrl-u': 'unset!'
          'ctrl-k ctrl-l': 'unset!'
          'ctrl-l': 'unset!'
          left: 'editor:move-to-beginning-of-word'
          right: 'editor:move-to-end-of-word'
          'shift-left': 'editor:select-to-beginning-of-word'
          'shift-right': 'editor:select-to-end-of-word'
          backspace: 'editor:delete-to-beginning-of-word'
          delete: 'editor:delete-to-end-of-word'
          home: 'core:move-to-top'
          end: 'core:move-to-bottom'
          'shift-home': 'core:select-to-top'
          'shift-end': 'core:select-to-bottom'
          a: 'core:select-all'
          'alt-shift-P': 'editor:log-cursor-scope'
          'k ctrl-u': 'editor:upper-case'
          'k ctrl-l': 'editor:lower-case'
          l: 'editor:select-line'
        'atom-workspace atom-text-editor:not([mini])':
          'ctrl-alt-z': 'unset!'
          'ctrl-<': 'unset!'
          'ctrl-alt-f': 'unset!'
          'ctrl-enter': 'unset!'
          'ctrl-shift-enter': 'unset!'
          'ctrl-]': 'unset!'
          'ctrl-[': 'unset!'
          'ctrl-up': 'unset!'
          'ctrl-down': 'unset!'
          'ctrl-/': 'unset!'
          'ctrl-j': 'unset!'
          'ctrl-shift-D': 'unset!'
          'ctrl-alt-[': 'unset!'
          'ctrl-alt-]': 'unset!'
          'ctrl-alt-{': 'unset!'
          'ctrl-alt-}': 'unset!'
          'ctrl-k ctrl-0': 'unset!'
          'ctrl-k ctrl-1': 'unset!'
          'ctrl-k ctrl-2': 'unset!'
          'ctrl-k ctrl-3': 'unset!'
          'ctrl-k ctrl-4': 'unset!'
          'ctrl-k ctrl-5': 'unset!'
          'ctrl-k ctrl-6': 'unset!'
          'ctrl-k ctrl-7': 'unset!'
          'ctrl-k ctrl-8': 'unset!'
          'ctrl-k ctrl-9': 'unset!'
          'alt-z': 'editor:checkout-head-revision'
          '<': 'editor:scroll-to-cursor'
          'alt-f': 'editor:fold-selection'
          enter: 'editor:newline-below'
          'shift-enter': 'editor:newline-above'
          ']': 'editor:indent-selected-rows'
          '[': 'editor:outdent-selected-rows'
          up: 'editor:move-line-up'
          down: 'editor:move-line-down'
          '/': 'editor:toggle-line-comments'
          j: 'editor:join-lines'
          'shift-D': 'editor:duplicate-lines'
          'alt-[': 'editor:fold-current-row'
          'alt-]': 'editor:unfold-current-row'
          'alt-{': 'editor:fold-all'
          'alt-}': 'editor:unfold-all'
          'k ctrl-0': 'editor:unfold-all'
          'k ctrl-1': 'editor:fold-at-indent-level-1'
          'k ctrl-2': 'editor:fold-at-indent-level-2'
          'k ctrl-3': 'editor:fold-at-indent-level-3'
          'k ctrl-4': 'editor:fold-at-indent-level-4'
          'k ctrl-5': 'editor:fold-at-indent-level-5'
          'k ctrl-6': 'editor:fold-at-indent-level-6'
          'k ctrl-7': 'editor:fold-at-indent-level-7'
          'k ctrl-8': 'editor:fold-at-indent-level-8'
          'k ctrl-9': 'editor:fold-at-indent-level-9'
        'atom-workspace atom-pane':
          'ctrl-alt-=': 'unset!'
          'ctrl-alt--': 'unset!'
          'alt-=': 'pane:increase-size'
          'alt--': 'pane:decrease-size'

    it 'unctrl_fold', ->
      m = db.resolveWithTest 'unctrl_fold'
      expect(m).toBeDefined()
      expect(m.keymap).toEqual
        'atom-text-editor:not(.mini)':
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
          A: 'abort!'
          B: 'abort!'
          C: 'abort!'
          D: 'abort!'
          E: 'abort!'
          F: 'abort!'
          G: 'abort!'
          H: 'abort!'
          I: 'abort!'
          J: 'abort!'
          K: 'abort!'
          L: 'abort!'
          M: 'abort!'
          N: 'abort!'
          O: 'abort!'
          P: 'abort!'
          Q: 'abort!'
          R: 'abort!'
          S: 'abort!'
          T: 'abort!'
          U: 'abort!'
          V: 'abort!'
          W: 'abort!'
          X: 'abort!'
          Y: 'abort!'
          Z: 'abort!'
          a: 'abort!'
          b: 'abort!'
          c: 'abort!'
          d: 'abort!'
          e: 'abort!'
          f: 'abort!'
          g: 'abort!'
          h: 'abort!'
          i: 'abort!'
          j: 'abort!'
          k: 'abort!'
          l: 'abort!'
          m: 'abort!'
          n: 'abort!'
          o: 'abort!'
          p: 'abort!'
          q: 'abort!'
          r: 'abort!'
          s: 'abort!'
          t: 'abort!'
          u: 'abort!'
          v: 'abort!'
          w: 'abort!'
          x: 'abort!'
          y: 'abort!'
          z: 'abort!'
        'atom-workspace atom-text-editor:not([mini])':
          'ctrl-k ctrl-1': 'unset!'
          'ctrl-k ctrl-2': 'unset!'
          'ctrl-k ctrl-3': 'unset!'
          'ctrl-k ctrl-4': 'unset!'
          'ctrl-k ctrl-5': 'unset!'
          'ctrl-k ctrl-6': 'unset!'
          'ctrl-k ctrl-7': 'unset!'
          'ctrl-k ctrl-8': 'unset!'
          'ctrl-k ctrl-9': 'unset!'
          'k ctrl-1': 'editor:fold-at-indent-level-1'
          'k ctrl-2': 'editor:fold-at-indent-level-2'
          'k ctrl-3': 'editor:fold-at-indent-level-3'
          'k ctrl-4': 'editor:fold-at-indent-level-4'
          'k ctrl-5': 'editor:fold-at-indent-level-5'
          'k ctrl-6': 'editor:fold-at-indent-level-6'
          'k ctrl-7': 'editor:fold-at-indent-level-7'
          'k ctrl-8': 'editor:fold-at-indent-level-8'
          'k ctrl-9': 'editor:fold-at-indent-level-9'