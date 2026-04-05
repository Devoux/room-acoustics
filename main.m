%% main.m
%  Orchestrator for room acoustic measurements.
%
%  This script defines the rooms and measurement positions, then calls
%  deconvolve() and plot_ir() for each measurement.  All path definitions
%  live here — the worker scripts receive paths as arguments.
%
%  Directory layout:
%    .\data\ess\              ESS excitation files
%    .\data\raw\ROOM\         Raw recordings + per-file metadata
%    .\data\processed\ROOM\   Recovered IRs + computed parameters
%    .\figures\ROOM\          PDF figures for LaTeX
 
clear; close all; clc;
 
%% ====================================================================
%  1. PROJECT PATHS
%  ====================================================================
paths.ess       = fullfile('.', 'data', 'ess');
paths.raw       = fullfile('.', 'data', 'raw');
paths.processed = fullfile('.', 'data', 'processed');
paths.figures   = fullfile('.', 'figures');
 
%% ====================================================================
%  2. GLOBAL ANALYSIS SETTINGS
%  ====================================================================
cfg.irLenSec  = 1.0;      % max IR length to keep [s]
cfg.outChPref = 1;         % preferred output channel (1 for mono recordings)
cfg.t_D50     = 50;        % early/late boundary for D50 [ms]
cfg.t_D80     = 80;        % early/late boundary for D80 [ms]
 
%% ====================================================================
%  3. ROOM AND MEASUREMENT DEFINITIONS
%  ====================================================================
%  Each room has a name and a list of measurements.  Each measurement
%  specifies the recording filename (without extension — .wav assumed),
%  the ESS file used, and optionally f1/f2 if known.
%
%  Per-file metadata (HVAC state, notes, channel overrides, etc.) is
%  read from the companion _meta.json file if it exists.

rooms = struct();

roomNames = {'EXP_204', 'ISEC_102', 'SNELL_168', 'ROBINSON_109', ...
             'EV_002', 'MUGAR_201', 'WVG_108', 'WVF_020', 'SHILLMAN_215'};

defaultMeas = {
    'src1_front',  'src1_front',  'ess_10s.wav'
    'src1_mid',    'src1_mid',    'ess_10s.wav'
    'src1_back',   'src1_back',   'ess_10s.wav'
    'src2_front',  'src2_front',  'ess_10s.wav'
    'src2_mid',    'src2_mid',    'ess_10s.wav'
    'src2_back',   'src2_back',   'ess_10s.wav'
};

for ri = 1:numel(roomNames)
    rooms(ri).name = roomNames{ri};
    rooms(ri).measurements = defaultMeas;
end

