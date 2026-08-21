import QtQuick
import qs.Commons
import qs.Ui

// A lightweight, instant-access Omarchy status bar widget.
// The popout panel handles network retrieval on demand, keeping bar startup
// instant and independent of network reachability.
BarWidget {
  id: root
  moduleName: "miguel.matchday"

  // Shape contract for shell.summon/hide/toggle routing
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  // Glanceable state for the bar badge and tooltip
  readonly property bool favoriteLive: panelLoader.item ? panelLoader.item.favoriteTeamLive === true : false
  readonly property string favoriteSummary: panelLoader.item ? panelLoader.item.favoriteSummaryText : ""
  readonly property int liveCount: panelLoader.item ? (panelLoader.item.liveCount || 0) : 0

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    var item = panelLoader.item
    if (!item) return
    if (item.openFromHotkey) item.openFromHotkey()
    else if (item.open) item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
      panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "⚽"
    active: root.opened

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton) root.open()
    }
  }

  // Live match indicator dot on bar icon
  Rectangle {
    id: liveDot
    visible: root.favoriteLive || root.liveCount > 0
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.margins: Math.max(1, Math.round(Style.space(1)))
    width: Style.space(7)
    height: width
    radius: width / 2
    color: root.favoriteLive ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.35)

    SequentialAnimation on opacity {
      running: root.favoriteLive || root.liveCount > 0
      loops: Animation.Infinite
      NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
    }
  }
}
