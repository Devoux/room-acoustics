# Room Acoustic Measurement Toolkit

MATLAB scripts for measuring room impulse responses using Exponential Sine Sweeps (ESS) and computing ISO 3382 acoustic parameters (T20, T30, D50, C50, D80, C80, Ts).

## Requirements

- MATLAB R2020b+ (uses `exportgraphics`, `movmean`, `jsonencode`)
- No additional toolboxes

## Quick Start

1. Generate the excitation signal:
   ```
   >> generate_ess
   ```
   Creates `data/ess/ess_10s.wav` (10 s sweep, 20–20 kHz, 48 kHz sample rate).

2. Play the sweep in each room and record the response. Save recordings as `.wav` files under `data/raw/ROOM_NAME/`.

3. Optionally create `_meta.json` files alongside each recording (see below).

4. Edit the `rooms` struct in `main.m` to list your rooms and measurement positions.

5. Run:
   ```
   >> main
   ```
   Outputs appear in `data/processed/` (IRs, parameter JSONs, room summaries) and `figures/` (per-position and per-room PDFs).

## Directory Layout

```
data/ess/                          Excitation signals
data/raw/ROOM_NAME/*.wav           Raw recordings
data/raw/ROOM_NAME/*_meta.json     Per-file metadata (optional)
data/processed/ROOM_NAME/*_ir.wav  Recovered impulse responses
data/processed/ROOM_NAME/*_params.json
data/processed/ROOM_NAME/summary.json
figures/ROOM_NAME/*.pdf            Per-position 3-panel figures
figures/ROOM_NAME/summary.pdf      Room-level comparison
```

## Metadata Format

Optional JSON file placed next to each recording. All fields are optional:

```json
{
    "f1": 20,
    "f2": 20000,
    "out_ch": 1,
    "hvac": "on",
    "notes": "Front row center, mic at 1.2m, 3m from source"
}
```

If `f1`/`f2` are omitted, the sweep bandwidth is estimated automatically from the signal. Specifying them is recommended when known.

## Scripts

| File | Purpose |
|---|---|
| `main.m` | Orchestrator — defines rooms, paths, and analysis settings |
| `deconvolve.m` | Farina inverse filter deconvolution, Lundeby truncation, parameter extraction |
| `plot_ir.m` | Per-position 3-panel figure (IR, IR in dB, EDC) |
| `plot_summary.m` | Per-room summary (EDC overlay + parameter dot-strip with ±1σ) |
| `generate_ess.m` | Generates the ESS excitation wav file |

## Method

Deconvolution uses the Farina analytical inverse filter (time-reversed sweep with exponential amplitude decay). No regularization parameter to tune. The Lundeby algorithm (adaptive window) finds the noise-floor truncation point, and the Schroeder backward integral with Chu correction produces the energy decay curve. Reverberation times are extracted by linear regression on the EDC per ISO 3382.

## References

- Farina, A. (2000). "Simultaneous measurement of impulse response and distortion with a swept-sine technique." 108th AES Convention.
- Lundeby, Vigran, Bietz & Vorländer (1995). "Uncertainties of measurements in room acoustics." Acustica 81, 344–355.
- Chu, W.T. (1978). "Comparison of reverberation measurements using Schroeder's impulse method and decay-curve averaging method." JASA 63(5).
- ISO 3382-1:2009, ISO 3382-2:2008.