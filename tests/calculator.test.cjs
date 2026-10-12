const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Exercise the exact source imported by QML, without maintaining a copy.
const calc = vm.createContext({});
vm.runInContext(readFileSync(join(__dirname, '../Calculator.js'), 'utf8'), calc);

for (const [expression, expected] of [
    ['(12 + 5) * 3', 51], ['2 + 3 * 4', 14], ['5 / 2', 2.5],
    ['-5 / 2', -2.5], ['10 % 3', 1], ['-10 % 3', -1],
    ['2^3^2', 512], ['2**3', 8], ['-2^2', -4], ['(-2)^2', 4],
    ['2^-2', 0.25], ['1--2', 3], ['+3', 3], ['0xFF + 0b10', 257],
    ['-0Xf + 0B11', -12], ['.5 + 1.25', 1.75], ['1e3 / 4', 250],
    ['  ( 2 + 3 ) / 2  ', 2.5], ['0', 0], ['-0', 0],
    ['9007199254740991', 9007199254740991],
    ['-9007199254740991', -9007199254740991],
]) {
    test(`evaluate ${expression}`, () => assert.equal(calc.evaluate(expression), expected));
}

for (const expression of [
    '', '2 +', '(1+2', '2)', '2(3)', '1 2', '0b102', '0xFG', '1e',
    '1/0', '0/0', '1%0', '(-1)^.5', '2^100', '1e309',
    '9007199254740993', '9007199254740991 + 1',
    'Math.random()', 'while(true){}', '1;2', 'x=1', '2|1', '2<<1',
    '1'.repeat(513),
]) {
    test(`reject expression ${expression.slice(0, 40)}`, () => assert.throws(() => calc.evaluate(expression)));
}

for (const [input, base, expected] of [
    ['255', 10, 255], ['11111111', 2, 255], ['FF', 16, 255],
    ['0b1010', 2, 10], ['+0B1010', 2, 10], ['-0xFF', 16, -255],
    [' ff ', 16, 255], ['-101', 2, -5], ['00025', 10, 25], ['-0', 10, 0],
]) {
    test(`parse base ${base}: ${input}`, () => assert.equal(calc.parseInteger(input, base), String(expected)));
}

for (const [input, base] of [
    ['102', 2], ['0b', 2], ['0x', 16], ['FG', 16], ['12cats', 10],
    ['2.5', 10], ['1e3', 10], ['1 0', 2], ['--1', 10], ['', 10],
    ['18446744073709551616', 10], ['10000000000000000', 16], ['1', 8],
    ['-9223372036854775809', 10], ['-8000000000000001', 16],
    ['1' + '0'.repeat(64), 2], ['-1' + '0'.repeat(62) + '1', 2],
    ['1'.repeat(129), 2],
]) {
    test(`reject base ${base}: ${input.slice(0, 40)}`, () => assert.throws(() => calc.parseInteger(input, base)));
}

test('integer conversions round-trip through every base', () => {
    for (const value of [0, 1, -1, 255, -255, 65535, 2147483648, 9007199254740991, -9007199254740991]) {
        const fields = calc.convert(value);
        assert.equal(calc.parseInteger(fields.decimal, 10), String(value));
        assert.equal(calc.parseInteger(fields.binary, 2), String(value));
        assert.equal(calc.parseInteger(fields.hexadecimal, 16), String(value));
    }
    assert.equal(calc.convert(-255).binary, '-11111111');
    assert.equal(calc.convert(255).hexadecimal, 'FF');
});

// Node's BigInt is an independent oracle, never a runtime plugin dependency.
function checkExactConversion(value) {
    const decimal = value.toString(10);
    const fields = calc.convert(decimal);
    assert.equal(fields.decimal, decimal);
    assert.equal(fields.binary, value.toString(2));
    assert.equal(fields.hexadecimal, value.toString(16).toUpperCase());
    for (const base of [2, 10, 16]) {
        assert.equal(calc.parseInteger(value.toString(base), base), decimal);
    }
}

test('64-bit boundaries and all powers of two stay exact in every base', () => {
    const min = -(1n << 63n);
    const max = (1n << 64n) - 1n;
    for (let bit = 0n; bit <= 64n; bit++) {
        for (const offset of [-1n, 0n, 1n]) {
            const value = (1n << bit) + offset;
            if (value <= max) checkExactConversion(value);
            if (-value >= min) checkExactConversion(-value);
        }
    }
});

test('deterministic 64-bit samples agree with BigInt', () => {
    let value = 0x123456789ABCDEFn;
    for (let i = 0; i < 1000; i++) {
        value = BigInt.asUintN(64, value * 6364136223846793005n + 1442695040888963407n);
        checkExactConversion(value);
        checkExactConversion(BigInt.asIntN(64, value));
    }
});

test('large inputs preserve prefixes, signs and leading-zero semantics', () => {
    assert.equal(calc.parseInteger(' +0xffffffffffffffff ', 16), '18446744073709551615');
    assert.equal(calc.parseInteger('-0X8000000000000000', 16), '-9223372036854775808');
    assert.equal(calc.parseInteger('+0B' + '1'.repeat(64), 2), '18446744073709551615');
    assert.equal(calc.parseInteger('0'.repeat(108) + '18446744073709551615', 10), '18446744073709551615');
    for (const [text, base] of [['-000', 10], ['-0x000', 16], ['-0b000', 2]]) {
        assert.equal(calc.parseInteger(text, base), '0');
    }
    assert.equal(calc.convert('-000').binary, '0');
});

