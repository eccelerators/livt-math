# Usage Examples

`Livt.Math` exposes fixed-size arithmetic components. These examples show the
basic call order and boundary behavior expected by the package.

## Integer Square Root

Use `SqrtLUT` for 8-bit inputs when a small table is a better fit than an
iterative divider. Inputs outside `[0, 255]` are clamped.

```livt
namespace Example

using Livt.Math.Sqrt

component SqrtLutExample
{
    sqrt: SqrtLUT

    new()
    {
        sqrt = new SqrtLUT()
    }

    public fn Run()
    {
        var root144: int = sqrt.Compute(144)
        var rootLarge: int = sqrt.Compute(300)
    }
}
```

Use `SqrtNewtonRaphson` for larger integer inputs. Inputs outside `[0, 32767]`
are clamped.

```livt
namespace Example

using Livt.Math.Sqrt

component SqrtNewtonExample
{
    sqrt: SqrtNewtonRaphson

    new()
    {
        sqrt = new SqrtNewtonRaphson()
    }

    public fn Run()
    {
        var root32766: int = sqrt.Compute(32766)
        var rootClamped: int = sqrt.Compute(40000)
    }
}
```

## Saturating Multiply-Accumulate

`MacUnit` stores a signed 16-bit accumulator. Each `Accumulate(a, b)` call adds
`a * b` and clamps the stored result to `[-32768, 32767]`.

```livt
namespace Example

using Livt.Math.Arithmetic

component MacExample
{
    mac: MacUnit

    new()
    {
        mac = new MacUnit()
    }

    public fn Run()
    {
        mac.Reset()
        mac.Accumulate(1, 4)
        mac.Accumulate(2, 5)
        mac.Accumulate(3, 6)
        var dot: int = mac.GetResult()
    }
}
```

## Fixed-Point Formats

Use named fixed-point helpers when values have a clear scale. `Q15` is the
default choice for normalized signed DSP coefficients, while `Q7` is compact and
`UQ8` is useful for unsigned normalized values such as duty cycles. Fixed-point
operations store their latest value in the helper component; call `GetResult()`
after each operation that you want to read.

```livt
namespace Example

using Livt.Math.FixedPoint

component FixedPointExample
{
    q15: Q15
    uq8: UQ8

    new()
    {
        q15 = new Q15()
        uq8 = new UQ8()
    }

    public fn Run()
    {
        var half: int = 16384
        q15.Mul(half, half)
        var quarter: int = q15.GetResult()
        q15.AddSaturating(32767, 10)
        var saturated: int = q15.GetResult()
        uq8.Mul(128, 128)
        var brightness: int = uq8.GetResult()
    }
}
```

## Q15 Complex Arithmetic

`ComplexQ15` stores a complex value in Q15 format and exposes the latest result
through explicit read methods.

```livt
namespace Example

using Livt.Math.Complex
using Livt.Math.FixedPoint

component ComplexExample
{
    value: ComplexQ15

    new()
    {
        value = new ComplexQ15()
    }

    public fn Run()
    {
        value.Set(16384, 0)
        value.MulByTwiddle(0, 32767)
        var real: int = value.GetResultReal()
        var imag: int = value.GetResultImag()
    }
}
```

## Q15 Lookup Constants

Use `TrigQ15` for small deterministic sine/cosine values. It is intentionally a
lookup helper, not a full transform implementation.

```livt
namespace Example

using Livt.Math.Lookup

component LookupExample
{
    trig: TrigQ15

    new()
    {
        trig = new TrigQ15()
    }

    public fn Run()
    {
        var cos45: int = trig.Cos(1, 8)
        var sin90: int = trig.Sin(1, 4)
    }
}
```
