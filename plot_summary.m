function plot_summary(allParams, allIRs, fs, roomName, outFile, irLenSec) %#ok<INUSL>
% PLOT_SUMMARY  Per-room summary: EDC overlay + spatial parameter trends.
%
%   plot_summary(allParams, allIRs, fs, roomName, outFile, irLenSec)
%
%   Three panels:
%     Top:    EDC overlay — coloured by receiver distance (front/mid/back),
%             styled by source (src1 solid, src2 dashed), truncated at
%             the Lundeby noise-floor point.
%     Middle: D50 vs receiver position by source, with target band (>50%).
%     Bottom: T20 vs receiver position by source, with target band (0.4–0.8 s).

    nMeas  = numel(allParams);
    labels = cellfun(@(p) p.label, allParams, 'UniformOutput', false);

    % ================================================================
    %  Parse labels → source number + distance index
    % ================================================================
    distNames = {'front', 'mid', 'back'};
    srcNum  = zeros(1, nMeas);    % 1 or 2
    distIdx = zeros(1, nMeas);    % 1=front, 2=mid, 3=back

    for k = 1:nMeas
        parts = strsplit(labels{k}, '_');
        srcNum(k)  = str2double(parts{1}(end));
        distIdx(k) = find(strcmp(distNames, parts{2}));
    end

    % ================================================================
    %  Colour / style scheme
    % ================================================================
    % EDC panel: colour by distance, line style by source
    distColors = [0.00 0.45 0.74;    % front — blue
                  0.47 0.67 0.19;    % mid   — green
                  0.85 0.33 0.10];   % back  — orange
    srcStyles  = {'-', '--'};

    % Parameter panels: colour + marker by source
    srcColors  = [0.00 0.45 0.74;    % src1 — blue
                  0.85 0.33 0.10];   % src2 — orange
    srcMarkers = {'o', '^'};

    bandColor = [0.75 0.92 0.75];

    fig = figure('Name', roomName, 'Position', [80 80 1000 900], 'Visible', 'off');

    % ================================================================
    %  Panel 1 (top): EDC overlay — truncated at Lundeby point
    % ================================================================
    ax1 = subplot(3, 1, 1);
    hold(ax1, 'on');

    for k = 1:nMeas
        edc    = allParams{k}.edc_dB(:);
        nPlot  = min(allParams{k}.lundeby_idx, numel(edc));
        edc    = edc(1:nPlot);
        tMs    = (0:nPlot-1)' / fs * 1000;

        col = distColors(distIdx(k), :);
        sty = srcStyles{srcNum(k)};

        plot(ax1, tMs, edc, sty, 'Color', [col, 0.8], 'LineWidth', 1.0, ...
             'DisplayName', strrep(labels{k}, '_', ' '));
    end

    xlabel(ax1, 'Time [ms]');
    ylabel(ax1, 'EDC [dB]');
    title(ax1, 'Energy Decay Curves  (truncated at Lundeby point)');
    xlim(ax1, [0, irLenSec * 1000]);
    ylim(ax1, [-80, 0]);
    grid(ax1, 'on');
    legend(ax1, 'Location', 'northeast', 'FontSize', 7);

    % ================================================================
    %  Panel 2 (middle): D50 vs receiver position
    % ================================================================
    ax2 = subplot(3, 1, 2);
    hold(ax2, 'on');

    D50_vals = cellfun(@(p) p.D50, allParams) * 100;   % → %

    % Y-range: include the 50% threshold so band is always visible
    ylo = min([D50_vals(:); 50]);
    yhi = max(D50_vals(:));
    ypad = 0.12 * (yhi - ylo + eps);

    % Target band: D50 > 50%
    fill(ax2, [0.5 3.5 3.5 0.5], [50 50 yhi+ypad yhi+ypad], ...
         bandColor, 'EdgeColor', 'none', 'FaceAlpha', 0.4, ...
         'HandleVisibility', 'off');

    for si = 1:2
        mask = srcNum == si;
        di = distIdx(mask);
        dv = D50_vals(mask);
        [di_s, ord] = sort(di);
        dv_s = dv(ord);

        plot(ax2, di_s, dv_s, srcStyles{si}, ...
             'Color', srcColors(si,:), 'LineWidth', 1.3, ...
             'Marker', srcMarkers{si}, 'MarkerSize', 7, ...
             'MarkerFaceColor', srcColors(si,:), ...
             'DisplayName', sprintf('Source %d', si));
    end

    ylim(ax2, [ylo - ypad, yhi + ypad]);
    set(ax2, 'XTick', 1:3, 'XTickLabel', {'Front', 'Mid', 'Back'});
    xlim(ax2, [0.5, 3.5]);
    ylabel(ax2, 'D_{50} [%]', 'Interpreter', 'tex');
    title(ax2, 'D_{50} — Speech Intelligibility vs Receiver Position', ...
          'Interpreter', 'tex');
    grid(ax2, 'on');
    legend(ax2, 'Location', 'best', 'FontSize', 8);

    % Target label
    yl2 = ylim(ax2);
    text(ax2, 3.4, yl2(2) - 0.06 * diff(yl2), 'Target: > 50%', ...
         'FontSize', 7, 'HorizontalAlignment', 'right', ...
         'BackgroundColor', bandColor, 'EdgeColor', [0.5 0.7 0.5], ...
         'Margin', 2);

    % ================================================================
    %  Panel 3 (bottom): T20 vs receiver position, with R² annotation
    % ================================================================
    ax3 = subplot(3, 1, 3);
    hold(ax3, 'on');

    T20_vals = cellfun(@(p) p.T20, allParams);
    T20_R2   = cellfun(@(p) p.T20_R2, allParams);

    % Y-range: include the 0.4–0.8 band so it is always visible
    ylo = min([T20_vals(:); 0.4]);
    yhi = max([T20_vals(:); 0.8]);
    ypad = 0.12 * (yhi - ylo + eps);

    % Target band: 0.4–0.8 s
    fill(ax3, [0.5 3.5 3.5 0.5], [0.4 0.4 0.8 0.8], ...
         bandColor, 'EdgeColor', 'none', 'FaceAlpha', 0.4, ...
         'HandleVisibility', 'off');

    R2_thresh = 0.99;
    voff = [1, -1] * 0.03 * (yhi - ylo + 2*ypad);   % text offset per source

    for si = 1:2
        mask = srcNum == si;
        di = distIdx(mask);
        tv = T20_vals(mask);
        r2 = T20_R2(mask);
        [di_s, ord] = sort(di);
        tv_s = tv(ord);
        r2_s = r2(ord);

        % Connecting line (no markers — drawn individually below)
        plot(ax3, di_s, tv_s, srcStyles{si}, ...
             'Color', srcColors(si,:), 'LineWidth', 1.3, ...
             'HandleVisibility', 'off');

        % Individual markers: filled = good fit, open = poor fit
        for j = 1:numel(di_s)
            if r2_s(j) >= R2_thresh
                mfc = srcColors(si,:);
            else
                mfc = 'none';
            end
            plot(ax3, di_s(j), tv_s(j), srcMarkers{si}, ...
                 'MarkerSize', 7, 'Color', srcColors(si,:), ...
                 'MarkerFaceColor', mfc, 'LineWidth', 1.2, ...
                 'HandleVisibility', 'off');

            % R² annotation
            text(ax3, di_s(j) + 0.08, tv_s(j) + voff(si), ...
                 sprintf('R^2=%.3f', r2_s(j)), ...
                 'FontSize', 5.5, 'Color', [0.4 0.4 0.4], ...
                 'Interpreter', 'tex');
        end

        % Invisible handle for legend
        plot(ax3, NaN, NaN, srcStyles{si}, ...
             'Color', srcColors(si,:), 'LineWidth', 1.3, ...
             'Marker', srcMarkers{si}, 'MarkerSize', 7, ...
             'MarkerFaceColor', srcColors(si,:), ...
             'DisplayName', sprintf('Source %d', si));
    end

    % Legend entry for open-marker meaning
    plot(ax3, NaN, NaN, 'o', 'MarkerSize', 7, ...
         'Color', [0.3 0.3 0.3], 'MarkerFaceColor', 'none', ...
         'LineWidth', 1.2, ...
         'DisplayName', sprintf('R^2 < %.2f', R2_thresh));

    ylim(ax3, [ylo - ypad, yhi + ypad]);
    set(ax3, 'XTick', 1:3, 'XTickLabel', {'Front', 'Mid', 'Back'});
    xlim(ax3, [0.5, 3.5]);
    ylabel(ax3, 'T_{20} [s]', 'Interpreter', 'tex');
    title(ax3, 'T_{20} — Reverberation Time vs Receiver Position', ...
          'Interpreter', 'tex');
    grid(ax3, 'on');
    legend(ax3, 'Location', 'best', 'FontSize', 8, 'Interpreter', 'tex');

    % Target label
    yl3 = ylim(ax3);
    text(ax3, 3.4, yl3(2) - 0.06 * diff(yl3), 'Target: 0.4-0.8 s', ...
         'FontSize', 7, 'HorizontalAlignment', 'right', ...
         'BackgroundColor', bandColor, 'EdgeColor', [0.5 0.7 0.5], ...
         'Margin', 2);

    % ================================================================
    %  Super title + save
    % ================================================================
    sgtitle(sprintf('Room Summary:  %s', strrep(roomName, '_', '\_')), ...
            'FontWeight', 'bold', 'FontSize', 13);

    exportgraphics(fig, outFile, 'ContentType', 'vector');
    close(fig);
end
