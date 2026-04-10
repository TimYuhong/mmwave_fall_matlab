function [compensated_response, tx_phase_weights] = phase_compensation(channel_response, doppler_value, radar_cfg, doppler_unit)
%PHASE_COMPENSATION Apply TDM-MIMO inter-TX motion phase compensation.
%   [compensated_response, tx_phase_weights] = ...
%       phase_compensation(channel_response, doppler_value, radar_cfg, doppler_unit)
%
%   Input:
%     channel_response : complex double
%       Size [num_rx, num_tx]
%     doppler_value    : scalar
%       Doppler bin index or Doppler velocity.
%     radar_cfg        : struct
%       Must contain:
%         radar_cfg.frame.num_tx
%         radar_cfg.rf.lambda_m
%         and one of:
%           radar_cfg.aoa.tx_time_offsets_s
%           radar_cfg.rf.chirp_period_us
%     doppler_unit     : char/string, optional
%       'bin' (default) or 'mps'
%
%   Output:
%     compensated_response : complex double
%       Same size as channel_response
%     tx_phase_weights     : complex double
%       Size [1, num_tx]
%
%   Notes:
%     1. Current implementation assumes each TX slot is separated by one
%        chirp period when explicit tx_time_offsets_s is not provided.
%     2. TODO: if the project later uses BPM or custom TX timing, populate
%        radar_cfg.aoa.tx_time_offsets_s with measured per-TX time offsets.

    narginchk(3, 4);

    if nargin < 4 || isempty(doppler_unit)
        doppler_unit = 'bin';
    end
    doppler_unit = char(doppler_unit);

    if ~ismatrix(channel_response) || isempty(channel_response)
        error('phase_compensation:InvalidResponse', ...
            'channel_response must be a non-empty 2-D matrix.');
    end

    if ~isscalar(doppler_value) || ~isnumeric(doppler_value)
        error('phase_compensation:InvalidDopplerValue', ...
            'doppler_value must be a numeric scalar.');
    end

    if ~isstruct(radar_cfg)
        error('phase_compensation:InvalidRadarCfg', ...
            'radar_cfg must be a struct.');
    end

    if ~isfield(radar_cfg, 'frame') || ~isfield(radar_cfg.frame, 'num_tx')
        error('phase_compensation:MissingRadarCfgField', ...
            'radar_cfg.frame.num_tx is required.');
    end

    if ~isfield(radar_cfg, 'rf') || ~isfield(radar_cfg.rf, 'lambda_m')
        error('phase_compensation:MissingRadarCfgField', ...
            'radar_cfg.rf.lambda_m is required.');
    end

    num_tx = size(channel_response, 2);
    if radar_cfg.frame.num_tx ~= num_tx
        error('phase_compensation:NumTxMismatch', ...
            'channel_response has %d TX channels, but radar_cfg.frame.num_tx is %d.', ...
            num_tx, radar_cfg.frame.num_tx);
    end

    switch lower(strtrim(doppler_unit))
        case 'bin'
            doppler_mps = doppler_bin_to_mps(doppler_value, radar_cfg);
        case 'mps'
            doppler_mps = double(doppler_value);
        otherwise
            error('phase_compensation:UnsupportedDopplerUnit', ...
                'Unsupported doppler_unit: %s', doppler_unit);
    end

    tx_time_offsets_s = local_get_tx_time_offsets_s(radar_cfg, num_tx);
    phase_rad = 4 * pi * doppler_mps * tx_time_offsets_s ./ radar_cfg.rf.lambda_m;
    tx_phase_weights = exp(-1j * phase_rad);

    compensated_response = channel_response .* repmat(tx_phase_weights, size(channel_response, 1), 1);
end

function tx_time_offsets_s = local_get_tx_time_offsets_s(radar_cfg, num_tx)
    tx_time_offsets_s = [];

    if isfield(radar_cfg, 'aoa') && isfield(radar_cfg.aoa, 'tx_time_offsets_s') && ...
            ~isempty(radar_cfg.aoa.tx_time_offsets_s)
        tx_time_offsets_s = double(radar_cfg.aoa.tx_time_offsets_s(:)).';
    elseif isfield(radar_cfg, 'rf') && isfield(radar_cfg.rf, 'chirp_period_us')
        tx_time_offsets_s = (0:num_tx-1) * double(radar_cfg.rf.chirp_period_us) * 1e-6;
    end

    if isempty(tx_time_offsets_s)
        error('phase_compensation:MissingTxTiming', ...
            ['Missing TX timing information. Provide radar_cfg.aoa.tx_time_offsets_s ', ...
             'or radar_cfg.rf.chirp_period_us.']);
    end

    if numel(tx_time_offsets_s) ~= num_tx
        error('phase_compensation:InvalidTxTimingLength', ...
            'Expected %d TX time offsets, but got %d.', num_tx, numel(tx_time_offsets_s));
    end
end
