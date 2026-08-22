# DSP and Agent contract

## Input priority

When inputs conflict, use this order:

1. Runtime decode/render measurements and clipping evidence
2. Current output route and its measured device baseline
3. Time-aggregated loudness, peak, dynamics, spectrum, stereo and phase measurements
4. Explicit listening goal
5. Retained preference with confidence and provenance
6. Metadata, genre labels and model priors

Clipping, headroom, phase, route, and measured-response data take precedence over
lower-ranked inputs.

## Stage roles

| Stage | Purpose | Avoid |
| --- | --- | --- |
| Device baseline | Repeatable output-device correction | Track voicing or provider-authored replacement |
| Graphic EQ | Broad stable tonal balance | Narrow resonances and saw-tooth curves |
| PEQ | Repeatable selective defects | Speculative high-Q notches or duplicate shelves |
| Compressor | Bounded time-varying density | Automatic loudness chasing |
| Stereo width | Controlled image width | Tonal repair or unsafe phase tricks |
| Preamp and limiter | Combined headroom and peak containment | Loudness maximization |

Keep the same order in validators, FFmpeg filters, and platform executors.

Treat external headphone-calibration sources, including OPRA-shaped datasets,
as adapter inputs rather than built-in Core knowledge. Resolve licensing,
dataset versioning, route matching, and interpolation outside the render path;
then convert the selected result to the route-owned 10- or 32-band
`deviceBaseline`. `MonoAudioCore` does not include an OPRA lookup engine.

## Current validator envelope

These ranges match `MonoAudioPlanValidator`:

- Graphic EQ: exactly 10 or 32 gains; every gain `-12...12 dB`; maximum adjacent jump `4.5 dB` for 10-band and `3 dB` for 32-band.
- PEQ: at most 12 bands; enabled bands use `20...20,000 Hz`, `-12...12 dB`, and `Q 0.1...12`.
- Compressor when enabled: threshold `-60...0 dB`, ratio `1...6`, attack `0.1...500 ms`, release `10...2,000 ms`, makeup `0...6 dB`.
- Stereo width: `0.75...1.5`.
- Output safety: preamp `-24...0 dB`, limiter ceiling `-6...-0.05 dBFS`, uncertainty margin `0...3 dB`.
- A disabled limiter is a warning. Insufficient headroom is an error.

The current headroom recommendation is the negative sum of:

1. the largest positive combined device-baseline plus graphic-EQ band,
2. all positive enabled PEQ gains,
3. compressor makeup when enabled,
4. the positive stereo-width allowance,
5. the uncertainty margin.

Clamp the recommendation at `0 dB` or below. Do not replace this conservative bound with measured peak alone; the validator must remain deterministic without audio access.

## Agent boundary

1. Capture measurements and route identity outside the render callback.
2. Construct `MonoAudioTuningRequest` with the requested band mode and route-owned baseline.
3. Let `MonoAudioAgentProvider` return a proposal. The provider may be local, remote, rule-based, or model-backed.
4. Let `MonoAudioAgent` restore the request's baseline and verify the requested mode.
5. Reject stale generations and every invalid report before execution.
6. Apply through a `MonoAudioPlanExecutor`; do not let the provider mutate the player directly.

When provider confidence is low, prefer a flat curve, fewer PEQ bands, disabled compression, width near `1`, and conservative output safety. A dense low-crest source is not evidence for more compression. Negative phase correlation is evidence against widening.

## Realtime rules

- Precompute filter coefficients and conversion state away from the audio thread.
- Smooth gain, frequency, Q, width, bypass and plan swaps.
- Avoid allocation, locks, file I/O, logging, inference, JSON parsing, and networking in render callbacks.
- Invalidate work when asset, stream variant, output identity, baseline, or graphic mode changes.
- Verify mono compatibility and low-frequency centering before widening.
