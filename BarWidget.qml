import QtQuick
import qs.Commons
import qs.Ui

// A lightweight, instant-access Omarchy status bar widget with live match ticker.
BarWidget {
  id: root
  moduleName: "miguel.omasports"

  // Shape contract for shell.summon/hide/toggle routing
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  // Glanceable state for the bar badge and ticker
  readonly property bool favoriteLive: panelLoader.item ? panelLoader.item.favoriteTeamLive === true : false
  readonly property string favoriteLiveState: panelLoader.item ? (panelLoader.item.favoriteLiveState || "") : ""
  readonly property string favoriteSummary: panelLoader.item ? panelLoader.item.favoriteSummaryText : ""
  readonly property int liveCount: panelLoader.item ? (panelLoader.item.liveCount || 0) : 0
  readonly property string activeSportIcon: panelLoader.item ? (panelLoader.item.activeSportIcon || "⚽") : "⚽"

  // Settings
  readonly property bool showBarTicker: {
    if (panelLoader.item && panelLoader.item.showBarTicker !== undefined) {
      return panelLoader.item.showBarTicker === true
    }
    return setting("showBarTicker", true) === true
  }

  readonly property bool vertical: root.bar ? root.bar.vertical : false
  readonly property bool hasTicker: !vertical && showBarTicker && favoriteLive && favoriteSummary !== ""

  readonly property string barDisplayLabel: {
    if (hasTicker) {
      return activeSportIcon + " " + favoriteSummary
    }
    return activeSportIcon
  }

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
    onLoaded: root.injectPanel()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barDisplayLabel
    labelVisible: true
    active: root.opened
    fontSize: root.hasTicker ? Style.font.bodySmall : Style.bar.iconFont
    fixedWidth: root.hasTicker ? -1 : (root.vertical ? -1 : Style.bar.iconSlot)
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1
    horizontalMargin: root.hasTicker ? 8.5 : 4
    verticalPadding: 4
    useActiveColor: root.hasTicker && root.favoriteLive
    tooltipText: root.opened
      ? "Hide OmaSports"
      : (root.favoriteLive
          ? "OmaSports — " + root.favoriteSummary
          : "Open OmaSports")

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton) root.open()
    }
  }

  // Live match indicator dot on bar icon (only when ticker text is not shown)
  Rectangle {
    id: liveDot
    visible: !root.hasTicker && (root.favoriteLive || root.liveCount > 0)
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.margins: Math.max(1, Math.round(Style.space(1)))
    width: Style.space(7)
    height: width
    radius: width / 2
    color: root.favoriteLive
      ? (root.favoriteLiveState === "leading"
         ? "#22c55e"
         : (root.favoriteLiveState === "trailing"
            ? "#ef4444"
            : (root.favoriteLiveState === "tied"
               ? "#f59e0b"
               : (root.bar ? root.bar.urgent : Color.urgent))))
      : Color.accent
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.35)

    SequentialAnimation on opacity {
      running: liveDot.visible
      loops: Animation.Infinite
      NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
    }
  }
}
