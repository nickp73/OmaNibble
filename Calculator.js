// Pure JavaScript: no QML objects and no eval(). QML imports this as a
// namespace; tests load the same source into an isolated Node VM context.
var MAX_INTEGER = 9007199254740991

function isSafeInteger(value) {
    return typeof value === "number" && isFinite(value)
        && Math.floor(value) === value && Math.abs(value) <= MAX_INTEGER
}

function checked(value) {
    if (!isFinite(value)) throw new Error("The result is not a finite number.")
    if (Math.abs(value) > MAX_INTEGER)
        throw new Error("Supported range: −9,007,199,254,740,991 to 9,007,199,254,740,991.")
    return value === 0 ? 0 : value // Normalize negative zero.
}

function parseInteger(input, base) {
    var text = String(input).trim()
    if (text.length > 128) throw new Error("Use at most 128 characters.")
    var pattern = base === 2 ? /^[+-]?(?:0b)?[01]+$/i
        : base === 16 ? /^[+-]?(?:0x)?[0-9a-f]+$/i
        : base === 10 ? /^[+-]?[0-9]+$/ : null
    if (!pattern) throw new Error("Unsupported number base.")
    if (!pattern.test(text))
        throw new Error("Enter a complete base " + base + " integer.")
    var sign = text.charAt(0) === "-" ? -1 : 1
    text = text.replace(/^[+-]/, "")
    if (base === 2) text = text.replace(/^0b/i, "")
    if (base === 16) text = text.replace(/^0x/i, "")
    return checked(sign * parseInt(text, base))
}

function convert(value) {
    if (!isSafeInteger(value)) throw new Error("Base conversion requires a safe integer.")
    return {
        decimal: value.toString(10),
        binary: value.toString(2),
        hexadecimal: value.toString(16).toUpperCase()
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
