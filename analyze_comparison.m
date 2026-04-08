%% analyze_comparison.m
%  Cross-room statistical comparison and speech-quality ranking.
%
%  Reads per-measurement parameter JSONs produced by main.m, performs
%  two-way ANOVA (room x position blocked design) with Tukey HSD post-hoc,
%  computes a composite speech-quality score, and ranks rooms.
%
%  The blocked design removes systematic source-receiver position effects
%  from the error term, increasing statistical power for detecting room
%  differences compared to a one-way ANOVA.
%
%  Outputs:
%    data/processed/comparison.json   Statistical results and ranking
%    figures/comparison/*.pdf         Comparison figures
%
%  Prerequisites:
%    Run main.m first to generate per-measurement parameter JSONs.
%    Statistics and Machine Learning Toolbox (anovan, multcompare, tinv).

clear; close all; clc;

%% ====================================================================
%  1. CONFIGURATION
%  ====================================================================
paths.processed = fullfile('.', 'data', 'processed');
paths.figures   = fullfile('.', 'figures');

roomNames = {'EXP_204', 'ISEC_102', 'SNELL_168', 'ROBINSON_109', ...
             'EV_002', 'MUGAR_201', 'WVG_108', 'WVF_020', 'SHILLMAN_215'};
nRooms = numel(roomNames);

paramLabels = {'T20', 'T30', 'D50', 'C50', 'D80', 'C80', 'Ts'};
nParams     = numel(paramLabels);

% Composite score: D50 (speech intelligibility) + T20 (reverberation penalty)
weights = struct('D50', 0.60, 'T20', 0.40);
T20_optimal = 0.7;   % [s] target for lecture halls

alpha = 0.05;

%% ====================================================================
%  2. LOAD PER-MEASUREMENT DATA
%  ====================================================================
fprintf('Loading per-measurement parameters...\n');

vals = struct();
for pi = 1:nParams
    vals.(paramLabels{pi}) = [];
end
groupIdx  = [];
groupName = {};
posLabel  = {};

for ri = 1:nRooms
    pFiles = dir(fullfile(paths.processed, roomNames{ri}, '*_params.json'));
    for fi = 1:numel(pFiles)
        p = jsondecode(fileread(fullfile(pFiles(fi).folder, pFiles(fi).name)));
        for pi = 1:nParams
            vals.(paramLabels{pi})(end+1) = p.(paramLabels{pi}); %#ok<SAGROW>
        end
        groupIdx(end+1)  = ri;            %#ok<SAGROW>
        groupName{end+1} = roomNames{ri}; %#ok<SAGROW>
        posLabel{end+1}  = p.label;       %#ok<SAGROW>
    end
end

nTotal = numel(groupIdx);
fprintf('  %d measurements across %d rooms.\n\n', nTotal, nRooms);

% Position index (for blocked design)
posNames = unique(posLabel);
nPos     = numel(posNames);

posIdx = zeros(1, nTotal);
for k = 1:nTotal
    posIdx(k) = find(strcmp(posNames, posLabel{k}));
end

%% ====================================================================
%  3. TWO-WAY ANOVA (ROOM x POSITION) + TUKEY HSD
%  ====================================================================
anovaResults = struct();

fprintf('================================================\n');
fprintf('  TWO-WAY ANOVA: Room x Position  (alpha = %.2f)\n', alpha);
fprintf('================================================\n');
fprintf('%-6s  %10s  %12s  %-3s  %10s  %12s  %s\n', ...
        'Param', 'F_room', 'p_room', '', 'F_pos', 'p_pos', '');
fprintf('%s\n', repmat('-', 1, 62));

for pi = 1:nParams
    [pvals, tbl, stats] = anovan(vals.(paramLabels{pi})(:), ...
        {groupName(:), posLabel(:)}, ...
        'model', 'linear', 'varnames', {'Room', 'Position'}, ...
        'display', 'off');

    anovaResults(pi).name        = paramLabels{pi};
    anovaResults(pi).F           = tbl{2, 6};    % Room F
    anovaResults(pi).p           = pvals(1);      % Room p
    anovaResults(pi).significant = pvals(1) < alpha;
    anovaResults(pi).F_pos       = tbl{3, 6};    % Position F
    anovaResults(pi).p_pos       = pvals(2);      % Position p

    % Tukey HSD on room factor
    [c, m, ~, gnames] = multcompare(stats, 'Dimension', 1, ...
        'Display', 'off', 'Alpha', alpha);
    anovaResults(pi).tukey.comparisons = c;
    anovaResults(pi).tukey.means       = m;
    anovaResults(pi).tukey.groups      = gnames;
    anovaResults(pi).tukey.n_sig       = sum(c(:,6) < alpha);

    sig_room = '   ';
    if pvals(1) < alpha, sig_room = '***'; end
    sig_pos = '';
    if pvals(2) < alpha, sig_pos = '***'; end

    fprintf('%-6s  %10.2f  %12.4g  %-3s  %10.2f  %12.4g  %s\n', ...
            paramLabels{pi}, anovaResults(pi).F, pvals(1), sig_room, ...
            anovaResults(pi).F_pos, pvals(2), sig_pos);
end

% Print significant Tukey pairs
fprintf('\n================================================\n');
fprintf('  SIGNIFICANT PAIRWISE DIFFERENCES (Tukey HSD)\n');
fprintf('================================================\n');

for pi = 1:nParams
    if ~anovaResults(pi).significant, continue; end
    c = anovaResults(pi).tukey.comparisons;
    g = anovaResults(pi).tukey.groups;
    sig = c(:,6) < alpha;
    if ~any(sig), continue; end

    fprintf('\n  %s (%d pairs):\n', paramLabels{pi}, sum(sig));
    for ci = find(sig)'
        fprintf('    %-16s vs %-16s  diff=%+.4f  p=%.4f\n', ...
                g{c(ci,1)}, g{c(ci,2)}, c(ci,4), c(ci,6));
    end
end

%% ====================================================================
%  4. ROOM MEANS AND COMPOSITE SCORE
%  ====================================================================
roomStats = struct();

for ri = 1:nRooms
    mask = groupIdx == ri;
    roomStats(ri).name = roomNames{ri};
    roomStats(ri).n    = sum(mask);

    for pi = 1:nParams
        v = vals.(paramLabels{pi})(mask);
        roomStats(ri).([paramLabels{pi}, '_mean']) = mean(v, 'omitnan');
        roomStats(ri).([paramLabels{pi}, '_std'])  = std(v, 0, 'omitnan');
    end
end

% Room-mean vectors for composite parameters
T20m = [roomStats.T20_mean];
D50m = [roomStats.D50_mean];

% Z-scores oriented so higher = better for speech
z_D50 = zscore_safe(D50m);                      % higher D50 is better
z_T20 = zscore_safe(-abs(T20m - T20_optimal));   % closer to optimal is better

composite = weights.D50 * z_D50 + weights.T20 * z_T20;

% Rank: 1 = best
[~, rankOrder] = sort(composite, 'descend');
ranks = zeros(1, nRooms);
ranks(rankOrder) = 1:nRooms;

for ri = 1:nRooms
    roomStats(ri).z_D50     = z_D50(ri);
    roomStats(ri).z_T20     = z_T20(ri);
    roomStats(ri).composite = composite(ri);
    roomStats(ri).rank      = ranks(ri);
end

% --- Composite uncertainty (error propagation from blocked model) ---
% Build data matrices: nRooms x nPos
D50_mat = NaN(nRooms, nPos);
T20_mat = NaN(nRooms, nPos);
for k = 1:nTotal
    D50_mat(groupIdx(k), posIdx(k)) = vals.D50(k);
    T20_mat(groupIdx(k), posIdx(k)) = vals.T20(k);
end

% Additive-model residuals: e_ij = y_ij - mean_i. - mean_.j + mean_..
D50_resid = D50_mat - mean(D50_mat, 2) - mean(D50_mat, 1) + mean(D50_mat(:));
T20_resid = T20_mat - mean(T20_mat, 2) - mean(T20_mat, 1) + mean(T20_mat(:));

df_error = (nRooms - 1) * (nPos - 1);

% Error mean squares and cross-product
MSE_D50   = sum(D50_resid(:).^2) / df_error;
MSE_T20   = sum(T20_resid(:).^2) / df_error;
cross_MSE = sum(D50_resid(:) .* T20_resid(:)) / df_error;

% Covariance matrix of room mean estimates (same for all rooms)
Sigma_mean = [MSE_D50, cross_MSE; cross_MSE, MSE_T20] / nPos;

% Z-score normalization constants
sigma_D50 = std(D50m);
sigma_dev = std(-abs(T20m - T20_optimal));

t_crit = tinv(1 - alpha/2, df_error);

for ri = 1:nRooms
    % Jacobian: dC/d[D50, T20]
    J = zeros(1, 2);
    if sigma_D50 > eps
        J(1) = weights.D50 / sigma_D50;
    end
    if sigma_dev > eps
        J(2) = -weights.T20 * sign(T20m(ri) - T20_optimal) / sigma_dev;
    end

    var_C = J * Sigma_mean * J';
    roomStats(ri).composite_ci = t_crit * sqrt(max(var_C, 0));
end

%% ====================================================================
%  5. PRINT RANKING
%  ====================================================================
fprintf('\n================================================\n');
fprintf('  SPEECH-QUALITY RANKING\n');
fprintf('================================================\n');
fprintf('Weights: D50 = %.0f%%,  T20 dev. from %.1f s = %.0f%%\n', ...
        weights.D50*100, T20_optimal, weights.T20*100);
fprintf('Error model: two-way additive (room + position), df = %d\n\n', df_error);

fprintf('%-5s  %-16s  %6s  %6s  %6s  %6s  %8s  %7s\n', ...
        'Rank', 'Room', 'T20', 'D50', 'z_T20', 'z_D50', 'Score', '95%CI');
fprintf('%s\n', repmat('-', 1, 72));

for k = 1:nRooms
    ri = rankOrder(k);
    fprintf('%-5d  %-16s  %5.3f  %5.3f  %+5.2f  %+5.2f  %+7.3f  +/-%.3f\n', ...
            k, roomNames{ri}, T20m(ri), D50m(ri), ...
            z_T20(ri), z_D50(ri), composite(ri), ...
            roomStats(ri).composite_ci);
end

%% ====================================================================
%  6. SAVE RESULTS
%  ====================================================================
out.description       = 'Cross-room comparison — ISO 3382 parameters (blocked design)';
out.n_rooms           = nRooms;
out.n_measurements    = nTotal;
out.n_positions       = nPos;
out.alpha             = alpha;
out.composite_weights = weights;
out.T20_optimal_s     = T20_optimal;
out.error_df          = df_error;

% ANOVA summary
for pi = 1:nParams
    a = anovaResults(pi);
    s.F_room      = a.F;
    s.p_room      = a.p;
    s.significant = a.significant;
    s.F_position  = a.F_pos;
    s.p_position  = a.p_pos;

    c  = a.tukey.comparisons;
    g  = a.tukey.groups;
    si = find(c(:,6) < alpha);

    pairs = struct('room1', {}, 'room2', {}, 'diff', {}, 'p_adj', {});
    for k = 1:numel(si)
        ci = si(k);
        pairs(end+1) = struct('room1', g{c(ci,1)}, 'room2', g{c(ci,2)}, ...
                              'diff', c(ci,4), 'p_adj', c(ci,6)); %#ok<SAGROW>
    end
    s.significant_pairs = pairs;
    out.anova.(paramLabels{pi}) = s;
end

% Ranking table
for k = 1:nRooms
    ri = rankOrder(k);
    out.ranking(k).rank            = k;
    out.ranking(k).room            = roomNames{ri};
    out.ranking(k).T20_mean        = T20m(ri);
    out.ranking(k).D50_mean        = D50m(ri);
    out.ranking(k).z_T20           = z_T20(ri);
    out.ranking(k).z_D50           = z_D50(ri);
    out.ranking(k).composite_score = composite(ri);
    out.ranking(k).composite_ci    = roomStats(ri).composite_ci;
end

outFile = fullfile(paths.processed, 'comparison.json');
fid = fopen(outFile, 'w');
fprintf(fid, '%s', jsonencode(out, 'PrettyPrint', true));
fclose(fid);
fprintf('\nSaved: %s\n', outFile);

%% ====================================================================
%  7. FIGURES
%  ====================================================================
figDir = fullfile(paths.figures, 'comparison');
if ~exist(figDir, 'dir'), mkdir(figDir); end

rawData.labels   = paramLabels;
rawData.values   = cell(1, nParams);
for pi = 1:nParams
    rawData.values{pi} = vals.(paramLabels{pi});
end
rawData.groupIdx = groupIdx;

plot_comparison(roomStats, anovaResults, rawData, rankOrder, ...
                weights, T20_optimal, alpha, figDir);

fprintf('\n===  Done.  ===\n');


%% ====================================================================
%  LOCAL HELPER
%  ====================================================================
function z = zscore_safe(x)
% ZSCORE_SAFE  Z-score that returns zeros when std is zero.
    s = std(x);
    if s < eps
        z = zeros(size(x));
    else
        z = (x - mean(x)) / s;
    end
end