%% ====================================================================
%  4. PROCESS ALL ROOMS
%  ====================================================================
for ri = 1:numel(rooms)
    room = rooms(ri);
    fprintf('\n###############################################\n');
    fprintf('  ROOM: %s\n', room.name);
    fprintf('###############################################\n');
 
    % Create output directories
    procDir = fullfile(paths.processed, room.name);
    figDir  = fullfile(paths.figures, room.name);
    if ~exist(procDir, 'dir'), mkdir(procDir); end
    if ~exist(figDir,  'dir'), mkdir(figDir);  end
 
    % Load room-level metadata (applies to all measurements in this room)
    roomMetaFile = fullfile(paths.raw, room.name, [room.name, '_meta.json']);
    roomMeta = struct();
    if isfile(roomMetaFile)
        roomMeta = jsondecode(fileread(roomMetaFile));
        fprintf('  Room metadata: %s\n', roomMetaFile);
    end
 
    % Accumulate parameters and IRs for room summary
    allParams = {};
    allIRs    = {};
 
    meas = room.measurements;
    for mi = 1:size(meas, 1)
        label   = meas{mi, 1};
        recName = meas{mi, 2};
        essName = meas{mi, 3};
 
        fprintf('\n========  %s / %s  ========\n', room.name, label);
 
        % -- File paths --
        recFile      = fullfile(paths.raw, room.name, [recName, '.wav']);
        essFile      = fullfile(paths.ess, essName);
        fileMetaFile = fullfile(paths.raw, room.name, [recName, '_meta.json']);
        irFile       = fullfile(procDir, [label, '_ir.wav']);
        paramFile    = fullfile(procDir, [label, '_params.json']);
        figFile      = fullfile(figDir, [label, '.pdf']);
 
        % -- Check files exist --
        if ~isfile(recFile)
            warning('Recording not found: %s — skipping.', recFile);
            continue;
        end
        if ~isfile(essFile)
            warning('ESS file not found: %s — skipping.', essFile);
            continue;
        end
 
        % -- Merge metadata: room defaults ← per-file overrides --
        meta = roomMeta;
        if isfile(fileMetaFile)
            fileMeta = jsondecode(fileread(fileMetaFile));
            % Per-file fields override room-level fields
            fileFields = fieldnames(fileMeta);
            for fi = 1:numel(fileFields)
                meta.(fileFields{fi}) = fileMeta.(fileFields{fi});
            end
            fprintf('  Metadata: room + file override (%s)\n', fileMetaFile);
        elseif ~isempty(fieldnames(roomMeta))
            fprintf('  Metadata: room defaults\n');
        end
 
        % -- Build per-measurement config --
        mcfg = cfg;
        if isfield(meta, 'f1'),     mcfg.f1 = meta.f1;            else, mcfg.f1 = []; end
        if isfield(meta, 'f2'),     mcfg.f2 = meta.f2;            else, mcfg.f2 = []; end
        if isfield(meta, 'out_ch'), mcfg.outChPref = meta.out_ch;  end
 
        % -- Deconvolve --
        [h, params, fs] = deconvolve(essFile, recFile, mcfg);
 
        % -- Save IR as wav --
        audiowrite(irFile, h, fs, 'BitsPerSample', 24);
 
        % -- Save parameters as JSON --
        params.label = label;
        params.room  = room.name;
        params.ess_file = essName;
        params.rec_file = [recName, '.wav'];
 
        % Pass through all non-analysis metadata fields
        analysisFields = {'f1', 'f2', 'out_ch'};
        metaFields = fieldnames(meta);
        for fi = 1:numel(metaFields)
            if ~ismember(metaFields{fi}, analysisFields)
                params.(metaFields{fi}) = meta.(metaFields{fi});
            end
        end
 
        fid = fopen(paramFile, 'w');
        fprintf(fid, '%s', jsonencode(params, 'PrettyPrint', true));
        fclose(fid);
 
        % -- Plot and save figure --
        plot_ir(h, params, fs, label, figFile, mcfg.irLenSec);
 
        % -- Accumulate for summary --
        allParams{end+1} = params; %#ok<AGROW>
        allIRs{end+1}    = h;     %#ok<AGROW>
 
        fprintf('  Saved: %s\n', irFile);
        fprintf('         %s\n', paramFile);
        fprintf('         %s\n', figFile);
    end
 
    % -- Room summary --
    if ~isempty(allParams)
        summary = compute_room_summary(allParams, room.name);
        summaryFile = fullfile(procDir, 'summary.json');
        fid = fopen(summaryFile, 'w');
        fprintf(fid, '%s', jsonencode(summary, 'PrettyPrint', true));
        fclose(fid);
 
        % Summary figure
        summaryFig = fullfile(figDir, 'summary.pdf');
        plot_summary(allParams, allIRs, fs, room.name, summaryFig, cfg.irLenSec);
 
        fprintf('\n  Room summary saved: %s\n', summaryFile);
        fprintf('  Summary figure:     %s\n', summaryFig);
        fprintf('    T20:  %.3f ± %.3f s\n', summary.T20_mean, summary.T20_std);
        fprintf('    T30:  %.3f ± %.3f s\n', summary.T30_mean, summary.T30_std);
        fprintf('    D50:  %.1f ± %.1f %%\n', summary.D50_mean*100, summary.D50_std*100);
        fprintf('    C80:  %.1f ± %.1f dB\n', summary.C80_mean, summary.C80_std);
    end
end
 
fprintf('\n===  Done.  ===\n');
 
 
%% ====================================================================
%  LOCAL HELPER
%  ====================================================================
function summary = compute_room_summary(allParams, roomName)
% COMPUTE_ROOM_SUMMARY  Spatially-averaged room acoustic parameters.
%   allParams is a cell array of param structs (one per measurement).
 
    summary.room = roomName;
    summary.n_measurements = numel(allParams);
 
    T20 = cellfun(@(p) p.T20, allParams);
    T30 = cellfun(@(p) p.T30, allParams);
    D50 = cellfun(@(p) p.D50, allParams);
    D80 = cellfun(@(p) p.D80, allParams);
    C50 = cellfun(@(p) p.C50, allParams);
    C80 = cellfun(@(p) p.C80, allParams);
    Ts  = cellfun(@(p) p.Ts,  allParams);
 
    % Exclude NaN values from averaging
    summary.T20_mean = mean(T20, 'omitnan');
    summary.T20_std  = std(T20, 0, 'omitnan');
    summary.T30_mean = mean(T30, 'omitnan');
    summary.T30_std  = std(T30, 0, 'omitnan');
    summary.D50_mean = mean(D50, 'omitnan');
    summary.D50_std  = std(D50, 0, 'omitnan');
    summary.D80_mean = mean(D80, 'omitnan');
    summary.D80_std  = std(D80, 0, 'omitnan');
    summary.C50_mean = mean(C50, 'omitnan');
    summary.C50_std  = std(C50, 0, 'omitnan');
    summary.C80_mean = mean(C80, 'omitnan');
    summary.C80_std  = std(C80, 0, 'omitnan');
    summary.Ts_mean  = mean(Ts,  'omitnan');
    summary.Ts_std   = std(Ts,  0, 'omitnan');
end