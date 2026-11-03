# Usage Examples

`Livt.Math` exposes fixed-size arithmetic components. These examples show the
basic call order and boundary behavior expected by the package.

## Bounded Stream Statistics

Use `StreamingMomentsInt16` when a finite block needs integer mean, population
variance, and standard deviation without retaining its samples. Finalize after
the block has been added, and check its Boolean result before reading the
finalized fields.

```livt
namespace Example

using Livt.Math.Statistics

component BlockStatisticsExample
{
    statistics: StreamingMomentsInt16<256>

    new()
    {
        statistics = new StreamingMomentsInt16<256>()
    }

    public fn Summarize()
    {
        statistics.Reset()
        statistics.Add(-12)
        statistics.Add(4)
        statistics.Add(20)

        if (statistics.Finalize()) {
            var mean: int = statistics.GetMean()
            var variance: uint = statistics.GetVariance()
            var deviation: uint = statistics.GetStdDev()
        }
    }
}
```

## Integer Helpers

Use the context-free integer helpers for reusable combinational selection,
magnitude, and saturating arithmetic. `Magnitude` returns `uint` so the magnitude
of signed `int` minimum remains representable. `AbsSaturating` returns `int` and
saturates that one value to signed maximum.

```livt
namespace Example

using Livt.Math.Arithmetic

component IntegerMathExample
{
	public fn Run()
	{
		var bounded: int = IntegerMath.Clamp(120, -100, 100)
		var magnitude: uint = IntegerMath.Magnitude(-2147483647 - 1)
		var signedSum: int = IntegerMath.AddSaturating(2147483647, 1)
		var unsignedDifference: uint = UnsignedMath.SubSaturating(3, 7)
	}
}
```

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
`UQ8` is useful for unsigned normalized values such as duty cycles.

For reusable combinational arithmetic, call the static context-free helpers
directly. They return values and do not require a component instance.

```livt
namespace Example

using Livt.Math.FixedPoint

component FixedPointExample
{
    public fn Run()
    {
        var half: int = 16384
        var quarter: int = Q15.MulValue(half, half)
        var saturated: int = Q15.AddSaturatingValue(32767, 10)
        var brightness: int = UQ8.MulValue(128, 128)
    }
}
```

Stateful calls remain available when a component should store the latest result.

```livt
namespace Example

using Livt.Math.FixedPoint

component StatefulFixedPointExample
{
    q15: Q15

    new()
    {
        q15 = new Q15()
    }

    public fn Run()
    {
        q15.Mul(16384, 16384)
        var quarter: int = q15.GetResult()
    }
}
```

## Q15 Complex Arithmetic

`ComplexQ15` stores a complex value in Q15 format and exposes the latest result
through explicit read methods. Static helpers are available for direct complex
composition when an algorithm wants real and imaginary parts as values.

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

        var directReal: int = ComplexQ15.MulReal(16384, 0, 0, 32767)
        var directImag: int = ComplexQ15.MulImag(16384, 0, 0, 32767)
    }
}
```

## Q15 Lookup Constants

Use `TrigQ15` for small deterministic sine/cosine values. It is intentionally a
lookup helper, not a full transform implementation. FFT orchestration belongs in
a DSP/signal-processing package that depends on these primitives.

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

## Arbitrary Q15 Sine and Cosine

Use the scheduled CORDIC worker when the phase is not one of the common values
provided by `TrigQ15`. Phase units map 32768 to π radians, so 8192 represents
π/4. A successful call retains both Q1.15 results.

```livt
namespace Example

using Livt.Math.Trigonometry

component CordicExample
{
    cordic: CordicSinCosQ15

    new()
    {
        cordic = new CordicSinCosQ15()
    }

    public fn Run() bool
    {
        if (!cordic.Compute(CordicSinCosQ15.QUARTER_PI)) {
            return false
        }

        var sine: int = cordic.GetSin()
        var cosine: int = cordic.GetCos()
        return true
    }
}
```

See [`CordicSinCosQ15.md`](CordicSinCosQ15.md) for the numeric error and
lifecycle contract.

## Q15 Vector Phase and Magnitude

Use the vectoring CORDIC worker to convert a nonzero Cartesian Q1.15 vector into
canonical phase and unsigned magnitude. Magnitude keeps 15 fractional bits and
can represent the complete diagonal range.

```livt
namespace Example

using Livt.Math.Trigonometry

component VectoringExample
{
    cordic: CordicAtan2MagnitudeQ15

    new()
    {
        cordic = new CordicAtan2MagnitudeQ15()
    }

    public fn Run() bool
    {
        if (!cordic.Compute(23170, 23170)) {
            return false
        }

        var phase: int = cordic.GetPhase()
        var magnitude: uint = cordic.GetMagnitude()
        return true
    }
}
```

See [`CordicAtan2MagnitudeQ15.md`](CordicAtan2MagnitudeQ15.md) for the numeric
and lifecycle contracts.

## Fixed-Point Logarithm, Exponential, and Reciprocal

The special-function components use paired, bounded formats suitable for FPGA
gain and compression paths.

```livt
namespace Example

using Livt.Math.Approximation
using Livt.Math.FixedPoint

component SpecialFunctionExample
{
    logarithm: Log2UQ15
    exponential: Exp2Q11
    reciprocal: ReciprocalUQ15

    new()
    {
        logarithm = new Log2UQ15()
        exponential = new Exp2Q11()
        reciprocal = new ReciprocalUQ15()
    }

    public fn Run() bool
    {
        if (!logarithm.Compute(46341 as uint)) {
            return false
        }

        var logValue: int = logarithm.GetResult()
        if (!exponential.Compute(logValue)) {
            return false
        }

        var restored: uint = exponential.GetResult()
        var inverse: uint = reciprocal.Compute(24576 as uint)
        return restored > (0 as uint) && inverse > (0 as uint)
    }
}
```

See [`SpecialFunctions.md`](SpecialFunctions.md) for the numeric and lifecycle
contracts.