test('conversion never accepts an already-rounded Number as a large integer', () => {
    assert.throws(() => calc.parseInteger(9007199254740992, 10));
    assert.throws(() => calc.convert(18446744073709551615));
    assert.equal(calc.parseInteger('9007199254740993', 10), '9007199254740993');
});

test('decimal string conversion rejects invalid and out-of-range values', () => {
    for (const value of ['', '1.5', '1e3', '0xFF', '18446744073709551616', '-9223372036854775809']) {
        assert.throws(() => calc.convert(value));
    }
});

test('conversion rejects fractions, nonfinite values and unsafe integers', () => {
    for (const value of [2.5, Infinity, NaN, 9007199254740992]) {
        assert.equal(calc.isSafeInteger(value), false);
        assert.throws(() => calc.convert(value));
    }
});

test('floating point behavior is explicit, without rounding into integers', () => {
    assert.equal(calc.evaluate('0.1 + 0.2'), 0.1 + 0.2);
    assert.equal(calc.isSafeInteger(calc.evaluate('5 / 2')), false);
});

function checkFixedPattern(pattern, width) {
    for (const mode of ['unsigned', 'twos']) {
        const value = mode === 'twos' ? BigInt.asIntN(width, pattern) : pattern;
        const decimal = value.toString();
        const fields = calc.convert(decimal, mode, width);
        assert.equal(fields.decimal, decimal);
        assert.equal(fields.binary, pattern.toString(2).padStart(width, '0'));
        assert.equal(fields.hexadecimal, pattern.toString(16).toUpperCase().padStart(width / 4, '0'));
        for (const [base, text] of [[10, decimal], [2, fields.binary], [16, fields.hexadecimal]]) {
            assert.equal(calc.parseInteger(text, base, mode, width), decimal);
        }
    }
}

test('every 8-bit pattern agrees with signed and unsigned BigInt interpretation', () => {
    for (let pattern = 0n; pattern < 256n; pattern++) checkFixedPattern(pattern, 8);
});

for (const width of [8, 16, 32, 64]) {
    test(`${width}-bit boundaries, powers and samples stay exact`, () => {
        const bits = BigInt(width);
        const max = (1n << bits) - 1n;
        for (let bit = 0n; bit < bits; bit++) {
            for (const offset of [-1n, 0n, 1n]) checkFixedPattern(((1n << bit) + offset) & max, width);
        }
        checkFixedPattern(max, width);
        let sample = 0x12345678n;
        for (let i = 0; i < 100; i++) {
            sample = BigInt.asUintN(width, sample * 6364136223846793005n + 1442695040888963407n);
            checkFixedPattern(sample, width);
        }
    });

    test(`${width}-bit mode rejects overflow instead of wrapping`, () => {
        const bits = BigInt(width);
        const signedLimit = 1n << (bits - 1n);
        for (const [mode, invalid] of [
            ['twos', [signedLimit, -signedLimit - 1n]],
            ['unsigned', [-1n, 1n << bits]],
        ]) {
            for (const value of invalid) {
                assert.throws(() => calc.convert(value.toString(), mode, width));
                assert.throws(() => calc.parseInteger(value.toString(), 10, mode, width));
            }
            assert.throws(() => calc.parseInteger('1' + '0'.repeat(width), 2, mode, width));
            assert.throws(() => calc.parseInteger('1' + '0'.repeat(width / 4), 16, mode, width));
        }
    });
}

test('short patterns are zero-extended to the selected width', () => {
    assert.equal(calc.parseInteger('FF', 16, 'twos', 8), '-1');
    assert.equal(calc.parseInteger('FF', 16, 'twos', 16), '255');
    assert.equal(calc.parseInteger('1', 2, 'twos', 8), '1');
    assert.equal(calc.parseInteger(' +0x00ff ', 16, 'twos', 8), '-1');
    assert.equal(calc.parseInteger('0b11111011', 2, 'twos', 8), '-5');
    assert.equal(calc.convert('-0', 'twos', 8).hexadecimal, '00');
});

test('fixed-width patterns require negative input to use the decimal field', () => {
    for (const mode of ['unsigned', 'twos']) {
        for (const [text, base] of [['-FF', 16], ['-0b1', 2], ['-0', 2]]) {
            assert.throws(() => calc.parseInteger(text, base, mode, 8), /minus sign/);
        }
    }
    assert.equal(calc.parseInteger('-FF', 16, 'plain', 8), '-255');
    assert.equal(calc.convert('-255', 'plain', 8).hexadecimal, '-FF');
});

test('conversion mode and widths are validated', () => {
    for (const [mode, width] of [['bad', 8], ['twos', 0], ['twos', 7], ['unsigned', 128], ['twos', undefined]]) {
        assert.throws(() => calc.convert('1', mode, width));
        assert.throws(() => calc.parseInteger('1', 16, mode, width));
    }
});
