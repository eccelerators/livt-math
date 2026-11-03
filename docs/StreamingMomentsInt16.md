# Streaming signed-16 moments

`Livt.Math.Statistics.StreamingMomentsInt16<MAX_SAMPLES>` computes exact
aggregate moments for a bounded finite stream without storing its samples. It is
suited to calibration, telemetry summaries, block statistics, and normalization
setup where the complete block is known before its statistics are consumed.

The component accepts signed 16-bit samples and supports capacities from 1 to
65,535. It retains an exact count, signed sum, and sum of squares. One scheduled
wide-arithmetic worker is shared across accumulation and finalization.

## Results

After at least one accepted sample, `Finalize()` produces:

- `GetMean()`: arithmetic mean rounded to nearest, with exact ties rounded to
  the even integer;
- `GetVariance()`: floor of the population variance, dividing by the sample
  count rather than `count - 1`;
- `GetStdDev()`: floor of the square root of the floored population variance.

`GetCount()` and `GetSum()` expose the live aggregate before or after
finalization. `HasResult()` identifies whether the finalized fields are valid.

## Lifecycle and rejection

`Reset()` clears the aggregate and finalized result. `Add(sample)` returns
`false` without changing state when the sample is outside `-32768..32767` or
the configured capacity is full. An accepted sample invalidates the previous
finalized result. An empty `Finalize()` returns `false` and leaves finalized
fields cleared.

The owner must serialize calls that mutate or finalize the component. Calls are
scheduled because they reuse the component's single wide-arithmetic worker.

## Package boundary

This component summarizes one finite stream and deliberately does not retain a
window. Moving averages, rolling variance, median filters, and ready/valid
sample-stream adapters belong in `Livt.Signal`, where window memory, update
rate, and backpressure can be expressed as signal-processing contracts.
