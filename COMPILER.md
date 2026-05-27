# Compiler Notes — livt-math

## `>>` (right shift) on `int` generates invalid VHDL

Using `s >> 7` on an `int` variable generates:
```vhdl
s := to_integer(to_signed(s, 32) and (-1 downto -7 => "0") & s(-8 downto 0));
```
This is invalid VHDL — GHDL rejects "type of prefix is not an array".

**Workaround:** Use division by a power of 2:
```livt
// Instead of: s = s >> 7
s = s / 128
```

## `<<` (left shift) on `int` generates invalid VHDL

Similar issue. Use multiplication by a power of 2:
```livt
// Instead of: s = s << 3
s = s * 8
```

## `^` and `&` in the same expression emit `and` for both

Writing `s = s ^ ((s * 8) & MASK)` generates VHDL that uses `and` for both
operators — the `^` (XOR) is incorrectly emitted as `and`:
```vhdl
-- Generated (wrong): all operators become 'and'
s := to_integer(to_signed(s, 32) and to_signed(s * 8, 32) and to_signed(MASK, 32));
```

When `^` is used alone (e.g. `s = s ^ t`), it correctly generates `xor`:
```vhdl
-- Generated (correct): standalone XOR works
s := to_integer(to_signed(s, 32) xor to_signed(t, 32));
```

**Workaround:** Split combined `^` and `&` expressions into separate statements
using a temporary variable:
```livt
// Instead of: s = s ^ ((s * 8) & MASK)
var t: int = (s * 8) & MASK
s = s ^ t
```
