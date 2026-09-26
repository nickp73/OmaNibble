import QtQuick
import Quickshell
import "Plugin" as Plugin

// Run with ./tests/smoke.sh in a Wayland session. No window is opened.
ShellRoot {
    Plugin.BarWidget { id: widget }

    function check(condition, message) {
        if (!condition) throw new Error(message)
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

            fields.expression.text = "1/0"
            fields.expression.textEdited()
            check(panel.errorMessage !== "" && fields.result.text === "", "Division by zero feedback")
            panel.clear()
            check(fields.expression.text === "" && fields.binary.text === "" && panel.errorMessage === "", "Clear action")
            console.log("OMAMATH_SMOKE_OK")
        } catch (error) {
            console.error("OMAMATH_SMOKE_FAILED: " + error.message)
        }
        Qt.quit()
    })
}
