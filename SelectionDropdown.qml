import QtQuick
import qs.Ui

// Native Dropdown assigns value when an option is chosen. Restore the
// controller binding afterward so later sport/state changes stay visible.
Dropdown {
  id: root
  property string selectedValue: ""
  value: selectedValue

  function restoreSelectionBinding() {
    root.value = Qt.binding(function() { return root.selectedValue })
  }

  onSelectedValueChanged: restoreSelectionBinding()
  onChanged: Qt.callLater(restoreSelectionBinding)
}
