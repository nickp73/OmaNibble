// Pure JavaScript: no QML objects and no eval(). QML imports this as a
// namespace; tests load the same source into an isolated Node VM context.
var MAX_INTEGER = 9007199254740991
var MAX_UNSIGNED_64 = "18446744073709551615"
var MIN_SIGNED_64_MAGNITUDE = "9223372036854775808"

function isSafeInteger(value) {
    return typeof value === "number" && isFinite(value)
        && Math.floor(value) === value && Math.abs(value) <= MAX_INTEGER
}

function checked(value) {
    if (!isFinite(value)) throw new Error("The result is not a finite number.")
    if (Math.abs(value) > MAX_INTEGER)
        throw new Error("Expression range: −9,007,199,254,740,991 to 9,007,199,254,740,991.")
    return value === 0 ? 0 : value // Normalize negative zero.
}

// Long division converts unsigned digit strings without ever storing the whole
// integer in a Number. For bases 2, 10 and 16, each intermediate is at most 255.
function convertDigits(text, fromBase, toBase) {
    var alphabet = "0123456789ABCDEF"
    var digits = []
    for (var i = 0; i < text.length; i++)
        digits.push(alphabet.indexOf(text.charAt(i).toUpperCase()))
    var result = ""
    while (digits.length > 0) {
        var quotient = []
        var remainder = 0
        for (i = 0; i < digits.length; i++) {
            var value = remainder * fromBase + digits[i]
            var digit = Math.floor(value / toBase)
            remainder = value % toBase
            if (quotient.length > 0 || digit !== 0) quotient.push(digit)
        }
        result = alphabet.charAt(remainder) + result
        digits = quotient
    }
    return result || "0"
}

// Return a canonical decimal STRING, including for small values. The QML
// engine has no BigInt; keeping strings throughout avoids rounding 64-bit input.
// Accept the union of signed and unsigned 64-bit ranges, without wrapping.
function parsePlainInteger(input, base) {
    if (typeof input === "number" && !isSafeInteger(input))
        throw new Error("Enter large integers as text to preserve every digit.")
    var text = String(input).trim()
    if (text.length > 128) throw new Error("Use at most 128 characters.")
    var pattern = base === 2 ? /^[+-]?(?:0b)?[01]+$/i
        : base === 16 ? /^[+-]?(?:0x)?[0-9a-f]+$/i
        : base === 10 ? /^[+-]?[0-9]+$/ : null
    if (!pattern) throw new Error("Unsupported number base.")
    if (!pattern.test(text))
        throw new Error("Enter a complete base " + base + " integer.")
    var negative = text.charAt(0) === "-"
    text = text.replace(/^[+-]/, "")
    if (base === 2) text = text.replace(/^0b/i, "")
    if (base === 16) text = text.replace(/^0x/i, "")
    var decimal = convertDigits(text, base, 10)
    var limit = negative ? MIN_SIGNED_64_MAGNITUDE : MAX_UNSIGNED_64
    if (decimal.length > limit.length || (decimal.length === limit.length && decimal > limit))
        throw new Error("64-bit conversion range: −9,223,372,036,854,775,808 to 18,446,744,073,709,551,615.")
    return negative && decimal !== "0" ? "-" + decimal : decimal
}

// Omitted mode preserves the original minus-sign representation.
function fixedWidth(mode, width) {
    if (mode === undefined || mode === "plain") return false
    if (mode !== "unsigned" && mode !== "twos") throw new Error("Unsupported conversion mode.")
    if (width !== 8 && width !== 16 && width !== 32 && width !== 64)
        throw new Error("Choose 8, 16, 32 or 64 bits.")
    return true
}

// Negate a fixed-width binary pattern by flipping its bits and adding one.
// All arithmetic stays on individual digits, including for 64-bit values.
function complementBits(bits) {
    let carry = 1
    let result = ""
    for (let i = bits.length - 1; i >= 0; i--) {
        const digit = (bits.charAt(i) === "0" ? 1 : 0) + carry
        result = String(digit % 2) + result
        carry = Math.floor(digit / 2)
    }
    return result
}

function widthRangeMessage(mode, width) {
    const maximum = convertDigits("1".repeat(mode === "twos" ? width - 1 : width), 2, 10)
    const minimum = mode === "twos" ? "−" + convertDigits("1" + "0".repeat(width - 1), 2, 10) : "0"
    return width + "-bit " + (mode === "twos" ? "signed" : "unsigned")
        + " range: " + minimum + " to " + maximum + "."
}

