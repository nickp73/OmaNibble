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
    test(`parse base ${base}: ${input}`, () => assert.equal(calc.parseInteger(input, base), expected));
}

for (const [input, base] of [
    ['102', 2], ['0b', 2], ['0x', 16], ['FG', 16], ['12cats', 10],
    ['2.5', 10], ['1e3', 10], ['1 0', 2], ['--1', 10], ['', 10],
    ['9007199254740993', 10], ['20000000000000', 16], ['1', 8],
    ['1'.repeat(129), 2],
]) {
    test(`reject base ${base}: ${input.slice(0, 40)}`, () => assert.throws(() => calc.parseInteger(input, base)));
}

test('integer conversions round-trip through every base', () => {
    for (const value of [0, 1, -1, 255, -255, 65535, 2147483648, 9007199254740991, -9007199254740991]) {
        const fields = calc.convert(value);
        assert.equal(calc.parseInteger(fields.decimal, 10), value);
        assert.equal(calc.parseInteger(fields.binary, 2), value);
        assert.equal(calc.parseInteger(fields.hexadecimal, 16), value);
    }
    assert.equal(calc.convert(-255).binary, '-11111111');
    assert.equal(calc.convert(255).hexadecimal, 'FF');
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
