%% run_single_source.m
%  Simplified pipeline for analysing measurements from a single source
%  in one room.  Edit the two parameters below, then run.

clear; close all; clc;

%% ====================================================================
%  USER PARAMETERS — edit these
%  ====================================================================
roomName = 'EXP_204';       % room folder name under data/raw/
source   = 'src1';          % 'src1' or 'src2'

%% ====================================================================
%  PATHS & SETTINGS
%  ====================================================================
paths.ess       = fullfile('.', 'data', 'ess');
paths.raw       = fullfile('.', 'data', 'raw');
paths.processed = fullfile('.', 'data', 'processed');
paths.figures   = fullfile('.', 'figures');

cfg.irLenSec  = 1.0;
cfg.outChPref = 1;
cfg.t_D50     = 50;
cfg.t_D80     = 80;

%% ====================================================================
%  MEASUREMENT LIST (single source, three positions)
%  ====================================================================
positions = {'front', 'mid', 'back'};
meas = cell(numel(positions), 3);
for pi = 1:numel(positions)
    tag = sprintf('%s_%s', source, positions{pi});
    meas{pi, 1} = tag;            % label
    meas{pi, 2} = tag;            % recording filename (no .wav)
    meas{pi, 3} = 'ess_10s.wav';  % ESS file
end

%% ====================================================================
%  OUTPUT DIRECTORIES
%  ====================================================================
procDir = fullfile(paths.processed, roomName);
figDir  = fullfile(paths.figures, roomName);
if ~exist(procDir, 'dir'), mkdir(procDir); end
if ~exist(figDir,  'dir'), mkdir(figDir);  end

%% ====================================================================
%  ROOM-LEVEL METADATA
%  ====================================================================
roomMetaFile = fullfile(paths.raw, roomName, [roomName, '_meta.json']);
roomMeta = struct();
if isfile(roomMetaFile)
    roomMeta = jsondecode(fileread(roomMetaFile));
    fprintf('Room metadata: %s\n', roomMetaFile);
end

%% ====================================================================
%  PROCESS EACH POSITION
%  ====================================================================
allParams = {};
allIRs    = {};

fprintf('\n===  %s / %s  ===\n', roomName, source);

for mi = 1:size(meas, 1)
    label   = meas{mi, 1};
    recName = meas{mi, 2};
    essName = meas{mi, 3};

    fprintf('\n--------  %s  --------\n', label);

    % -- File paths --
    recFile      = fullfile(paths.raw, roomName, [recName, '.wav']);
    essFile      = fullfile(paths.ess, essName);
    fileMetaFile = fullfile(paths.raw, roomName, [recName, '_meta.json']);
    irFile       = fullfile(procDir, [label, '_ir.wav']);
    paramFile    = fullfile(procDir, [label, '_params.json']);
    figFile      = fullfile(figDir, [label, '.pdf']);

    if ~isfile(recFile)
        warning('Recording not found: %s — skipping.', recFile);
        continue;
    end
    if ~isfile(essFile)
        warning('ESS file not found: %s — skipping.', essFile);
        continue;
    end

    % -- Merge metadata --
    meta = roomMeta;
    if isfile(fileMetaFile)
        fileMeta = jsondecode(fileread(fileMetaFile));
        for fi = fieldnames(fileMeta)'
            meta.(fi{1}) = fileMeta.(fi{1});
        end
    end

    % -- Per-measurement config --
    mcfg = cfg;
    if isfield(meta, 'f1'),     mcfg.f1 = meta.f1;           else, mcfg.f1 = []; end
    if isfield(meta, 'f2'),     mcfg.f2 = meta.f2;           else, mcfg.f2 = []; end
    if isfield(meta, 'out_ch'), mcfg.outChPref = meta.out_ch; end

    % -- Deconvolve --
    [h, params, fs] = deconvolve(essFile, recFile, mcfg);

    % -- Save IR --
    audiowrite(irFile, h, fs, 'BitsPerSample', 24);

    % -- Save parameters --
    params.label    = label;
    params.room     = roomName;
    params.ess_file = essName;
    params.rec_file = [recName, '.wav'];

    analysisFields = {'f1', 'f2', 'out_ch'};
    for fi = fieldnames(meta)'
        if ~ismember(fi{1}, analysisFields)
            params.(fi{1}) = meta.(fi{1});
        end
    end

    fid = fopen(paramFile, 'w');
    fprintf(fid, '%s', jsonencode(params, 'PrettyPrint', true));
    fclose(fid);

    % -- Plot --
    plot_ir(h, params, fs, label, figFile, cfg.irLenSec);

    % -- Accumulate --
    allParams{end+1} = params; %#ok<AGROW>
    allIRs{end+1}    = h;     %#ok<AGROW>

    fprintf('  Saved: %s\n', irFile);
end

%% ====================================================================
%  SUMMARY
%  ====================================================================
if numel(allParams) >= 2
    T20 = cellfun(@(p) p.T20, allParams);
    T30 = cellfun(@(p) p.T30, allParams);
    D50 = cellfun(@(p) p.D50, allParams);
    C80 = cellfun(@(p) p.C80, allParams);

    fprintf('\n===  %s / %s summary (%d positions)  ===\n', ...
        roomName, source, numel(allParams));
    fprintf('  T20:  %.3f +/- %.3f s\n', mean(T20,'omitnan'), std(T20,0,'omitnan'));
    fprintf('  T30:  %.3f +/- %.3f s\n', mean(T30,'omitnan'), std(T30,0,'omitnan'));
    fprintf('  D50:  %.1f +/- %.1f %%\n', mean(D50,'omitnan')*100, std(D50,0,'omitnan')*100);
    fprintf('  C80:  %.1f +/- %.1f dB\n', mean(C80,'omitnan'), std(C80,0,'omitnan'));
end

fprintf('\n===  Done.  ===\n');