function integerBits(decimal, mode, width) {
    const negative = decimal.charAt(0) === "-"
    const bits = convertDigits(negative ? decimal.slice(1) : decimal, 10, 2)
    const signedMinimum = "1" + "0".repeat(width - 1)
    const fits = mode === "unsigned" ? !negative && bits.length <= width
        : bits.length < width || (negative && bits === signedMinimum)
    if (!fits) throw new Error(widthRangeMessage(mode, width))
    const padded = "0".repeat(width - bits.length) + bits
    return negative ? complementBits(padded) : padded
}

function parseInteger(input, base, mode, width) {
    const fixed = fixedWidth(mode, width)
    if (fixed && base !== 10 && String(input).trim().charAt(0) === "-")
        throw new Error("Use a bit pattern without a minus sign here; enter negative values in Decimal.")
    const decimal = parsePlainInteger(input, base)
    if (!fixed) return decimal
    if (base === 10) {
        integerBits(decimal, mode, width) // Validate the decimal signed/unsigned range.
        return decimal
    }
    const bits = convertDigits(decimal, 10, 2)
    if (bits.length > width) throw new Error("The bit pattern does not fit in " + width + " bits.")
    const padded = "0".repeat(width - bits.length) + bits
    return mode === "twos" && padded.charAt(0) === "1"
        ? "-" + convertDigits(complementBits(padded), 2, 10) : decimal
}

function convert(value, mode, width) {
    // Expression results are Numbers; edited base fields supply decimal strings.
    if (typeof value !== "string" && !isSafeInteger(value))
        throw new Error("Base conversion requires an exact integer.")
    const fixed = fixedWidth(mode, width)
    var decimal = parsePlainInteger(value, 10)
    if (fixed) {
        const bits = integerBits(decimal, mode, width)
        const hex = convertDigits(bits, 2, 16)
        return {
            decimal: decimal,
            binary: bits,
            hexadecimal: "0".repeat(width / 4 - hex.length) + hex
        }
    }
    var sign = decimal.charAt(0) === "-" ? "-" : ""
    var magnitude = sign ? decimal.slice(1) : decimal
    return {
        decimal: decimal,
        binary: sign + convertDigits(magnitude, 10, 2),
        hexadecimal: sign + convertDigits(magnitude, 10, 16)
    }
}

// Recursive descent: each function handles one precedence level.
// expression → sum → product → unary → power → primary (number or brackets).
// Powers bind more tightly than a leading minus: -2^2 = -(2^2) = -4.
// Their right operand is unary, so 2^-2 and 2^3^2 also work naturally.
function evaluate(input) {
    var source = String(input).trim()
    if (!source) throw new Error("Enter an expression.")
    if (source.length > 512) throw new Error("Use at most 512 characters.")
    var position = 0

    function skipSpace() {
        while (position < source.length && /\s/.test(source.charAt(position))) position++
    }

    function take(token) {
        skipSpace()
        if (source.slice(position, position + token.length) !== token) return false
        position += token.length
        return true
    }

    function primary() {
        if (take("(")) {
            var value = sum()
            if (!take(")")) throw new Error("Missing closing parenthesis.")
            return value
        }
        skipSpace()
        var rest = source.slice(position)
        var literal = /^(?:0[xX][0-9a-fA-F]+|0[bB][01]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)/.exec(rest)
        if (!literal) throw new Error("Expected a number at position " + (position + 1) + ".")
        position += literal[0].length
        return checked(Number(literal[0]))
    }

    function power() {
        var left = primary()
        if (take("**") || take("^")) return checked(Math.pow(left, unary()))
        return left
    }

    function unary() {
        if (take("+")) return unary()
        if (take("-")) return checked(-unary())
        return power()
    }

    function product() {
        var left = unary()
        while (true) {
            if (take("*")) left = checked(left * unary())
            else if (take("/")) {
                var divisor = unary()
                if (divisor === 0) throw new Error("Cannot divide by zero.")
                left = checked(left / divisor)
            } else if (take("%")) {
                var modulus = unary()
                if (modulus === 0) throw new Error("Cannot take a remainder with zero.")
                left = checked(left % modulus)
            } else return left
        }
    }

    function sum() {
        var left = product()
        while (true) {
            if (take("+")) left = checked(left + product())
            else if (take("-")) left = checked(left - product())
            else return left
        }
    }

    var result = sum()
    skipSpace()
    if (position !== source.length)
        throw new Error("Unexpected input at position " + (position + 1) + ".")
    return result
}
