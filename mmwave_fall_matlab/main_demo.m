function results = main_demo(input_path)
%MAIN_DEMO Process DCA1000 data up to preliminary point cloud generation.
%   results = main_demo(input_path)
%
%   Input:
%     input_path
%       1. path to a single DCA1000 raw ADC .bin file
%       2. path to a directory that contains multiple .bin files
%
%   Output:
%     results.mode
%     results.input_path
%     results.radar_cfg
%     results.cfar_cfg
%     results.pipeline
%     results.file_results(k).adc_stream
%     results.file_results(k).frames(frame_idx).adc_frame_cube
%     results.file_results(k).frames(frame_idx).mimo_cube
%     results.file_results(k).frames(frame_idx).range_cube
%     results.file_results(k).frames(frame_idx).clutter_free_cube
%     results.file_results(k).frames(frame_idx).rd_cube
%     results.file_results(k).frames(frame_idx).rd_linear_cube
%     results.file_results(k).frames(frame_idx).rd_power_map
%     results.file_results(k).frames(frame_idx).rd_amplitude_map
%     results.file_results(k).frames(frame_idx).cfar_threshold_map
%     results.file_results(k).frames(frame_idx).cfar_mask_map
%     results.file_results(k).frames(frame_idx).cfar_detection_map
%     results.file_results(k).frames(frame_idx).cfar_peaks
%     results.file_results(k).frames(frame_idx).preliminary_point_cloud
%     results.file_results(k).frames(frame_idx).preliminary_point_cloud_xyz

    project_root = fileparts(mfilename('fullpath'));
    addpath(genpath(project_root));

    radar_cfg = radar_config(fullfile(project_root, 'config', 'Radar.cfg'));
    cfar_cfg = cfar_config();

    if nargin < 1 || isempty(input_path)
        input_path = 'F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin';
    end

    input_path = char(input_path);
    input_path = strrep(input_path, '/', filesep);
    if exist(input_path, 'dir') ~= 7 && exist(input_path, 'file') ~= 2
        candidate_path = fullfile(project_root, input_path);
        if exist(candidate_path, 'dir') == 7 || exist(candidate_path, 'file') == 2
            input_path = candidate_path;
        end
    end

    if exist(input_path, 'dir') == 7
        bin_listing = dir(fullfile(input_path, '*.bin'));
        if isempty(bin_listing)
            error('main_demo:NoBinInDirectory', ...
                'No .bin file was found in directory: %s', input_path);
        end
        [~, order] = sort({bin_listing.name});
        bin_listing = bin_listing(order);
        bin_files = fullfile({bin_listing.folder}, {bin_listing.name});
        result_mode = 'directory';
    elseif exist(input_path, 'file') == 2
        bin_files = {input_path};
        result_mode = 'single_file';
    else
        error('main_demo:InvalidInputPath', ...
            ['Input path does not exist: ', input_path, newline, ...
             'Please pass a .bin file path or a directory that contains .bin files.']);
    end

    results = struct();
    results.mode = result_mode;
    results.input_path = input_path;
    results.radar_cfg = radar_cfg;
    results.cfar_cfg = cfar_cfg;
    results.pipeline = { ...
        'read_dca1000_adc', ...
        'reshape_frame_cube', ...
        'deinterleave_tdm_mimo', ...
        'range_fft', ...
        'static_clutter_remove', ...
        'doppler_fft', ...
        'noncoherent_integration_rd', ...
        'os_cfar_2d_on_fused_map', ...
        'preliminary_point_cloud'};
    results.file_results = repmat(struct( ...
        'file_path', '', ...
        'file_name', '', ...
        'num_frames', 0, ...
        'num_adc_complex_samples', 0, ...
        'adc_stream', complex(zeros(0, 1)), ...
        'range_axis_m', zeros(0, 1), ...
        'doppler_axis_mps', zeros(0, 1), ...
        'frames', struct([])), numel(bin_files), 1);

    range_axis_m = range_bin_to_meters((1:radar_cfg.fft.range_fft_size).', radar_cfg);
    doppler_axis_mps = doppler_bin_to_mps((1:radar_cfg.fft.doppler_fft_size).', radar_cfg);

    for file_idx = 1:numel(bin_files)
        current_bin = bin_files{file_idx};
        [adc_stream, num_frames] = read_dca1000_adc(current_bin, radar_cfg);
        frame_cubes = reshape_frame_cube(adc_stream, radar_cfg);

        frame_results = repmat(local_empty_frame_result(), num_frames, 1);

        for frame_idx = 1:num_frames
            adc_frame_cube = frame_cubes(:, :, :, frame_idx);
            frame_result = local_process_frame_until_point_cloud( ...
                adc_frame_cube, radar_cfg, cfar_cfg, range_axis_m, doppler_axis_mps);
            frame_result.frame_id = frame_idx;
            frame_results(frame_idx) = frame_result;
        end

        [~, file_name, file_ext] = fileparts(current_bin);
        results.file_results(file_idx).file_path = current_bin;
        results.file_results(file_idx).file_name = [file_name, file_ext];
        results.file_results(file_idx).num_frames = num_frames;
        results.file_results(file_idx).num_adc_complex_samples = numel(adc_stream);
        results.file_results(file_idx).adc_stream = adc_stream;
        results.file_results(file_idx).range_axis_m = range_axis_m;
        results.file_results(file_idx).doppler_axis_mps = doppler_axis_mps;
        results.file_results(file_idx).frames = frame_results;
    end

    if nargout == 0
        local_print_main_demo_summary(results);
    end
end

function frame_result = local_process_frame_until_point_cloud(adc_frame_cube, radar_cfg, cfar_cfg, range_axis_m, doppler_axis_mps)
    mimo_cube = deinterleave_tdm_mimo(adc_frame_cube, radar_cfg);

    [range_cube, ~] = range_fft(mimo_cube, struct( ...
        'fft_size', radar_cfg.fft.range_fft_size, ...
        'window_type', radar_cfg.fft.range_window));

    clutter_free_cube = static_clutter_remove(range_cube, struct('method', 'mean'));

    [rd_cube, ~] = doppler_fft(clutter_free_cube, struct( ...
        'fft_size', radar_cfg.fft.doppler_fft_size, ...
        'window_type', radar_cfg.fft.doppler_window, ...
        'apply_shift', true));

    rd_linear_cube = abs(rd_cube);

    % First fuse the multi-channel RD cube by noncoherent integration (NCI).
    % This sums channel power across RX/TX without coherent phase addition,
    % then 2D CFAR runs on the fused RD amplitude map.
    [rd_power_map, rd_amplitude_map] = noncoherent_integration_rd(rd_cube);

    [cfar_threshold_map, cfar_mask_map, cfar_detection_map] = ...
        os_cfar_2d(rd_amplitude_map, cfar_cfg);

    cfar_peaks = local_build_cfar_peaks( ...
        rd_amplitude_map, cfar_threshold_map, cfar_mask_map, ...
        range_axis_m, doppler_axis_mps);
    [preliminary_point_cloud, preliminary_point_cloud_xyz] = ...
        local_build_preliminary_point_cloud(rd_cube, cfar_peaks, radar_cfg);

    frame_result = struct( ...
        'frame_id', 0, ...
        'adc_frame_cube', adc_frame_cube, ...
        'mimo_cube', mimo_cube, ...
        'range_cube', range_cube, ...
        'clutter_free_cube', clutter_free_cube, ...
        'rd_cube', rd_cube, ...
        'rd_linear_cube', rd_linear_cube, ...
        'rd_power_map', rd_power_map, ...
        'rd_amplitude_map', rd_amplitude_map, ...
        'cfar_threshold_map', cfar_threshold_map, ...
        'cfar_mask_map', cfar_mask_map, ...
        'cfar_detection_map', cfar_detection_map, ...
        'cfar_peaks', cfar_peaks, ...
        'preliminary_point_cloud', preliminary_point_cloud, ...
        'preliminary_point_cloud_xyz', preliminary_point_cloud_xyz);
end

function frame_result = local_empty_frame_result()
    frame_result = struct( ...
        'frame_id', 0, ...
        'adc_frame_cube', [], ...
        'mimo_cube', [], ...
        'range_cube', [], ...
        'clutter_free_cube', [], ...
        'rd_cube', [], ...
        'rd_linear_cube', [], ...
        'rd_power_map', zeros(0, 0), ...
        'rd_amplitude_map', zeros(0, 0), ...
        'cfar_threshold_map', zeros(0, 0), ...
        'cfar_mask_map', false(0, 0), ...
        'cfar_detection_map', zeros(0, 0), ...
        'cfar_peaks', local_empty_cfar_peaks(), ...
        'preliminary_point_cloud', zeros(0, 5), ...
        'preliminary_point_cloud_xyz', zeros(0, 5));
end

function cfar_peaks = local_build_cfar_peaks(rd_linear_map, cfar_threshold_map, cfar_mask_map, range_axis_m, doppler_axis_mps)
    if isempty(cfar_mask_map) || ~any(cfar_mask_map(:))
        cfar_peaks = local_empty_cfar_peaks();
        return;
    end

    [range_bin, doppler_bin] = find(cfar_mask_map);
    linear_index = sub2ind(size(cfar_mask_map), range_bin, doppler_bin);

    amplitude = double(rd_linear_map(linear_index));
    threshold = double(cfar_threshold_map(linear_index));
    range_m = double(range_axis_m(range_bin));
    doppler_mps = double(doppler_axis_mps(doppler_bin));

    cfar_peaks = table( ...
        double(range_bin(:)), ...
        double(doppler_bin(:)), ...
        amplitude(:), ...
        threshold(:), ...
        range_m(:), ...
        doppler_mps(:), ...
        'VariableNames', { ...
            'range_bin', ...
            'doppler_bin', ...
            'amplitude', ...
            'threshold', ...
            'range_m', ...
            'doppler_mps'});
end

function [preliminary_point_cloud, preliminary_point_cloud_xyz] = local_build_preliminary_point_cloud(rd_cube, cfar_peaks, radar_cfg)
    if isempty(cfar_peaks)
        preliminary_point_cloud = zeros(0, 5);
        preliminary_point_cloud_xyz = zeros(0, 5);
        return;
    end

    num_targets = height(cfar_peaks);
    preliminary_point_cloud = zeros(num_targets, 5);
    preliminary_point_cloud_xyz = NaN(num_targets, 5);

    array_geometry = local_get_array_geometry(radar_cfg);
    scan_cfg = local_get_aoa_scan_cfg(radar_cfg);
    can_estimate_angle = ~isempty(array_geometry) && ~isempty(scan_cfg);

    for target_idx = 1:num_targets
        range_bin = cfar_peaks.range_bin(target_idx);
        doppler_bin = cfar_peaks.doppler_bin(target_idx);

        channel_response = extract_multichannel_rd_response(rd_cube, range_bin, doppler_bin);
        channel_response = phase_compensation(channel_response, doppler_bin, radar_cfg, 'bin');

        az_deg = NaN;
        el_deg = NaN;
        if can_estimate_angle
            [az_deg, el_deg] = angle_estimation_2d_dbf( ...
                channel_response, array_geometry, radar_cfg, scan_cfg);
        end

        preliminary_point_cloud(target_idx, :) = [ ...
            cfar_peaks.range_m(target_idx), ...
            cfar_peaks.doppler_mps(target_idx), ...
            az_deg, ...
            el_deg, ...
            cfar_peaks.amplitude(target_idx)];

        preliminary_point_cloud_xyz(target_idx, 4:5) = [ ...
            cfar_peaks.doppler_mps(target_idx), ...
            cfar_peaks.amplitude(target_idx)];

        if isfinite(az_deg) && isfinite(el_deg)
            point_radar_xyz = radar_spherical_to_cartesian( ...
                cfar_peaks.range_m(target_idx), az_deg, el_deg);
            point_world_xyz = transform_radar_to_world(point_radar_xyz, radar_cfg.mount);
            preliminary_point_cloud_xyz(target_idx, 1:3) = point_world_xyz(1, :);
        end
    end

    % NOTE:
    % preliminary_point_cloud_xyz uses a local ground-aligned frame whose
    % origin is the radar floor projection. Room/global registration still
    % needs extra extrinsics if a larger scene frame is required.
end

function array_geometry = local_get_array_geometry(radar_cfg)
    array_geometry = [];

    if isfield(radar_cfg, 'aoa')
        if isfield(radar_cfg.aoa, 'array_geometry') && ~isempty(radar_cfg.aoa.array_geometry)
            array_geometry = radar_cfg.aoa.array_geometry;
        elseif isfield(radar_cfg.aoa, 'virtual_array_geometry') && ~isempty(radar_cfg.aoa.virtual_array_geometry)
            array_geometry = radar_cfg.aoa.virtual_array_geometry;
        end
    elseif isfield(radar_cfg, 'array_geometry') && ~isempty(radar_cfg.array_geometry)
        array_geometry = radar_cfg.array_geometry;
    end
end

function scan_cfg = local_get_aoa_scan_cfg(radar_cfg)
    scan_cfg = [];

    if isfield(radar_cfg, 'aoa')
        if isfield(radar_cfg.aoa, 'scan_cfg') && ~isempty(radar_cfg.aoa.scan_cfg)
            scan_cfg = radar_cfg.aoa.scan_cfg;
        elseif isfield(radar_cfg.aoa, 'azimuth_grid_deg') && isfield(radar_cfg.aoa, 'elevation_grid_deg')
            scan_cfg = struct( ...
                'azimuth_grid_deg', radar_cfg.aoa.azimuth_grid_deg, ...
                'elevation_grid_deg', radar_cfg.aoa.elevation_grid_deg);
        end
    elseif isfield(radar_cfg, 'scan_cfg') && ~isempty(radar_cfg.scan_cfg)
        scan_cfg = radar_cfg.scan_cfg;
    end
end

function cfar_peaks = local_empty_cfar_peaks()
    cfar_peaks = table( ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        'VariableNames', { ...
            'range_bin', ...
            'doppler_bin', ...
            'amplitude', ...
            'threshold', ...
            'range_m', ...
            'doppler_mps'});
end

function local_print_main_demo_summary(results)
    fprintf('\nmain_demo completed\n');
    fprintf('mode: %s\n', results.mode);
    fprintf('input: %s\n', results.input_path);
    fprintf('pipeline: %s\n', strjoin(results.pipeline, ' -> '));

    for file_idx = 1:numel(results.file_results)
        file_result = results.file_results(file_idx);
        max_rd_linear = 0;

        if ~isempty(file_result.frames)
            frame_energy = arrayfun(@(f) sum(f.rd_linear_cube(:)), file_result.frames);
            detection_count = arrayfun(@(f) nnz(f.cfar_mask_map), file_result.frames);
            point_count = arrayfun(@(f) size(f.preliminary_point_cloud, 1), file_result.frames);
            max_rd_linear = max(frame_energy);
            total_detections = sum(detection_count);
            total_points = sum(point_count);
        else
            total_detections = 0;
            total_points = 0;
        end

        fprintf(['[%d] %s | frames=%d | adc_samples=%d | rd_bins=%dx%d | ', ...
                 'max_rd_linear=%.3e | cfar_detections=%d | ', ...
                 'prelim_points=%d\n'], ...
            file_idx, file_result.file_name, file_result.num_frames, ...
            file_result.num_adc_complex_samples, ...
            numel(file_result.range_axis_m), numel(file_result.doppler_axis_mps), ...
            max_rd_linear, total_detections, total_points);
    end

    fprintf('\n');
end
