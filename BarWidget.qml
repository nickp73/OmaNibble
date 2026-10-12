import QtQuick
import qs.Ui as Ui

// Omarchy injects bar and settings into this item. Qualifying Ui.BarWidget
// avoids confusing the framework component with this file's own name.
Ui.BarWidget {
    id: root
    moduleName: "io.github.BinDecHex.omamath"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    // The host uses this interface to coordinate popups and keyboard summons.
    readonly property bool opened: calculator.opened
    readonly property bool popoutSwitchClosing: calculator.popoutSwitchClosing
    readonly property real openPanelIndicatorWidth: button.labelWidth

    function open() { calculator.open() }
    function close() { calculator.close() }
    function togglePanel() { calculator.toggle() }
    function closeForPopoutSwitch() { calculator.closeForPopoutSwitch() }

    Ui.WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.vertical ? "=" : "OmaMath"
        tooltipText: "Calculator and decimal / binary / hex converter"
        onPressed: function(mouseButton) {
            if (mouseButton === Qt.LeftButton) root.togglePanel()
        }
    }


    // Property bindings keep its host and anchor up to date automatically.
    Panel {
        id: calculator
        bar: root.bar
        settings: root.settings
        anchorItem: button
        hostWidget: root
    }
}
