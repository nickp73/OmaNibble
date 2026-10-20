import QtQuick
import qs.Commons
import qs.Commons as OmarchyCommons
import qs.Ui as Ui
import "Calculator.js" as Calculator

// Ui.Panel owns open(), close(), toggle() and the logical opened state.
// Ui.KeyboardPanel below owns the actual window, focus and outside clicks.
Ui.Panel {
    id: root
    moduleName: "io.github.nickp73.omanibble"
    manageIpc: false

    property Item anchorItem: null
    property var hostWidget: null
    property string errorMessage: ""
    property string conversionNote: ""
    property string conversionMode: "plain"
    property int bitWidth: 8
    property Item sourceField: null
    property int sourceBase: 10

    onConversionModeChanged: refreshConversion()
    onBitWidthChanged: refreshConversion()

    function refreshConversion() {
        if (sourceField === null) return
        if (sourceField === mathInput) calculate()
        else editBase(sourceField, sourceBase)
    }

    function clearBases(exceptField) {
        if (exceptField !== decField) decField.text = ""
        if (exceptField !== binField) binField.text = ""
        if (exceptField !== hexField) hexField.text = ""
    }

    function showBases(value, exceptField) {
        const bases = Calculator.convert(value, conversionMode, bitWidth)
        // Don't rewrite the field being edited: preserve its cursor and prefix.
        if (exceptField !== decField) decField.text = bases.decimal
        if (exceptField !== binField) binField.text = bases.binary
        if (exceptField !== hexField) hexField.text = bases.hexadecimal
    }

    function calculate() {
        sourceField = mathInput
        errorMessage = ""
        conversionNote = ""
        resultField.text = ""
        clearBases(null)
        if (mathInput.text.trim() === "") return
        try {
            var value = Calculator.evaluate(mathInput.text)
            resultField.text = String(value)
            if (Calculator.isSafeInteger(value)) {
                try {
                    showBases(value, null)
                } catch (conversionError) {
                    // The arithmetic result remains valid even if it doesn't
                    // fit the selected conversion width.
                    conversionNote = conversionError.message
                }
            } else conversionNote = "Fractional result — base conversion requires an integer."
        } catch (error) {
            errorMessage = error.message
        }
    }

    function editBase(field, base) {
        sourceField = field
        sourceBase = base
        errorMessage = ""
        conversionNote = ""
        mathInput.text = ""
        resultField.text = ""
        clearBases(field)
        if (field.text.trim() === "") return
        try {
            const value = Calculator.parseInteger(field.text, base, conversionMode, bitWidth)
            showBases(value, field)
            resultField.text = value
        } catch (error) {
            errorMessage = error.message
        }
    }

    function clear() {
        sourceField = null
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
                        text: "OmaNibble"
                        color: OmarchyCommons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body * 1.3
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: "Calculate, or convert 64-bit integers between bases."
                        color: OmarchyCommons.Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "Expression"
                        color: OmarchyCommons.Color.foreground
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
                        color: OmarchyCommons.Color.foreground
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

                    Flow {
                        width: parent.width
                        spacing: Style.space(6)
                        Repeater {
                            model: [
                                { key: "plain", label: "Minus sign" },
                                { key: "unsigned", label: "Unsigned" },
                                { key: "twos", label: "Two’s complement" }
                            ]
                            delegate: Ui.Button {
                                required property var modelData
                                objectName: "mode-" + modelData.key
                                text: modelData.label
                                selected: root.conversionMode === modelData.key
                                focusable: true
                                bordered: true
                                onClicked: root.conversionMode = modelData.key
                                onActiveFocusChanged: if (activeFocus) scroll.reveal(this)
                            }
                        }
                    }

                    Flow {
                        width: parent.width
                        visible: root.conversionMode !== "plain"
                        spacing: Style.space(6)
                        Repeater {
                            model: [8, 16, 32, 64]
                            delegate: Ui.Button {
                                required property int modelData
                                objectName: "width-" + modelData
                                text: modelData + " bits"
                                selected: root.bitWidth === modelData
                                focusable: true
                                bordered: true
                                onClicked: root.bitWidth = modelData
                                onActiveFocusChanged: if (activeFocus) scroll.reveal(this)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.conversionMode === "plain"
                            ? "Negative binary and hex values use a minus sign."
                            : root.conversionMode === "twos"
                                ? root.bitWidth + "-bit signed: a leading 1 bit means negative. Enter negative values in Decimal."
                                : root.bitWidth + "-bit unsigned: all values are zero or positive."
                        color: OmarchyCommons.Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "Decimal · base 10"
                        color: OmarchyCommons.Color.foreground
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
                        color: OmarchyCommons.Color.foreground
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
                        color: OmarchyCommons.Color.foreground
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
                        color: root.errorMessage ? OmarchyCommons.Color.urgent : OmarchyCommons.Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                    }

                    Text {
                        width: parent.width
                        text: "+  −  *  /  %  ^  ( )   ·   Tab: next field   ·   Esc: close"
                        color: OmarchyCommons.Color.muted
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
