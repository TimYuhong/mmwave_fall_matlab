function [az_deg, el_deg, spectrum_2d, peak_value] = angle_estimation_2d_dbf(channel_response, array_geometry, radar_cfg, scan_cfg)
%ANGLE_ESTIMATION_2D_DBF Estimate azimuth/elevation using 2-D DBF.
%   [az_deg, el_deg, spectrum_2d, peak_value] = ...
%       angle_estimation_2d_dbf(channel_response, array_geometry, radar_cfg, scan_cfg)
%
%   Input:
%     channel_response : complex double
%       Size [num_rx, num_tx]
%     array_geometry   : struct
%       Required field:
%         element_positions_m : [num_virtual_channels, 3]
%       Row order must match channel_response(:), i.e.
%         [RX1..RXN @ TX-slot1; RX1..RXN @ TX-slot2; ...]
%       If only [N, 2] is provided, z is assumed to be 0.
%     radar_cfg        : struct
%       Must contain radar_cfg.rf.lambda_m
%     scan_cfg         : struct
%       Required fields:
%         azimuth_grid_deg
%         elevation_grid_deg
%
%   Output:
%     az_deg      : scalar
%     el_deg      : scalar
%     spectrum_2d : double
%       Size [num_elevation, num_azimuth]
%     peak_value  : scalar
%
%   Notes:
%     Coordinate convention is radar-local:
%       x: azimuth horizontal axis
%       y: boresight / range axis
%       z: elevation axis

    narginchk(4, 4);

    if ~ismatrix(channel_response) || isempty(channel_response)
        error('angle_estimation_2d_dbf:InvalidResponse', ...
            'channel_response must be a non-empty 2-D matrix.');
    end

    if ~isstruct(array_geometry)
        error('angle_estimation_2d_dbf:InvalidGeometry', ...
            'array_geometry must be a struct.');
    end

    if ~isstruct(scan_cfg)
        error('angle_estimation_2d_dbf:InvalidScanCfg', ...
            'scan_cfg must be a struct.');
    end

    if ~isfield(radar_cfg, 'rf') || ~isfield(radar_cfg.rf, 'lambda_m')
        error('angle_estimation_2d_dbf:MissingRadarCfgField', ...
            'radar_cfg.rf.lambda_m is required.');
    end

    positions_m = local_get_element_positions_m(array_geometry);
    num_virtual_channels = numel(channel_response);
    if size(positions_m, 1) ~= num_virtual_channels
        error('angle_estimation_2d_dbf:GeometrySizeMismatch', ...
            ['array_geometry.element_positions_m must have one row per virtual ', ...
             'channel in channel_response(:).']);
    end

    if ~isfield(scan_cfg, 'azimuth_grid_deg') || ~isfield(scan_cfg, 'elevation_grid_deg')
        error('angle_estimation_2d_dbf:MissingScanGrid', ...
            'scan_cfg.azimuth_grid_deg and scan_cfg.elevation_grid_deg are required.');
    end

    azimuth_grid_deg = double(scan_cfg.azimuth_grid_deg(:)).';
    elevation_grid_deg = double(scan_cfg.elevation_grid_deg(:)).';
    if isempty(azimuth_grid_deg) || isempty(elevation_grid_deg)
        error('angle_estimation_2d_dbf:EmptyScanGrid', ...
            'scan_cfg.azimuth_grid_deg and scan_cfg.elevation_grid_deg must be non-empty.');
    end

    steering_matrix = local_get_steering_matrix( ...
        positions_m, radar_cfg.rf.lambda_m, azimuth_grid_deg, elevation_grid_deg);

    channel_vector = channel_response(:);
    beam_output = steering_matrix' * channel_vector;
    spectrum_2d = reshape(abs(beam_output).^2 / (num_virtual_channels ^ 2), ...
        [numel(elevation_grid_deg), numel(azimuth_grid_deg)]);

    [peak_value, linear_index] = max(spectrum_2d(:));
    [peak_el_idx, peak_az_idx] = ind2sub(size(spectrum_2d), linear_index);

    az_deg = azimuth_grid_deg(peak_az_idx);
    el_deg = elevation_grid_deg(peak_el_idx);
end

function positions_m = local_get_element_positions_m(array_geometry)
    if isfield(array_geometry, 'element_positions_m')
        positions_m = double(array_geometry.element_positions_m);
    elseif isfield(array_geometry, 'virtual_element_positions_m')
        positions_m = double(array_geometry.virtual_element_positions_m);
    else
        error('angle_estimation_2d_dbf:MissingGeometryField', ...
            ['array_geometry must contain element_positions_m or ', ...
             'virtual_element_positions_m.']);
    end

    if size(positions_m, 2) == 2
        positions_m(:, 3) = 0;
    end

    if size(positions_m, 2) ~= 3
        error('angle_estimation_2d_dbf:InvalidGeometrySize', ...
            'element_positions_m must have size [N, 2] or [N, 3].');
    end
end

function steering_matrix = local_get_steering_matrix(positions_m, lambda_m, azimuth_grid_deg, elevation_grid_deg)
    persistent cached_positions cached_lambda cached_azimuth cached_elevation cached_steering

    if isempty(cached_steering) || ...
            ~isequal(cached_positions, positions_m) || ...
            ~isequal(cached_lambda, lambda_m) || ...
            ~isequal(cached_azimuth, azimuth_grid_deg) || ...
            ~isequal(cached_elevation, elevation_grid_deg)

        [azimuth_mesh_deg, elevation_mesh_deg] = meshgrid(azimuth_grid_deg, elevation_grid_deg);
        azimuth_rad = deg2rad(azimuth_mesh_deg(:));
        elevation_rad = deg2rad(elevation_mesh_deg(:));

        directions = [ ...
            sin(azimuth_rad) .* cos(elevation_rad), ...
            cos(azimuth_rad) .* cos(elevation_rad), ...
            sin(elevation_rad)];

        wave_number = 2 * pi / lambda_m;
        cached_steering = exp(-1j * wave_number * (positions_m * directions.'));
        cached_positions = positions_m;
        cached_lambda = lambda_m;
        cached_azimuth = azimuth_grid_deg;
        cached_elevation = elevation_grid_deg;
    end

    steering_matrix = cached_steering;
end
