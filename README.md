keybinding-mode
===============
[![Travis](https://img.shields.io/travis/deprint/keybinding-mode.svg?style=flat-square)](https://travis-ci.org/deprint/keybinding-mode) [![AppVeyor](https://img.shields.io/appveyor/ci/deprint/keybinding-mode.svg?style=flat-square)](https://ci.appveyor.com/project/deprint/keybinding-mode) [![Dependency Status](https://david-dm.org/deprint/keybinding-mode.svg?style=flat-square)](https://david-dm.org/deprint/keybinding-mode) [![apm](https://img.shields.io/apm/dm/keybinding-mode.svg?style=flat-square)](https://github.com/deprint/keybinding-mode) [![apm](https://img.shields.io/apm/v/keybinding-mode.svg?style=flat-square)](https://github.com/deprint/keybinding-mode)

### Switch keymaps easily

## HowTo
1. Open your keymode configuration with `keybinding-mode:open-config`.
2. Configure your keymaps.
3. Open your custom keymap with `application:open-your-keymap`.
4. Bind a key to `keybinding-mode:<KEYMAP-NAME>`, where `KEYMAP-NAME` is the name of a keymap in your keymode config file.
5. `window:reload` to load the new keybindings.
6. Load your keybinding-mode by pressing the key binding you have configured in step 4 or by executing `keybinding-mode:<KEYMAP-NAME>` manually through the command palette.

## Syntax

```coffee
'some-keymap':
  keymap:
    'atom-workspace':
      #...
'other-keymap':
  inherited: ['some-keymap', ...]
```

`inherited` is an array of strings and can be used to "import" other keymaps. The string can be ...

1. another keymap in your keymode config file or a keymap provided by another package.
2. `(+/-)user-packages` to enable/disable the keymap of all user packages.
3. `(+/-)core-packages` to enable/disable the keymap of all core packages.
4. `(+/-)all-core` to enable/disable all core keybindings.
5. `(+/-)custom` to enable/disable your custom keymap (this would also disable the keybinding you've set up for toggling the keymap!)
6. `-lower` to disable all lowercase letters.
7. `-upper` to disable all uppercase letters.
8. `-numbers` to disable 0-9 keys.
9. `(+/-)package-name` to enable/disable the keymap of `package-name`.
10. `(+/-)regexp` to filter all key bindings with a regular expression, for example:
  * `^ctrl-k` to disable all keybindings which begin with `ctrl-k`.
  * `^window:` to disable all keybindings whose commands begin with `window:`.
  * `.` to disable ALL keybindings.

Order when looking up keymode names:

1. Keymaps in your keybinding-mode config file.
2. Keymaps provided by other packages.
3. `user-packages`, `core-packages`, `all-core`, `custom`, `lower`, `upper`, `numbers`.
4. Package names.
5. Regular expressions.

## Service

Packages can provide their own keybinding-modes:

```JSON
"providedServices": {
  "keybinding-mode": {
    "versions": {
      "1.0.0": "provideKeybindingMode"
    }
  }
}
```

```coffee
provideKeybindingMode: ->
  name: 'my-package-name'
  modes:
    keymap1:
      keymap:
        'atom-workspace':
          #...
    keymap2: (op) ->
      execute: (reset = false) ->
        _op = op ^ reset
        if _op
          #Activate keymap
        else
          #Deactivate keymap
```

* `name`: Name of your package.
* Each key in `modes` is either a keybinding mode __object__ or a __function__ returning one.
* If the key is a __function__: If the keymap is included as `+keymap`, then `op` is `true` (`-keymap` is `false`).

Keybinding modes have the following keys (all keys are optional, but having none doesn't make sense):

* `keymap`: Static keymap.
* `inherited`: See above.
* `execute`: `execute()` is called when the keymap gets activated, `execute(true)` when disabled.
