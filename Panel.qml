import QtQuick
import qs.Commons
import qs.Ui as Ui
import "Calculator.js" as Calculator

// Ui.Panel owns open(), close(), toggle() and the logical opened state.
// Ui.KeyboardPanel below owns the actual window, focus and outside clicks.
Ui.Panel {
    id: root
    moduleName: "io.github.BinDecHex.omamath"
    manageIpc: false

    property Item anchorItem: null
    property var hostWidget: null
    property string errorMessage: ""
    property string conversionNote: ""

    function clearBases(exceptField) {
        if (exceptField !== decField) decField.text = ""
        if (exceptField !== binField) binField.text = ""
        if (exceptField !== hexField) hexField.text = ""
    }

    function showBases(value, exceptField) {
        var bases = Calculator.convert(value)
        // Don't rewrite the field being edited: preserve its cursor and prefix.
        if (exceptField !== decField) decField.text = bases.decimal
        if (exceptField !== binField) binField.text = bases.binary
        if (exceptField !== hexField) hexField.text = bases.hexadecimal
    }

    function calculate() {
        errorMessage = ""
        conversionNote = ""
        resultField.text = ""
        clearBases(null)
        if (mathInput.text.trim() === "") return
        try {
            var value = Calculator.evaluate(mathInput.text)
            resultField.text = String(value)
            if (Calculator.isSafeInteger(value)) showBases(value, null)
            else conversionNote = "Fractional result — base conversion requires an integer."
        } catch (error) {
            errorMessage = error.message
        }
    }

    function editBase(field, base) {
        errorMessage = ""
        conversionNote = ""
        mathInput.text = ""
        resultField.text = ""
        clearBases(field)
        if (field.text.trim() === "") return
        try {
            var value = Calculator.parseInteger(field.text, base)
            resultField.text = String(value)
            showBases(value, field)
        } catch (error) {
            errorMessage = error.message
        }
    }

    function clear() {
        mathInput.text = ""
        resultField.text = ""
        clearBases(null)
        errorMessage = ""
        conversionNote = ""
        mathInput.forceActiveFocus()
    }

    Ui.KeyboardPanel {
        id: popup
        anchorItem: root.anchorItem
        bar: root.bar
        owner: root.hostWidget || root
        open: root.opened
        focusTarget: mathInput
        contentWidth: fittedContentWidth(Style.space(440))
        contentHeight: fittedContentHeight(form.implicitHeight)

        // Key events that a text field doesn't consume bubble up here.
        FocusScope {
            anchors.fill: parent
            Keys.onEscapePressed: function(event) {
                root.close()
                event.accepted = true
            }

            Flickable {
                id: scroll
                anchors.fill: parent
                contentWidth: width
                contentHeight: form.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                // Keep keyboard navigation usable on smaller screens.
                function reveal(field) {
                    var top = field.mapToItem(form, 0, 0).y
                    if (top < contentY) contentY = top
                    else if (top + field.height > contentY + height)
                        contentY = top + field.height - height
                }

                Column {
                    id: form
                    width: scroll.width
                    spacing: Style.space(8)

                    Text {
                        text: "OmaMath"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body * 1.3
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: "Calculate, or edit any base to convert."
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "Expression"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }

                    Ui.TextField {
                        id: mathInput
                        objectName: "expression"
                        width: parent.width
                        placeholderText: "(12 + 5) * 3 or 0xFF + 0b10"
                        maximumLength: 512
                        selectByMouse: true
                        // textEdited fires for user edits, not our assignments.
                        onTextEdited: root.calculate()
                        onAccepted: root.calculate()
                        onActiveFocusChanged: if (activeFocus) scroll.reveal(mathInput)
                    }

                    Text {
                        text: "Result"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }

                    Ui.TextField {
                        id: resultField
                        objectName: "result"
                        width: parent.width
                        readOnly: true
                        selectByMouse: true
                        placeholderText: "Select a value and press Ctrl+C to copy"
                        onActiveFocusChanged: if (activeFocus) scroll.reveal(resultField)
                    }

                    Text {
                        text: "Decimal · base 10"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }

                    Ui.TextField {
                        id: decField
                        objectName: "decimal"
                        width: parent.width
                        placeholderText: "255"
                        maximumLength: 128
                        selectByMouse: true
                        onTextEdited: root.editBase(decField, 10)
                        onActiveFocusChanged: if (activeFocus) scroll.reveal(decField)
                    }

                    Text {
                        text: "Binary · base 2"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }

                    Ui.TextField {
                        id: binField
                        objectName: "binary"
                        width: parent.width
                        placeholderText: "11111111 or 0b11111111"
                        maximumLength: 128
                        selectByMouse: true
                        onTextEdited: root.editBase(binField, 2)
                        onActiveFocusChanged: if (activeFocus) scroll.reveal(binField)
                    }

                    Text {
                        text: "Hexadecimal · base 16"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }

                    Ui.TextField {
                        id: hexField
                        objectName: "hexadecimal"
                        width: parent.width
                        placeholderText: "FF or 0xFF"
                        maximumLength: 128
                        selectByMouse: true
                        onTextEdited: root.editBase(hexField, 16)
                        onActiveFocusChanged: if (activeFocus) scroll.reveal(hexField)
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: root.errorMessage || root.conversionNote
                        color: root.errorMessage ? Color.urgent : Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                    }

                    Text {
                        width: parent.width
                        text: "+  −  *  /  %  ^  ( )   ·   Tab: next field   ·   Esc: close"
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }

                    Ui.Button {
                        id: clearButton
                        text: "Clear"
                        focusable: true
                        bordered: true
                        onClicked: root.clear()
                        onActiveFocusChanged: if (activeFocus) scroll.reveal(clearButton)
                    }
                }
            }
        }
    }
}
