# Presentation Outline — Acoustic Quality of Northeastern Lecture Halls

12-minute presentation. 12 slides, ~1 minute each. Timing targets noted per section.

## Slide 1 — Title (0.5 min)

**Title:** "Acoustic Quality of Northeastern Lecture Halls: A Comparative Measurement Study"

- Team: Jack Cairo, Alder Nadon, Jeremy Yeh
- Course: ME 4505, Prof. Smyser
- Date

## Slide 2 — Problem Statement (1.0 min)

**Key question:** Do Northeastern's lecture halls differ meaningfully in acoustic quality for speech, and can we rank them?

- Students experience these rooms daily — some feel clear, others muddy
- No existing acoustic characterization of these spaces
- Goal: measure, compare, and rank 9 rooms using ISO 3382 parameters

## Slide 3 — Background: Room Acoustics for Speech (1.5 min)

**Left side:** Diagram of a room impulse response (direct sound, early reflections, reverberant tail). Use the IR panel from one of the `plot_ir` figures.

**Right side:** The two parameters the audience needs:

- **D50** — fraction of energy in first 50 ms (higher = clearer speech)
- **T20** — reverberation time (too long = muddy, too short = dead; optimal ~0.7 s)

One line: "These are standardized metrics from ISO 3382."

Don't define all 7 parameters — D50 and T20 are sufficient to follow the rest of the talk.

## Slide 4 — Rooms Measured (0.75 min)

Campus map or photo grid showing the 9 rooms.

| ID | Room | Description |
|---|---|---|
| 1 | EXP 204 | Large lecture hall |
| 2 | ISEC 102 | Large lecture hall |
| 3 | Snell 168 | Large auditorium |
| 4 | Robinson 109 | Medium classroom |
| 5 | Ell 002 | Medium lecture hall |
| 6 | Mugar 201 | Medium lecture hall |
| 7 | West Village G 108 | Small classroom |
| 8 | West Village F 020 | Small classroom |
| 9 | Shillman 215 | Medium lecture hall |

One line: "9 rooms, ranging from small classrooms to 200+ seat halls."

## Slide 5 — Measurement Setup & Protocol (1.25 min)

**Left:** Photo of actual setup (speaker, mic on stand, laptop).

**Right:** Diagram showing 2 source positions x 3 receiver positions = 6 measurements per room (54 total).

Equipment (3 bullets max):

- USB condenser mic (Jounivo JV-601, cardioid)
- Portable powered speaker
- Laptop running MATLAB

Protocol: room empty, doors closed, same equipment for all rooms.

Mic limitation (one line): "Cardioid USB mic — not ideal, but consistent across all rooms, so results are internally comparable."

**Transition:** "With this setup, we recorded 54 measurements total. Here's how we processed them."

## Slide 6 — Analysis Pipeline (1.0 min)

Flow diagram:

    ESS playback → Recording → Farina deconvolution → Impulse response
    → Lundeby truncation → Energy decay curve → ISO 3382 parameters

One bullet per step:

- Exponential sine sweep: known input, recover room response via deconvolution
- Lundeby algorithm: finds where the IR hits the noise floor, truncates cleanly
- Schroeder integration: energy decay curve, fit regression, extract T20/D50/etc.
- R-squared quality check: verify each T20 fit has R-squared > 0.99

Keep high-level — audience needs the logic, not the math.

## Slide 7 — Validation (0.5 min)

"Pipeline validated against 3 reference datasets before applying to campus data."

- Known-room dataset (TU Ilmenau): matched published T20
- Anechoic chamber (EPFL): confirmed D50 near 100%
- Synthetic ground truth: quantitative accuracy check

One or two sentences in narration — builds credibility fast.

## Slide 8 — Per-Room Results: Spatial Patterns (1.5 min)

**Figure:** One room's `summary.pdf` — pick a room with a clear spatial trend.

Walk through the 3 panels:

- **EDC overlay:** "Decay curves are consistent, truncated at noise floor"
- **D50 panel:** "D50 drops from ~85% at front to ~55% at back — expected, farther from speaker"
- **T20 panel:** "T20 is relatively stable across positions — it's a room property. R-squared values confirm good fits."

Pick a clean room for this example slide.

**Transition:** "This pattern is consistent across rooms. Now let's compare all 9."

## Slide 9 — Cross-Room Comparison (1.5 min)

**Figure:** `comparison_heatmap.pdf`

Walk the audience through:

- Rows = rooms (ranked best to worst), columns = parameters
- Blue = below average, red = above average, numbers = actual values
- Green target bands on parameter plots show which rooms meet ISO targets

Can briefly flash `comparison_parameters.pdf` for D50 or T20 to show individual data points with error bars.

**Takeaway:** "There's clear variation across rooms, especially in D50 and reverberation time."

## Slide 10 — Statistical Significance (1.0 min)

Simplified ANOVA results table (key parameters only):

| Parameter | F_room | p | Significant? |
|---|---|---|---|
| D50 | X.X | 0.XXX | Yes/No |
| T20 | X.X | 0.XXX | Yes/No |
| C80 | X.X | 0.XXX | Yes/No |

Key point: "We used a blocked ANOVA — source-receiver position is a systematic factor, not random noise. Removing it gave us 8x more degrees of freedom and tighter confidence intervals."

One line on Tukey HSD: "Post-hoc testing identified X significantly different room pairs for D50."

State the result and move on — don't linger on statistics.

## Slide 11 — Room Ranking (1.0 min)

**Figure:** `comparison_ranking.pdf`

Walk through:

- Composite score: 60% D50 + 40% T20 penalty from 0.7 s target
- Error bars from propagating measurement uncertainty through the composite
- Name the top 2-3 and bottom 2-3 rooms

Note: "Some adjacent rooms have overlapping error bars — we can't distinguish them statistically, but the overall spread is clear."

This is the payoff slide — the audience gets the answer to Slide 2's question.

## Slide 12 — Discussion & Conclusions (1.5 min)

**Limitations** (2-3 bullets):

- Uncalibrated cardioid mic: absolute values carry bias, but internal comparison is valid
- Single source type, not omnidirectional per ISO 3382-1
- Composite ranking is relative to these 9 rooms, not an absolute quality rating

**Key findings** (2-3 bullets):

- Room differences are [significant / partially significant] for [which parameters]
- [Best room] and [worst room] are clearly distinguishable; middle ranks overlap
- Spatial position has a large, systematic effect on clarity — the blocked design was essential

**Closing sentence:** "Rooms X and Y offer the best speech clarity; Room Z could benefit from acoustic treatment. The measurement toolkit developed here can be applied to any future campus spaces."

End clearly. Final sentence is the conclusion.

## Timing Budget

| Slides | Topic | Minutes |
|---|---|---|
| 1 | Title | 0.5 |
| 2 | Problem | 1.0 |
| 3 | Background | 1.5 |
| 4-5 | Rooms & Setup | 2.0 |
| 6-7 | Pipeline & Validation | 1.5 |
| 8 | Per-Room Example | 1.5 |
| 9-10 | Comparison & Statistics | 2.5 |
| 11 | Ranking | 1.0 |
| 12 | Discussion & Conclusions | 1.5 |
| | **Total** | **~12.0** |

## Slide Design Notes

- Max 4-5 bullets per slide, each under 10 words. Narrate the detail; slide shows the structure.
- One figure per slide for results. Don't shrink two plots onto one slide.
- Pipeline figures are vector PDFs — crop to the relevant panel if needed rather than showing the whole grid.
- Plain white or light grey background. No template decorations.
- Slide titles should be assertions, not topics: "D50 drops significantly with distance" beats "D50 Results."
