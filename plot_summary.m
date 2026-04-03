function plot_summary(allParams, allIRs, fs, roomName, outFile, irLenSec)
% PLOT_SUMMARY  Room-level summary figure with uncertainty analysis.
%
%   plot_summary(allParams, allIRs, fs, roomName, outFile, irLenSec)
%
%   Inputs
%     allParams : cell array of param structs (one per measurement)
%     allIRs    : cell array of IR vectors (one per measurement)
%     fs        : sample rate [Hz]
%     roomName  : room name string (for title)
%     outFile   : full path for the output PDF
%     irLenSec  : x-axis limit for EDC [s]
%
%   The figure has two panels:
%     Top:    EDC overlay — all positions superimposed
%     Bottom: Parameter dot-strip — individual values, mean, ±1σ

    nMeas  = numel(allParams);
    labels = cellfun(@(p) p.label, allParams, 'UniformOutput', false);

    % ================================================================
    %  Colour map: one colour per measurement
    % ================================================================
    cmap = lines(nMeas);

    fig = figure('Name', roomName, 'Position', [80 80 1000 800], 'Visible', 'off');

    % ================================================================
    %  Top panel: EDC overlay
    % ================================================================
    ax1 = subplot(2,1,1);
    hold(ax1, 'on');

    for k = 1:nMeas
        edc = allParams{k}.edc_dB;
        tMs = (0:numel(edc)-1)' / fs * 1000;
        plot(ax1, tMs, edc, 'Color', [cmap(k,:), 0.7], 'LineWidth', 1.0, ...
             'DisplayName', strrep(labels{k}, '_', '\_'));
    end

    xlabel(ax1, 'Time [ms]');
    ylabel(ax1, 'EDC [dB]');
    title(ax1, 'Energy Decay Curves — All Positions');
    xlim(ax1, [0 irLenSec * 1000]);
    ylim(ax1, [-80 0]);
    grid(ax1, 'on');
    legend(ax1, 'Location', 'northeast', 'FontSize', 7);

    % ================================================================
    %  Bottom panel: Parameter dot-strip with mean ± σ
    % ================================================================
    ax2 = subplot(2,1,2);
    hold(ax2, 'on');

    % Extract parameter vectors
    T20 = cellfun(@(p) p.T20, allParams);
    T30 = cellfun(@(p) p.T30, allParams);
    D50 = cellfun(@(p) p.D50, allParams) * 100;   % convert to %
    C80 = cellfun(@(p) p.C80, allParams);
    Ts  = cellfun(@(p) p.Ts,  allParams) * 1000;   % convert to ms

    paramNames  = {'T20 [s]', 'T30 [s]', 'D50 [%]', 'C80 [dB]', 'T_s [ms]'};
    paramValues = {T20, T30, D50, C80, Ts};
    nParams     = numel(paramNames);

    % Jitter dots horizontally so they don't overlap
    jitterWidth = 0.25;

    for pi = 1:nParams
        vals = paramValues{pi};
        mu   = mean(vals, 'omitnan');
        sig  = std(vals, 0, 'omitnan');

        % ±1σ shaded band
        fill(ax2, ...
            [pi-0.4, pi+0.4, pi+0.4, pi-0.4], ...
            [mu-sig, mu-sig, mu+sig, mu+sig], ...
            [0.7 0.85 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.5, ...
            'HandleVisibility', 'off');

        % Mean line
        plot(ax2, [pi-0.4, pi+0.4], [mu, mu], 'k-', 'LineWidth', 1.5, ...
             'HandleVisibility', 'off');

        % Individual dots with jitter
        jitter = (rand(size(vals)) - 0.5) * jitterWidth;
        for k = 1:nMeas
            plot(ax2, pi + jitter(k), vals(k), 'o', ...
                'MarkerSize', 6, 'MarkerFaceColor', cmap(k,:), ...
                'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');
        end

        % Annotate: mean ± σ
        text(ax2, pi, mu + sig + 0.08 * (max(vals) - min(vals) + eps), ...
            sprintf('%.2f±%.2f', mu, sig), ...
            'HorizontalAlignment', 'center', 'FontSize', 8, ...
            'VerticalAlignment', 'bottom');
    end

    set(ax2, 'XTick', 1:nParams, 'XTickLabel', paramNames);
    xlim(ax2, [0.3, nParams + 0.7]);
    ylabel(ax2, 'Value');
    title(ax2, sprintf('Room Parameters  (n = %d positions)', nMeas));
    grid(ax2, 'on');

    % ================================================================
    %  Super title
    % ================================================================
    sgtitle(sprintf('Room Summary:  %s', strrep(roomName, '_', '\_')), ...
            'FontWeight', 'bold', 'FontSize', 13);

    % ================================================================
    %  Save
    % ================================================================
    exportgraphics(fig, outFile, 'ContentType', 'vector');
    close(fig);
end
