function [h, params, fs] = deconvolve(essFile, recFile, cfg)
% DECONVOLVE  Recover room impulse response from ESS measurement.
%
%   [h, params, fs] = deconvolve(essFile, recFile, cfg)
%
%   Inputs
%     essFile : path to the ESS excitation wav file
%     recFile : path to the recorded room response wav file
%     cfg     : struct with fields:
%                 .irLenSec  — max IR length to keep [s]
%                 .outChPref — preferred output channel index
%                 .t_D50     — early/late boundary for D50 [ms]
%                 .t_D80     — early/late boundary for D80 [ms]
%                 .f1        — ESS start frequency [Hz] ([] = auto)
%                 .f2        — ESS end frequency [Hz]   ([] = auto)
%
%   Outputs
%     h      : recovered impulse response (column vector, peak-normalised)
%     params : struct with T20, T30, D50, C50, D80, C80, Ts, and metadata
%     fs     : sample rate [Hz]

    % ==================================================================
    %  1. Read audio
    % ==================================================================
    [inRaw,  fsIn]  = audioread(essFile);
    [outRaw, fsOut] = audioread(recFile);
    assert(fsIn == fsOut, ...
        'Sample rates differ: ESS = %d Hz, recording = %d Hz.', fsIn, fsOut);
    fs = fsIn;

    % Channel selection
    inCh  = detect_sweep_channel(inRaw);
    outCh = select_channel(outRaw, cfg.outChPref);

    x = inRaw(:, inCh);
    y = outRaw(:, outCh);

    fprintf('  fs = %d Hz,  in ch = %d/%d,  out ch = %d/%d,  x: %.2f s,  y: %.2f s\n', ...
            fs, inCh, size(inRaw,2), outCh, size(outRaw,2), ...
            numel(x)/fs, numel(y)/fs);

    % ==================================================================
    %  2. Farina inverse filter deconvolution
    % ==================================================================

    % Strip silence padding
    xPeak     = max(abs(x));
    activeIdx = find(abs(x) > 0.05 * xPeak);
    xSweep    = x(activeIdx(1) : activeIdx(end));

    % Determine sweep rate R
    if ~isempty(cfg.f1) && ~isempty(cfg.f2)
        f1_use = cfg.f1;
        f2_use = cfg.f2;
        R_use  = log(f2_use / f1_use);
        fprintf('  ESS bandwidth: %.0f – %.0f Hz  (R = %.2f)  [user-specified]\n', ...
                f1_use, f2_use, R_use);
    else
        [f1_use, f2_use, R_use] = estimate_ess_rate(xSweep, fs);
        fprintf('  ESS bandwidth: %.0f – %.0f Hz  (R = %.2f)  [auto-estimated]\n', ...
                f1_use, f2_use, R_use);
        if R_use < 1.0
            warning('deconvolve:lowR', ...
                'Estimated R = %.2f is suspiciously low — consider specifying f1/f2.', R_use);
        end
    end

    % Build inverse filter
    Ns    = numel(xSweep);
    x_inv = flipud(xSweep);
    decay = exp(-(0:Ns-1)' * R_use / (Ns - 1));
    x_inv = x_inv .* decay;

    % Normalise via auto-deconvolution
    Nfft_auto  = 2^nextpow2(2 * Ns);
    autoDeconv = real(ifft(fft(xSweep, Nfft_auto) .* fft(x_inv, Nfft_auto)));
    x_inv = x_inv / max(abs(autoDeconv));

    % Deconvolve
    Nfft = 2^nextpow2(numel(y) + Ns - 1);
    Y    = fft(y, Nfft);
    Xinv = fft(x_inv, Nfft);
    hRaw = real(ifft(Y .* Xinv));

    % ==================================================================
    %  3. Trim IR
    % ==================================================================
    irMaxSamples = round(cfg.irLenSec * fs);
    halfLen = floor(Nfft / 2);
    [~, pkIdx] = max(abs(hRaw(1:halfLen)));

    preMargin = round(0.002 * fs);
    idxStart  = max(1, pkIdx - preMargin);
    idxEnd    = min(numel(hRaw), idxStart + irMaxSamples - 1);
    h = hRaw(idxStart:idxEnd);

    fprintf('  IR length kept: %d samples (%.3f s)\n', numel(h), numel(h)/fs);

    % Normalise
    h = h / max(abs(h));

    % ==================================================================
    %  4. EDC and room parameters
    % ==================================================================
    [edc_dB, ~, lundebyIdx] = schroeder_edc_lundeby(h, fs);
    p = room_parameters(h, fs, cfg.t_D50, cfg.t_D80, lundebyIdx);

    % ==================================================================
    %  5. Build output params struct
    % ==================================================================
    params.T20  = p.T20;
    params.T30  = p.T30;
    params.D50  = p.D50;
    params.C50  = p.C50;
    params.D80  = p.D80;
    params.C80  = p.C80;
    params.Ts   = p.Ts;
    params.fs   = fs;
    params.ir_length_s    = numel(h) / fs;
    params.ess_bandwidth  = [f1_use, f2_use];
    params.R              = R_use;
    params.lundeby_idx    = lundebyIdx;
    params.edc_dB         = edc_dB;

    fprintf('  T20   = %.4f s\n', params.T20);
    fprintf('  T30   = %.4f s\n', params.T30);
    fprintf('  D50   = %.1f %%   (C50 = %.1f dB)\n', params.D50*100, params.C50);
    fprintf('  D80   = %.1f %%   (C80 = %.1f dB)\n', params.D80*100, params.C80);
    fprintf('  Ts    = %.1f ms\n', params.Ts*1000);
end


%% ====================================================================
%  LOCAL FUNCTIONS
%  ====================================================================

function [f1, f2, R] = estimate_ess_rate(x, fs)
% ESTIMATE_ESS_RATE  Estimate ESS sweep rate from zero-crossing periods.

    xPeak     = max(abs(x));
    activeIdx = find(abs(x) > 0.05 * xPeak);

    if numel(activeIdx) < 2
        warning('estimate_ess_rate:noSignal', ...
            'Could not detect sweep — using fallback R.');
        f1 = 20; f2 = 20000; R = log(f2/f1);
        return;
    end

    startIdx = activeIdx(1);
    endIdx   = activeIdx(end);
    sweepLen = endIdx - startIdx + 1;

    % f1: period of the first few cycles
    searchLen1 = min(sweepLen, max(round(2.0 * fs), round(0.2 * sweepLen)));
    seg1 = x(startIdx : startIdx + searchLen1 - 1);
    zcIdx1 = find(diff(sign(seg1)) ~= 0);
    if numel(zcIdx1) >= 8
        period1 = (zcIdx1(7) - zcIdx1(3)) / 2;
        f1 = fs / period1;
    elseif numel(zcIdx1) >= 4
        period1 = (zcIdx1(end) - zcIdx1(1)) / (floor(numel(zcIdx1)/2));
        f1 = fs / period1;
    else
        f1 = 20;
    end

    % f2: period of the last few cycles
    searchLen2 = min(sweepLen, max(round(0.05 * fs), round(0.01 * sweepLen)));
    seg2 = x(endIdx - searchLen2 + 1 : endIdx);
    zcIdx2 = find(diff(sign(seg2)) ~= 0);
    if numel(zcIdx2) >= 8
        nzc = numel(zcIdx2);
        period2 = (zcIdx2(nzc-2) - zcIdx2(nzc-6)) / 2;
        f2 = fs / period2;
    elseif numel(zcIdx2) >= 4
        period2 = (zcIdx2(end) - zcIdx2(1)) / (floor(numel(zcIdx2)/2));
        f2 = fs / period2;
    else
        f2 = fs / 2 * 0.9;
    end

    f1 = max(f1, 1);
    f2 = max(f2, f1 * 2);
    f2 = min(f2, fs / 2);
    R  = log(f2 / f1);
end


function ch = detect_sweep_channel(audio)
% DETECT_SWEEP_CHANNEL  Pick the channel with the highest RMS energy.

    nCh = size(audio, 2);
    if nCh == 1, ch = 1; return; end

    rmsVals = rms(audio, 1);
    [~, ch] = max(rmsVals);

    otherRms = rmsVals;  otherRms(ch) = [];
    if ~isempty(otherRms)
        margin_dB = 20*log10(rmsVals(ch) / max(otherRms));
        if margin_dB < 20
            warning('detect_sweep_channel:lowMargin', ...
                'Sweep channel %d is only %.1f dB above next loudest.', ch, margin_dB);
        end
    end
end


function ch = select_channel(audio, preferred)
% SELECT_CHANNEL  Use preferred channel if available, else fall back.

    nCh = size(audio, 2);

    if nCh == 1
        ch = 1;
        if preferred ~= 1
            fprintf('  (output is mono — using channel 1 instead of %d)\n', preferred);
        end
        return;
    end

    if preferred <= nCh
        ch = preferred;
        return;
    end

    rmsVals = rms(audio, 1);
    [~, ch] = max(rmsVals);
    warning('select_channel:fallback', ...
        'Requested ch %d but file has only %d channels — using ch %d (loudest).', ...
        preferred, nCh, ch);
end


function [edc_dB, t, truncIdx] = schroeder_edc_lundeby(h, fs)
% SCHROEDER_EDC_LUNDEBY  EDC with adaptive Lundeby truncation.

    N = numel(h);
    t = (0:N-1)' / fs;

    % --- Adaptive window: coarse RT estimate first ---
    nTargetWins = 30;
    minWinMs = 2;  maxWinMs = 50;

    coarseWinLen = max(1, round(0.020 * fs));
    nCoarse = floor(N / coarseWinLen);
    coarseE = zeros(nCoarse, 1);
    coarseT = zeros(nCoarse, 1);
    for k = 1:nCoarse
        seg = h((k-1)*coarseWinLen+1 : k*coarseWinLen);
        coarseE(k) = mean(seg.^2);
        coarseT(k) = ((k-1)*coarseWinLen + coarseWinLen/2) / fs;
    end
    coarseE_dB = 10*log10(coarseE + eps);

    nfIdx = max(1, round(0.9 * nCoarse));
    prelimNoise = 10*log10(mean(coarseE(nfIdx:end)) + eps);

    crossC = find(coarseE_dB < prelimNoise + 10, 1, 'first');
    if isempty(crossC) || crossC < 3, crossC = nCoarse; end
    pkC = find(coarseE_dB == max(coarseE_dB(1:crossC)), 1);
    if isempty(pkC), pkC = 1; end
    regC = pkC:crossC;
    if numel(regC) >= 3
        pC = polyfit(coarseT(regC), coarseE_dB(regC), 1);
        if pC(1) < 0
            coarseRT = -60 / pC(1);
        else
            coarseRT = N / fs;
        end
    else
        coarseRT = N / fs;
    end

    adaptiveWinMs = max(minWinMs, min(maxWinMs, coarseRT * 1000 / nTargetWins));
    winLen = max(1, round(adaptiveWinMs * 1e-3 * fs));

    fprintf('  Lundeby: coarse T60 ≈ %.3f s  →  adaptive window = %.1f ms\n', ...
            coarseRT, adaptiveWinMs);

    % --- Build energy envelope ---
    nWins = floor(N / winLen);
    envE  = zeros(nWins, 1);
    envT  = zeros(nWins, 1);
    for k = 1:nWins
        seg = h((k-1)*winLen+1 : k*winLen);
        envE(k) = mean(seg.^2);
        envT(k) = ((k-1)*winLen + winLen/2) / fs;
    end
    envE_dB = 10*log10(envE + eps);

    nfIdx2 = max(1, round(0.9 * nWins));
    noiseFloor = 10*log10(mean(envE(nfIdx2:end)) + eps);

    % --- Iterative Lundeby ---
    maxIter = 5;
    crossSample = N;
    for iter = 1:maxIter
        crossIdx = find(envE_dB < noiseFloor + 5, 1, 'first');
        if isempty(crossIdx) || crossIdx < 3, crossIdx = nWins; end

        peakWin = find(envE_dB == max(envE_dB(1:min(crossIdx, nWins))), 1);
        if isempty(peakWin), peakWin = 1; end
        regRange = peakWin : min(crossIdx, nWins);
        if numel(regRange) < 3, break; end

        p = polyfit(envT(regRange), envE_dB(regRange), 1);
        if p(1) >= 0, break; end

        tCross = (noiseFloor - p(2)) / p(1);
        crossSample = round(tCross * fs);
        crossSample = min(max(crossSample, 1), N);

        margin = round(0.05 * fs);
        noiseStart = min(crossSample + margin, N - winLen);
        if noiseStart < N
            noiseFloor = 10*log10(mean(h(noiseStart:end).^2) + eps);
        end
    end

    truncIdx = min(crossSample, N);

    % --- Schroeder integration with Chu correction ---
    h_trunc    = h(1:truncIdx);
    noisePower = mean(h(max(1,truncIdx):end).^2);
    edc_lin    = flipud(cumsum(flipud(h_trunc.^2)));
    noiseContrib = noisePower * (truncIdx:-1:1)' / fs;
    edc_lin    = max(edc_lin - noiseContrib, eps);

    edc_full = ones(N, 1) * edc_lin(end);
    edc_full(1:truncIdx) = edc_lin;
    edc_dB = 10*log10(edc_full / edc_full(1));
end


function params = room_parameters(h, fs, t_D50_ms, t_D80_ms, truncIdx)
% ROOM_PARAMETERS  Broadband room acoustic parameters from IR.

    N  = min(truncIdx, numel(h));
    hT = h(1:N);
    t  = (0:N-1)' / fs;
    h2 = hT.^2;
    totalEnergy = sum(h2);

    n50 = min(round(t_D50_ms * 1e-3 * fs), N);
    earlyE_50 = sum(h2(1:n50));
    lateE_50  = sum(h2(n50+1:end));
    params.D50 = earlyE_50 / totalEnergy;
    params.C50 = 10*log10(earlyE_50 / max(lateE_50, eps));

    n80 = min(round(t_D80_ms * 1e-3 * fs), N);
    earlyE_80 = sum(h2(1:n80));
    lateE_80  = sum(h2(n80+1:end));
    params.D80 = earlyE_80 / totalEnergy;
    params.C80 = 10*log10(earlyE_80 / max(lateE_80, eps));

    params.Ts = sum(t .* h2) / totalEnergy;

    edc_lin = flipud(cumsum(flipud(h2)));
    edc_dB  = 10*log10(edc_lin / edc_lin(1) + eps);
    params.T20 = rt_from_edc(edc_dB, t, -5, -25);
    params.T30 = rt_from_edc(edc_dB, t, -5, -35);
end


function RT = rt_from_edc(edc_dB, t, upperLim, lowerLim)
% RT_FROM_EDC  Reverberation time by least-squares fit to EDC.

    idx = (edc_dB >= lowerLim) & (edc_dB <= upperLim);
    if sum(idx) < 3, RT = NaN; return; end
    p = polyfit(t(idx), edc_dB(idx), 1);
    if p(1) >= 0, RT = NaN; return; end
    RT = -60 / p(1);
end
