keybinding-mode
===============
[![Travis](https://img.shields.io/travis/deprint/keybinding-mode.svg?style=flat-square)](https://travis-ci.org/deprint/keybinding-mode) [![AppVeyor](https://img.shields.io/appveyor/ci/deprint/keybinding-mode.svg?style=flat-square)](https://ci.appveyor.com/project/deprint/keybinding-mode) [![Dependency Status](https://david-dm.org/deprint/keybinding-mode.svg?style=flat-square)](https://david-dm.org/deprint/keybinding-mode) [![apm](https://img.shields.io/apm/dm/keybinding-mode.svg?style=flat-square)](https://github.com/deprint/keybinding-mode) [![apm](https://img.shields.io/apm/v/keybinding-mode.svg?style=flat-square)](https://github.com/deprint/keybinding-mode)

### Advanced keymap configuration in Atom

## HowTo
1. Open your keymode configuration with `keybinding-mode:open-advanced-keymap`.
2. Configure your keymaps. Bind keymaps to hotkeys (see [Hidden Keymaps](https://github.com/deprint/keybinding-mode/blob/master/README.md#hidden-keymaps)), etc.
3. `window:reload` or `keybinding-mode:reload`.

There can only be one keymap active at a time. To load a keymap at startup, see [Autostart](https://github.com/deprint/keybinding-mode/blob/master/README.md#autostart).

## Syntax

```coffee
'Simple Keymap':
  keymap:
    'atom-workspace':
      #...
'.Hidden Keymap':
  keymap:
    'atom-workspace':
      #...
'Include other keymaps': [
  'Simple Keymap'
  '.Hidden Keymap'
  keymap:
    'atom-workspace':
      #...
]
'Include all keymaps ending with -emacs': '~-emacs$'
'Disable keymaps of other packages': '-find-and-replace'
'Disable all keybindings that start with ctrl-k': '-k/^ctrl-k/'
'Move all alt- keybindings to ctrl-k': '-k/^alt-/ctrl-k /'
'!import': ['other-keymap.cson'] # Split your adv. keymap across multiple files
'!autostart': 'Simple Keymap' # Load 'Simple Keymap' at startup
```

### Static Keymaps

```coffee
'Static Keymap':
  keymap:
    'atom-workspace':
      #...
```

Static keymaps are objects with one key `keymap` which contains a custom keymap.

### Dynamic Keymaps

```coffee
'Dynamic Keymap': '-user-packages'
```

Dynamic keymaps are generated on the fly. If the dynamic keymap begins with `+`,
it adds the keymap. On `-`, it removes (`unset!`s) it. The following dynamic keymaps are
included in "vanilla keybinding-mode":

* `+/-user-packages` enables/disables the keymap of all user packages.
* `+/-core-packages` enables/disables the keymap of all core packages.
* `+/-all-core` enables/disables all core keybindings.
* `+/-custom` enables/disables your custom keymap.
* `-upper`, `-lower`, `-numbers` disables uppercase letters, lowercase letters and numbers in your text editor, but leaves mini editors untouched.
* `+/-package-name` enables/disables the keymap of package `package-name`.

`+/-user-packages`, `+/-core-packages` and `+/-package-name` load/remove package keymaps instead of `unset!`ing them.
To force these three modes to return a keymap, use `+!` and `-!`.

### Regular Expressions

```coffee
'Matching regular expression': '-k/^ctrl-k/'
'Replacing regular expression': '-k/^ctrl-k/ctrl-x/'
```

All regular expressions start with `+` or `-`, similar to dynamic keymaps.
The next character describes the property that we want to match:

* `k` for matching keybindings (like `ctrl-f`)
* `s` for matching selectors (like `atom-text-editor`)
* `c` for matching commands (like `core:move-right`)

Here, `/` is the separator. If you want to match `/` in your regular expression, choose a different separator.

The replacement string in substituting regular expressions can contain `$1`, `$2`, ... to work with capture groups.

A `+` substitution adds the replaced keybinding. A `-` substitution also `unset!`s the old one.

### Combined Filters

```coffee
'Merge multiple keymaps': ['-k/^ctrl-k/', '-find-and-replace']
'Filter keymaps': [
  [
    '+k/^ctrl-/'
    '-k/shift/'
    '-k/^ctrl-k/^ctrl-m/'
  ]
]
'Combined filters': [
  '-k/^ctrl-k/'
  [
    ['+k/^alt-/', '&', '+c/^editor:/']
    '-k/^alt-/ctrl-k /'
  ]
]
```

Combined filters have the form `[source filters+]`:

1. The parent filter's `source` is filtered through `source`.
2. Every `filter` filters `source` separately.
3. The keymaps from all `filters` are merged in order and returned.

In `Filter keymaps`, for example:

* `+k/^ctrl-/` matches all keybindings starting with `ctrl-`.
* `-k/shift/` `unset!`s all keybindings in `+k/^ctrl-/` that contain `shift`.
* `-k/^ctrl-k/^ctrl-m` moves all keybindings in `+k/^ctrl-/` that start with `ctrl-k` to `ctrl-m`

The outer array of a mode has a slightly different syntax, `[filters+]`.
If you execute the mode directly, `source` is implied to be `!all` ("All keybindings").
If the mode is loaded from another mode, `source` depends on the position of the include in said other mode.

If you want to chain multiple filters (`AND` them), use `[filter1, '&', filter2, '&', filter3, ...]`. If you only want to combine two filters, you can omit the `&`.

### Hidden Keymaps

```coffee
'.hello': #...
'world': ['.hello']
```

Visible keymaps (those that don't start with `.`) have a command
associated with them (`keybinding-mode:MODE-NAME`). You can toggle these keymaps through the command palette or by binding a key to it.
Hidden keymaps can only be included by other modes.

### Static Keymaps with regular expression

```coffee
emacs: ['~']
```

`~REGEX` includes all __static__ keybinding modes matching `REGEX`.

`~` without a regular expression matches `\.?NAME-`. In this example, all modes starting with `emacs-` would be matched. This also includes modes from other packages (that use the service interface) and is a simple way for other packages to provide alternate keymaps (e.g. for `emacs` users).

### Invert Keymaps

```coffee
'Disable keybindings that do not start with ctrl-k': ['!not', '-k/^ctrl-k/']
```

`['!not', filter]` returns all keybindings that did not pass `filter`. `filter` cannot be a substituting regular expression.

### Import other keymap files

```coffee
'!import': ['other.cson']
```

`!import` loads modes from all file paths in array (relative to the current file).

### Autostart

```coffee
'!autostart': 'emacs'
```

Activate mode at startup.

### Local keymaps

If your project contains a `.advanced-keybindings.cson`, it loads modes from that file at startup. `!autostart` in local keymaps override global `!autostart`.

### Service Interface

```json
"providedServices": {
  "keybinding-mode.modes": {
    "versions": {
      "1.0.0": "provideModes"
    }
  }
}
```

```coffee
provideModes: ->
  name: 'package-name'
  modes:
    'static-mode': [
      '!all'
      keymap:
        'atom-text-editor':
          #...
    ]
    'dynamic-mode': (op, sobj) ->
      #...
```

Packages can provide two types of modes:

* __Static__ modes can be used like your user-defined modes (with their name). Unlike user modes, you have to use the `['!all', ...]` construct.

* __Dynamic__ modes are functions that return a keybinding mode:

  * `op` is _true_(`+dynamic-mode`) or _false_(`-dynamic-mode`).

  ```coffee
    sobj =
      source
      getKeyBindings
      filter
      merge
      is_static: false
      flags:
        no_filter: false
        resolved: false
        not: false
  ```

  * `source` is either `!all` or `source.keymap` contains the current source keymap.

  * `getKeyBindings` returns the current source as an Array of `{keystrokes, command, selector}`.

  * `filter(dest, source, invert)` removes all keybindings from `dest` that are not in `source` (different commands are allowed). `invert = true` removes all keybindings from `dest` that are in `source`.

  * `merge(dest, source)` merges the keymap of `source` into `dest`

  * `is_static` should stay _false_, but you can set it to _true_ to cache the returned keymap.

  * `no_filter` should be set to _true_ if you use `filter` or `getKeyBindings`.

  * `resolved` should be _true_ if you return an object containing a `keymap` and optionally an `execute` function (see below).

  * `not` is the `invert` argument of the internal filter. Only works if `no_filter` is _false_.

  * Dynamic modes return the same values as your user-defined ones, with one exception:
  Along with `keymap`, you can also return an `execute(reset = false)` function, which is called with _true_ on deactivation.

These modes do __not__ get their own commands, it is up to the user to include them in his advanced keymap.
