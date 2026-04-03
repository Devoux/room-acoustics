function plot_ir(h, params, fs, label, outFile, irLenSec)
% PLOT_IR  Three-panel impulse response figure, saved to PDF.
%
%   plot_ir(h, params, fs, label, outFile, irLenSec)
%
%   Inputs
%     h         : impulse response (column vector, peak-normalised)
%     params    : struct from deconvolve() — must contain .edc_dB, .lundeby_idx
%     fs        : sample rate [Hz]
%     label     : title string (e.g. 'src1_front')
%     outFile   : full path for the output PDF
%     irLenSec  : x-axis limit [s]

    tIR = (0:numel(h)-1)' / fs;
    tMs = tIR * 1000;
    xlimMs = irLenSec * 1000;

    fig = figure('Name', label, 'Position', [100 100 900 700], 'Visible', 'off');

    % --- Panel 1: Impulse response (linear) ---
    subplot(3,1,1);
    plot(tMs, h, 'Color', [0.1 0.3 0.7]);
    xlabel('Time [ms]');  ylabel('Amplitude');
    title(sprintf('Impulse Response  —  %s', strrep(label, '_', '\_')));
    xlim([0 xlimMs]);
    grid on;

    % --- Panel 2: Impulse response (dB) ---
    subplot(3,1,2);
    h_dB = 20*log10(abs(h) / max(abs(h)) + eps);
    plot(tMs, h_dB, 'Color', [0.1 0.3 0.7]);
    xlabel('Time [ms]');  ylabel('Level [dB]');
    title('Impulse Response (dB)');
    xlim([0 xlimMs]);  ylim([-80 0]);
    grid on;

    % --- Panel 3: Energy Decay Curve ---
    subplot(3,1,3);
    edc_dB = params.edc_dB;
    tEDC = (0:numel(edc_dB)-1)' / fs * 1000;
    plot(tEDC, edc_dB, 'Color', [0.8 0.15 0.15], 'LineWidth', 1.3);
    hold on;
    truncMs = (params.lundeby_idx - 1) / fs * 1000;
    xline(truncMs, '--k', 'Lundeby trunc.', ...
          'LabelVerticalAlignment', 'bottom');
    xlabel('Time [ms]');  ylabel('EDC [dB]');
    title('Energy Decay Curve (Schroeder)');
    xlim([0 xlimMs]);  ylim([-80 0]);
    grid on;

    % --- Super title with key parameters ---
    sgtitle(sprintf('%s     T20=%.2fs  D50=%.0f%%  C80=%.1fdB', ...
        strrep(label, '_', '\_'), params.T20, params.D50*100, params.C80), ...
        'FontWeight', 'bold', 'FontSize', 11);

    % --- Save ---
    exportgraphics(fig, outFile, 'ContentType', 'vector');
    close(fig);
end
