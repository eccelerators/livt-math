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
