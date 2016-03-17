{CompositeDisposable} = require 'atom'

kdb = require './keymode-db'

serviceMaps = null

path = require 'path'

module.exports = KeybindingMode =
  subscriptions: null

  activate: (state) ->
    kdb.activate()
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'keybinding-mode:open-config': ->
      atom.workspace.open(path.join(path.dirname(atom.config.getUserConfigPath()), 'keybinding-mode.cson'))
    @subscriptions.add atom.commands.add 'atom-workspace', 'keybinding-mode:reload': -> kdb.reload()
    @subscriptions.add atom.packages.onDidActivateInitialPackages -> kdb.reload()
    @subscriptions.add kdb.onReload =>
      @keybindingElement?.innerText = 'default'
    @subscriptions.add kdb.onDeactivate =>
      @keybindingElement?.innerText = 'default'
    @subscriptions.add kdb.onActivate (name) =>
      @keybindingElement?.innerText = name

  deactivate: ->
    @subscriptions.dispose()
    kdb.deactivate()
    @statusBarTile?.destroy()
    @keybindingElement = null
    @statusBarTile = null

  consumeKeybindingMode: (o) ->
    (serviceMaps ? serviceMaps = require './service_maps').consume o

  consumeStatusBar: (statusBar) ->
    element = document.createElement 'div'
    element.className = 'inline-block keybinding-mode'
    icon = document.createElement 'span'
    icon.className = 'icon icon-keyboard'
    @keybindingElement = document.createElement 'span'
    element.appendChild icon
    element.appendChild @keybindingElement
    @statusBarTile = statusBar.addRightTile item: element, priority: 50
    @keybindingElement.innerText = 'default'
