import QtQuick
import qs.Commons

// Shared uppercase section heading used by the settings cards.
PlainText {
  id: root

  property color foreground: Commons.Color.foreground
  property real mutedOpacity: 0.6

  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.mutedOpacity)
  font.family: Style.font.family
  font.pixelSize: Style.font.caption
  font.bold: true
  font.letterSpacing: 0.8
}
