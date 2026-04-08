function plot_comparison(roomStats, anovaResults, rawData, rankOrder, ...
                         weights, T_optimal, alpha, outDir)
% PLOT_COMPARISON  Cross-room comparison figures.
%
%   plot_comparison(roomStats, anovaResults, rawData, rankOrder, ...
%                   weights, T_optimal, alpha, outDir)
%
%   Generates three PDFs in outDir:
%     comparison_parameters.pdf  Dot-and-whisker per parameter (all 7)
%     comparison_heatmap.pdf     Z-score heatmap across rooms
%     comparison_ranking.pdf     Composite score bar chart with breakdown

    nRooms  = numel(roomStats);
    nParams = numel(rawData.labels);

    % Room names in rank order
    sortedNames = {roomStats(rankOrder).name};

    % Display formatting: names, units, and multipliers for human-readable values
    dispNames = {'T_{20}', 'T_{30}', 'D_{50}', 'C_{50}', ...
                 'D_{80}', 'C_{80}', 'T_s'};
    dispUnits = {'s', 's', '%', 'dB', '%', 'dB', 'ms'};
    dispScale = [1, 1, 100, 1, 100, 1, 1000];

    % Plain-text variants (for tick labels that use 'none' interpreter)
    plainNames = {'T20 [s]', 'T30 [s]', 'D50 [%]', 'C50 [dB]', ...
                  'D80 [%]', 'C80 [dB]', 'Ts [ms]'};

    % Colours: one per room (rank-ordered)
    cmap = lines(nRooms);

    % ================================================================
    %  FIGURE 1: Parameter dot-and-whisker (2 x 4 grid, 7 panels)
    % ================================================================
    fig1 = figure('Position', [50 50 1500 900], 'Visible', 'off');

    % Literature-based target ranges (ISO 3382 / Rakerd et al.)
    %   Each row: [lo, hi] in display units, or NaN to skip.
    %   Use Inf/-Inf for one-sided ranges.
    %          T20      T30      D50      C50      D80      C80      Ts
    targLo = [ 0.4,     0.4,     50,      0,       NaN,    -2,       NaN];
    targHi = [ 0.8,     0.8,     Inf,     Inf,     NaN,     5,       100];
    targDesc = {'0.4-0.8 s', '0.4-0.8 s', '> 50%', '> 0 dB', '', ...
                '-2 to 5 dB', ''};
    bandColor = [0.75 0.92 0.75];

    for pi = 1:nParams
        subplot(2, 4, pi);
        hold on;

        % First pass: collect all data to determine y-range
        allVals = [];
        for ki = 1:nRooms
            ri = rankOrder(ki);
            mask = rawData.groupIdx == ri;
            allVals = [allVals, rawData.values{pi}(mask) * dispScale(pi)]; %#ok<AGROW>
        end
        ylo = min(allVals);
        yhi = max(allVals);
        ypad = 0.25 * (yhi - ylo + eps);

        % Target band (clamped to data range)
        if ~isnan(targLo(pi))
            xl = [0.3, nRooms + 0.7];
            lo = targLo(pi);
            hi = targHi(pi);
            if isinf(hi), hi = yhi + ypad; end
            if isinf(lo), lo = ylo - ypad; end
            fill([xl(1) xl(2) xl(2) xl(1)], [lo lo hi hi], ...
                 bandColor, 'EdgeColor', 'none', 'FaceAlpha', 0.45, ...
                 'HandleVisibility', 'off');
        end

        % Second pass: draw data on top of band
        for ki = 1:nRooms
            ri = rankOrder(ki);
            mask = rawData.groupIdx == ri;
            v = rawData.values{pi}(mask) * dispScale(pi);

            mu = mean(v, 'omitnan');
            s  = std(v, 0, 'omitnan');
            n  = sum(~isnan(v));
            t_crit = tinv(1 - alpha/2, max(n-1, 1));
            ci = t_crit * s / sqrt(max(n, 1));

            % Jittered individual measurements
            jitter = (rand(size(v)) - 0.5) * 0.3;
            plot(ki + jitter, v, 'o', 'MarkerSize', 4, ...
                 'MarkerFaceColor', cmap(ki,:), 'MarkerEdgeColor', 'none', ...
                 'HandleVisibility', 'off');

            % Mean diamond + 95% CI whisker
            errorbar(ki, mu, ci, 'k', 'LineWidth', 1.5, 'CapSize', 6, ...
                     'HandleVisibility', 'off');
            plot(ki, mu, 'kd', 'MarkerSize', 6, 'MarkerFaceColor', 'k', ...
                 'HandleVisibility', 'off');
        end

        % Lock y-axis to data range
        ylim([ylo - ypad, yhi + ypad]);

        % Target-range label in upper-right of panel
        if ~isnan(targLo(pi))
            yl = ylim;
            text(nRooms + 0.5, yl(2) - 0.06 * diff(yl), ...
                 ['Target: ' targDesc{pi}], ...
                 'FontSize', 6.5, 'HorizontalAlignment', 'right', ...
                 'VerticalAlignment', 'middle', ...
                 'BackgroundColor', bandColor, 'EdgeColor', [0.5 0.7 0.5], ...
                 'Margin', 2);
        end

        % ANOVA annotation in title
        if anovaResults(pi).p < 0.001
            p_str = 'p < 0.001';
        else
            p_str = sprintf('p = %.3f', anovaResults(pi).p);
        end
        sig_marker = '';
        if anovaResults(pi).significant, sig_marker = ' ***'; end

        title(sprintf('%s [%s]    F = %.1f, %s%s', ...
              dispNames{pi}, dispUnits{pi}, anovaResults(pi).F, ...
              p_str, sig_marker), ...
              'FontSize', 9, 'Interpreter', 'tex');

        set(gca, 'XTick', 1:nRooms, ...
                 'XTickLabel', sortedNames, ...
                 'XTickLabelRotation', 45, ...
                 'FontSize', 7, ...
                 'TickLabelInterpreter', 'none');
        xlim([0.3, nRooms + 0.7]);
        grid on;
    end

    % 8th panel: notes
    subplot(2, 4, 8);
    axis off;
    xlim([0 1]); ylim([0 1]);
    text(0.5, 0.70, 'Rooms sorted by composite rank', ...
         'HorizontalAlignment', 'center', 'FontSize', 10, ...
         'FontWeight', 'bold');
    text(0.5, 0.60, '(best \rightarrow worst, left \rightarrow right)', ...
         'HorizontalAlignment', 'center', 'FontSize', 9, ...
         'Interpreter', 'tex');
    text(0.5, 0.50, sprintf('Error bars: 95%% CI   |   n = %d per room', ...
         roomStats(1).n), ...
         'HorizontalAlignment', 'center', 'FontSize', 9);
    text(0.5, 0.40, '*** = ANOVA significant at \alpha = 0.05', ...
         'HorizontalAlignment', 'center', 'FontSize', 9, ...
         'Interpreter', 'tex');

    sgtitle('ISO 3382 Parameters by Room', 'FontWeight', 'bold', 'FontSize', 13);

    exportgraphics(fig1, fullfile(outDir, 'comparison_parameters.pdf'), ...
                   'ContentType', 'vector');
    close(fig1);
    fprintf('  Saved: comparison_parameters.pdf\n');

    % ================================================================
    %  FIGURE 2: Z-score heatmap
    % ================================================================
    fig2 = figure('Position', [50 50 950 550], 'Visible', 'off');

    % Build z-score matrix (rooms x params) from room means
    Z = zeros(nRooms, nParams);
    for pi = 1:nParams
        roomMeans = arrayfun(@(r) r.([rawData.labels{pi}, '_mean']), roomStats);
        s = std(roomMeans);
        if s < eps
            Z(:, pi) = 0;
        else
            Z(:, pi) = (roomMeans - mean(roomMeans)) / s;
        end
    end

    % Reorder rows: rank 1 at top
    Z_sorted = Z(rankOrder, :);

    imagesc(Z_sorted);
    colormap(blue_white_red(256));
    cLim = max(abs(Z_sorted(:)));
    if cLim < eps, cLim = 1; end
    caxis([-cLim, cLim]);
    cb = colorbar;
    cb.Label.String = 'z-score (relative to room mean)';

    % Annotate each cell with the actual parameter value
    for ki = 1:nRooms
        ri = rankOrder(ki);
        for pi = 1:nParams
            val = roomStats(ri).([rawData.labels{pi}, '_mean']) * dispScale(pi);
            if abs(val) >= 100
                txt = sprintf('%.0f', val);
            elseif abs(val) >= 10
                txt = sprintf('%.1f', val);
            else
                txt = sprintf('%.2f', val);
            end
            % White text on saturated cells, black on pale cells
            if abs(Z_sorted(ki, pi)) > 0.55 * cLim
                tc = 'w';
            else
                tc = 'k';
            end
            text(pi, ki, txt, 'HorizontalAlignment', 'center', ...
                 'FontSize', 8, 'Color', tc, 'FontWeight', 'bold');
        end
    end

    set(gca, 'XTick', 1:nParams, 'XTickLabel', plainNames, ...
             'YTick', 1:nRooms,  'YTickLabel', sortedNames, ...
             'TickLabelInterpreter', 'none', 'FontSize', 8);
    title('Room Acoustic Parameters — Z-Score Heatmap  (ranked top \rightarrow bottom)', ...
          'FontWeight', 'bold', 'Interpreter', 'tex');

    exportgraphics(fig2, fullfile(outDir, 'comparison_heatmap.pdf'), ...
                   'ContentType', 'vector');
    close(fig2);
    fprintf('  Saved: comparison_heatmap.pdf\n');

    % ================================================================
    %  FIGURE 3: Composite ranking bar chart
    % ================================================================
    fig3 = figure('Position', [50 50 900 500], 'Visible', 'off');

    scores = [roomStats(rankOrder).composite];

    bh = barh(1:nRooms, scores);
    bh.FaceColor = 'flat';
    for ki = 1:nRooms
        if scores(ki) >= 0
            bh.CData(ki,:) = [0.30 0.60 0.85];   % blue = positive
        else
            bh.CData(ki,:) = [0.85 0.40 0.30];   % red-orange = negative
        end
    end

    set(gca, 'YTick', 1:nRooms, 'YTickLabel', sortedNames, ...
             'YDir', 'reverse', 'TickLabelInterpreter', 'none', ...
             'FontSize', 9);
    xlabel('Composite Score', 'FontSize', 10);
    title(sprintf(['Speech-Quality Ranking   ' ...
                   '(D_{50} = %.0f%%,  T_{20} penalty = %.0f%%)'], ...
                  weights.D50*100, weights.T20*100), ...
          'FontWeight', 'bold', 'Interpreter', 'tex');
    grid on;
    hold on;

    % 95% CI error bars (error propagation through composite)
    ci_vals = [roomStats(rankOrder).composite_ci];
    errorbar(scores, 1:nRooms, [], [], ci_vals, ci_vals, ...
             'k.', 'LineWidth', 1.2, 'CapSize', 5, ...
             'HandleVisibility', 'off');

    % Zero line
    xline(0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');

    % Annotate bars with component z-scores (shifted above bar centre)
    ci_vals = [roomStats(rankOrder).composite_ci];
    xpad = max(abs(scores)) * 0.05 + 0.02;
    for ki = 1:nRooms
        ri = rankOrder(ki);
        label = sprintf('D50:%+.1f  T20:%+.1f', ...
                roomStats(ri).z_D50, roomStats(ri).z_T20);

        if scores(ki) >= 0
            xpos = scores(ki) + ci_vals(ki) + xpad;
            ha = 'left';
        else
            xpos = scores(ki) - ci_vals(ki) - xpad;
            ha = 'right';
        end
        text(xpos, ki, label, 'FontSize', 7, ...
             'HorizontalAlignment', ha, 'VerticalAlignment', 'middle');
    end

    % Fixed x-axis range with room for annotations
    ax = gca;
    ax.XLim = [-3.5, 3.5];

    % Optimal-target note
    text(ax.XLim(2) - 0.55, nRooms + 0.7, ...
         sprintf('T_{20} optimal = %.1f s', T_optimal), ...
         'FontSize', 8, 'HorizontalAlignment', 'right', ...
         'FontAngle', 'italic', 'Interpreter', 'tex');

    exportgraphics(fig3, fullfile(outDir, 'comparison_ranking.pdf'), ...
                   'ContentType', 'vector');
    close(fig3);
    fprintf('  Saved: comparison_ranking.pdf\n');
end


% ====================================================================
%  LOCAL HELPER: Blue–White–Red diverging colormap
% ====================================================================
function cmap = blue_white_red(n)
    half = floor(n/2);
    % Blue end (ColorBrewer RdBu blue)
    b_r = 0.13;  b_g = 0.40;  b_b = 0.67;
    % Red end  (ColorBrewer RdBu red)
    r_r = 0.70;  r_g = 0.09;  r_b = 0.17;

    % Blue → white
    R1 = linspace(b_r, 1, half);
    G1 = linspace(b_g, 1, half);
    B1 = linspace(b_b, 1, half);
    % White → red
    R2 = linspace(1, r_r, n - half);
    G2 = linspace(1, r_g, n - half);
    B2 = linspace(1, r_b, n - half);

    cmap = [[R1, R2]', [G1, G2]', [B1, B2]'];
end
