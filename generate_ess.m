%% generate_ess.m
%  Generate an Exponential Sine Sweep (ESS) for room acoustic measurements.
%
%  Output: a mono .wav file containing [silence | sweep | silence]
%  suitable for playback through a loudspeaker while recording the
%  room response on a separate device.

clear; close all; clc;

%% Configuration
outFile = 'ess_10s.wav';

fs           = 48000;    % sample rate [Hz]  (match your recording device)
sweepDurSec  = 10;       % sweep duration [s]
f1           = 20;       % start frequency [Hz]
f2           = 20000;    % end frequency   [Hz]
gain_dB      = -3;       % peak level [dBFS]  (-3 avoids clipping on cheap speakers)
fadeDurSec   = 0.010;    % fade in/out duration [s]
preSilSec    = 1.0;      % silence before sweep [s]  (settling time)
postSilSec   = 3.0;      % silence after sweep [s]   (capture reverb tail)

%% Generate sweep
N = round(sweepDurSec * fs);
t = (0:N-1)' / fs;
R = log(f2 / f1);

sweep = sin(2*pi * f1 * sweepDurSec / R * (exp(t / sweepDurSec * R) - 1));

% Apply gain
sweep = sweep * 10^(gain_dB / 20);

% Fade in/out (half-Hann window)
nFade   = round(fadeDurSec * fs);
fadeIn  = 0.5 * (1 - cos(pi * (0:nFade-1)' / nFade));
fadeOut = 0.5 * (1 + cos(pi * (0:nFade-1)' / nFade));
sweep(1:nFade)         = sweep(1:nFade) .* fadeIn;
sweep(end-nFade+1:end) = sweep(end-nFade+1:end) .* fadeOut;

%% Assemble output: silence + sweep + silence
sig = [zeros(round(preSilSec * fs), 1); ...
       sweep; ...
       zeros(round(postSilSec * fs), 1)];

%% Write file
audiowrite(outFile, sig, fs, 'BitsPerSample', 24);

fprintf('Written: %s\n', outFile);
fprintf('  Sample rate:  %d Hz\n', fs);
fprintf('  Sweep:        %.1f s  (%.0f – %.0f Hz)\n', sweepDurSec, f1, f2);
fprintf('  Peak level:   %.0f dBFS\n', gain_dB);
fprintf('  Total length: %.1f s  (%.1f pre + %.1f sweep + %.1f post)\n', ...
    numel(sig)/fs, preSilSec, sweepDurSec, postSilSec);
fprintf('  R = ln(f2/f1) = %.4f\n', R);
