import QtQuick
import Quickshell
import "Plugin" as Plugin

// Run with ./tests/smoke.sh in a Wayland session. No window is opened.
ShellRoot {
    Plugin.BarWidget { id: widget }

    function check(condition, message) {
        if (!condition) throw new Error(message)
    }

    function findControl(item, name) {
        if (item.objectName === name) return item
        for (let i = 0; i < item.children.length; i++) {
            const found = findControl(item.children[i], name)
            if (found) return found
        }
        return null
    }

    Component.onCompleted: Qt.callLater(function() {
        try {
            var panel = null
            for (var i = 0; i < widget.children.length; i++) {
                if (typeof widget.children[i].calculate === "function") panel = widget.children[i]
            }
            check(panel !== null, "Local Panel must be created")
            var popup = null
            for (i = 0; i < panel.data.length; i++) {
                if (panel.data[i].focusTarget !== undefined) popup = panel.data[i]
            }
            check(popup !== null, "KeyboardPanel must be created")
            var fields = {}
            var children = popup.focusTarget.parent.children
            for (i = 0; i < children.length; i++) {
                if (children[i].objectName) fields[children[i].objectName] = children[i]
            }
            check(!widget.opened && !popup.open, "Popup must start closed")
            check(popup.anchorItem !== null, "Bar button must be bound as the popup anchor")

            fields.expression.text = "(12 + 5) * 3"
            fields.expression.textEdited()
            check(fields.result.text === "51", "Expression result")
            check(fields.decimal.text === "51", "Decimal from expression")
            check(fields.binary.text === "110011", "Binary from expression")
            check(fields.hexadecimal.text === "33", "Hex from expression")

            fields.binary.text = "0b1010"
            fields.binary.cursorPosition = 3
            fields.binary.textEdited()
            check(fields.binary.text === "0b1010", "Preserve edited text")
            check(fields.binary.cursorPosition === 3, "Preserve cursor")
            check(fields.result.text === "10" && fields.hexadecimal.text === "A", "Base synchronization")
            check(fields.expression.text === "", "Clear stale expression after base edit")

            fields.binary.text = "102"
            fields.binary.textEdited()
            check(panel.errorMessage !== "", "Reject invalid binary")
            check(fields.result.text === "" && fields.decimal.text === "" && fields.hexadecimal.text === "", "Clear stale outputs")

            fields.expression.text = "5 / 2"
            fields.expression.textEdited()
            check(fields.result.text === "2.5", "Keep fractional result")
            check(fields.binary.text === "" && fields.decimal.text === "" && fields.hexadecimal.text === "", "Don't round fractions for conversion")
            check(panel.conversionNote !== "" && panel.errorMessage === "", "Explain fractional conversion")

            fields.hexadecimal.text = "-0xFF"
            fields.hexadecimal.textEdited()
            check(fields.decimal.text === "-255" && fields.binary.text === "-11111111", "Signed conversion")

            fields.hexadecimal.text = "0xffffffffffffffff"
            fields.hexadecimal.cursorPosition = 5
            fields.hexadecimal.textEdited()
            check(fields.decimal.text === "18446744073709551615", "Exact unsigned 64-bit maximum")
            check(fields.result.text === fields.decimal.text, "Exact large result text")
            check(fields.binary.text === "1".repeat(64), "All 64 binary digits")
            check(fields.hexadecimal.text === "0xffffffffffffffff" && fields.hexadecimal.cursorPosition === 5, "Preserve large input and cursor")

            fields.decimal.text = "-9223372036854775808"
            fields.decimal.textEdited()
            check(fields.hexadecimal.text === "-8000000000000000", "Exact signed 64-bit minimum")
            check(fields.binary.text === "-1" + "0".repeat(63), "Signed minimum binary")

            fields.binary.text = "1".repeat(64)
            fields.binary.textEdited()
            check(fields.decimal.text === "18446744073709551615" && fields.hexadecimal.text === "FFFFFFFFFFFFFFFF", "Exact conversion from 64-bit binary")

            fields.decimal.text = "18446744073709551616"
            fields.decimal.textEdited()
            check(panel.errorMessage !== "", "Reject 64-bit overflow")
            check(fields.result.text === "" && fields.binary.text === "" && fields.hexadecimal.text === "", "Overflow clears stale outputs")

            fields.decimal.text = "9007199254740993"
            fields.decimal.textEdited()
            check(fields.hexadecimal.text === "20000000000001" && panel.errorMessage === "", "Recover from overflow without losing digits")

            fields.expression.text = "9007199254740993"
            fields.expression.textEdited()
            check(panel.errorMessage !== "" && fields.result.text === "" && fields.decimal.text === "", "Expression range remains explicit")

            fields.expression.text = "1/0"
            fields.expression.textEdited()
            check(panel.errorMessage !== "" && fields.result.text === "", "Division by zero feedback")
            panel.clear()
            check(fields.expression.text === "" && fields.binary.text === "" && panel.errorMessage === "", "Clear action")

            const form = popup.focusTarget.parent
            const twos = findControl(form, "mode-twos")
            const unsigned = findControl(form, "mode-unsigned")
            const plain = findControl(form, "mode-plain")
            const width8 = findControl(form, "width-8")
            const width16 = findControl(form, "width-16")
            const width64 = findControl(form, "width-64")
            check(twos && unsigned && plain && width8 && width16 && width64, "Mode and width controls exist")
            check(plain.selected && panel.bitWidth === 8, "Minus-sign mode is the default")

            fields.decimal.text = "-5"
            fields.decimal.textEdited()
            twos.clicked()
            check(twos.selected && fields.binary.text === "11111011" && fields.hexadecimal.text === "FB", "Enable two's complement for negative decimal")
            width16.clicked()
            check(fields.hexadecimal.text === "FFFB" && fields.decimal.text === "-5", "Width changes preserve decimal input")
            width8.clicked()
            unsigned.clicked()
            check(panel.errorMessage !== "" && fields.result.text === "" && fields.hexadecimal.text === "", "Unsigned mode rejects negative decimal")
            twos.clicked()
            check(panel.errorMessage === "" && fields.hexadecimal.text === "FB", "Switching back recovers the input")

            fields.hexadecimal.text = "0xFF"
            fields.hexadecimal.cursorPosition = 3
            fields.hexadecimal.textEdited()
            check(fields.decimal.text === "-1" && fields.result.text === "-1", "Interpret signed hexadecimal pattern")
            unsigned.clicked()
            check(fields.decimal.text === "255" && fields.binary.text === "11111111", "Reinterpret same pattern as unsigned")
            check(fields.hexadecimal.text === "0xFF" && fields.hexadecimal.cursorPosition === 3, "Mode changes preserve source text and cursor")
            twos.clicked()
            width16.clicked()
            check(fields.decimal.text === "255" && fields.binary.text === "0000000011111111", "Short hex is zero-extended at wider width")

            fields.hexadecimal.text = "100"
            fields.hexadecimal.textEdited()
            width8.clicked()
            check(panel.errorMessage !== "" && fields.decimal.text === "" && fields.binary.text === "" && fields.result.text === "", "Narrowing rejects overflow and clears results")
            width16.clicked()
            check(panel.errorMessage === "" && fields.decimal.text === "256", "Widening recovers original input")

            width64.clicked()
            fields.hexadecimal.text = "FFFFFFFFFFFFFFFF"
            fields.hexadecimal.textEdited()
            check(fields.decimal.text === "-1", "Signed 64-bit all-ones pattern")
            unsigned.clicked()
            check(fields.decimal.text === "18446744073709551615", "Unsigned 64-bit all-ones pattern")

            twos.clicked()
            width8.clicked()
            fields.expression.text = "127 + 1"
            fields.expression.textEdited()
            check(fields.result.text === "128" && fields.decimal.text === "" && panel.conversionNote !== "" && panel.errorMessage === "", "Width overflow preserves ordinary arithmetic result")
            width16.clicked()
            check(fields.result.text === "128" && fields.hexadecimal.text === "0080" && panel.conversionNote === "", "Width change refreshes expression conversion")
            fields.expression.text = "5 / 2"
            fields.expression.textEdited()
            check(fields.result.text === "2.5" && fields.hexadecimal.text === "", "Fixed width does not round fractions")

            panel.clear()
            check(panel.sourceField === null && panel.conversionMode === "twos", "Clear retains selected mode and resets source")
            plain.clicked()
            check(fields.result.text === "" && panel.errorMessage === "", "Mode switch after clear keeps inputs empty")
            console.log("OMAMATH_SMOKE_OK")
        } catch (error) {
            console.error("OMAMATH_SMOKE_FAILED: " + error.message)
        }
        Qt.quit()
    })
}
