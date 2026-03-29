function results = main_demo(input_path)
%MAIN_DEMO mmWave 跌倒场景动静融合点云主流程示例。
% 函数签名：
%   results = main_demo(input_path)
%
% 输入：
%   input_path : char/string，可选
%       1. 单个 DCA1000 原始 ADC bin 文件路径
%       2. 包含多个 bin 文件的目录路径
%
% 输出：
%   results : struct
%       results.mode         : 'single_file' 或 'directory'
%       results.input_path   : 实际输入路径
%       results.file_results : 每个文件对应一个结果结构体
%
% main_demo.m 中的新调用示例：
%   mimo_cube = deinterleave_tdm_mimo(frame_cube, radar_cfg);
%   [point_cloud, mpoint_debug] = gen_pointcloud_comprehensive_mpoint( ...
%       mimo_cube, radar_cfg, antenna_layout, mpoint_cfg, aoa_cfg);
%   [filtered_cloud, ~] = prefilter_human_roi(point_cloud, cluster_cfg);
%   [cluster_result, human_cloud, track_state] = cluster_dbscan_human( ...
%       filtered_cloud, cluster_cfg, track_state);
%   voxel_map = build_voxel_confidence_map(history_human_clouds, stable_cfg);
%   stable_cloud = voxel_map.stable_cloud;

    project_root = fileparts(mfilename('fullpath'));
    addpath(genpath(project_root));

    radar_cfg = radar_config(fullfile(project_root, 'config', 'Radar.cfg'));
    aoa_cfg = aoa_config();
    mpoint_cfg = mpoint_config(radar_cfg);
    cluster_cfg = cluster_config();
    stable_cfg = stable_config();
    antenna_layout = get_isk_antenna_layout(radar_cfg);

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
                '目录中未找到 bin 文件：%s', input_path);
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
            ['输入路径不存在：', input_path, newline, ...
             '请传入 bin 文件路径，或包含多个 bin 的目录路径。']);
    end

    results = struct();
    results.mode = result_mode;
    results.input_path = input_path;
    results.file_results = repmat(struct( ...
        'file_path', '', ...
        'file_name', '', ...
        'num_frames', 0, ...
        'frames', struct([])), numel(bin_files), 1);

    for file_idx = 1:numel(bin_files)
        current_bin = bin_files{file_idx};
        [adc_stream, num_frames] = read_dca1000_adc(current_bin, radar_cfg);
        frame_cubes = reshape_frame_cube(adc_stream, radar_cfg);

        frame_results = repmat(struct( ...
            'frame_id', 0, ...
            'detection_list', zeros(0, 6), ...
            'point_cloud', local_empty_point_cloud(), ...
            'filtered_cloud', local_empty_point_cloud(), ...
            'cluster_result', struct(), ...
            'human_cloud', local_empty_human_cloud(), ...
            'stable_cloud', local_empty_stable_cloud(), ...
            'voxel_map', struct(), ...
            'mpoint_debug', struct()), num_frames, 1);

        history_human_clouds = cell(0, 1);
        track_state = struct('is_valid', false, 'centroid', [NaN, NaN, NaN]);

        for frame_idx = 1:num_frames
            frame_cube = frame_cubes(:, :, :, frame_idx);   % [sample, rx, chirp]
            mimo_cube = deinterleave_tdm_mimo(frame_cube, radar_cfg);

            [point_cloud, mpoint_debug] = gen_pointcloud_comprehensive_mpoint( ...
                mimo_cube, radar_cfg, antenna_layout, mpoint_cfg, aoa_cfg);

            [filtered_cloud, ~] = prefilter_human_roi(point_cloud, cluster_cfg);
            [cluster_result, human_cloud, track_state] = cluster_dbscan_human( ...
                filtered_cloud, cluster_cfg, track_state);

            history_human_clouds = [history_human_clouds; {human_cloud}]; %#ok<AGROW>
            if numel(history_human_clouds) > stable_cfg.window_length_frames
                history_human_clouds = history_human_clouds(end - stable_cfg.window_length_frames + 1:end);
            end

            voxel_map = build_voxel_confidence_map(history_human_clouds, stable_cfg);
            stable_cloud = voxel_map.stable_cloud;

            frame_results(frame_idx).frame_id = frame_idx;
            frame_results(frame_idx).detection_list = mpoint_debug.dynamic_candidate_list;
            frame_results(frame_idx).point_cloud = point_cloud;
            frame_results(frame_idx).filtered_cloud = filtered_cloud;
            frame_results(frame_idx).cluster_result = cluster_result;
            frame_results(frame_idx).human_cloud = human_cloud;
            frame_results(frame_idx).stable_cloud = stable_cloud;
            frame_results(frame_idx).voxel_map = voxel_map;
            frame_results(frame_idx).mpoint_debug = mpoint_debug;
        end

        [~, file_name, file_ext] = fileparts(current_bin);
        results.file_results(file_idx).file_path = current_bin;
        results.file_results(file_idx).file_name = [file_name, file_ext];
        results.file_results(file_idx).num_frames = num_frames;
        results.file_results(file_idx).frames = frame_results;
    end

    if nargout == 0
        local_print_main_demo_summary(results);
    end
end

function point_cloud = local_empty_point_cloud()
    point_cloud = struct();
    point_cloud.points = zeros(0, 7);
    point_cloud.xyz = zeros(0, 3);
    point_cloud.v_mps = zeros(0, 1);
    point_cloud.snr_db = zeros(0, 1);
    point_cloud.intensity = zeros(0, 1);
    point_cloud.source_flag = zeros(0, 1);
    point_cloud.range_m = zeros(0, 1);
    point_cloud.azimuth_deg = zeros(0, 1);
    point_cloud.elevation_deg = zeros(0, 1);
    point_cloud.range_bin = zeros(0, 1);
    point_cloud.doppler_bin = zeros(0, 1);
    point_cloud.doppler_mps = zeros(0, 1);
    point_cloud.power_linear = zeros(0, 1);
    point_cloud.power_db = zeros(0, 1);
end

function human_cloud = local_empty_human_cloud()
    human_cloud = local_empty_point_cloud();
    human_cloud.label = -1;
    human_cloud.centroid = [NaN, NaN, NaN];
    human_cloud.bbox = nan(2, 3);
end

function stable_cloud = local_empty_stable_cloud()
    stable_cloud = struct();
    stable_cloud.xyz = zeros(0, 3);
    stable_cloud.confidence = zeros(0, 1);
    stable_cloud.hit_count = zeros(0, 1);
    stable_cloud.num_valid_frames = 0;
    stable_cloud.reference_center = [NaN, NaN, NaN];
end

function local_print_main_demo_summary(results)
    fprintf('\nmain_demo completed\n');
    fprintf('mode: %s\n', results.mode);
    fprintf('input: %s\n', results.input_path);

    for file_idx = 1:numel(results.file_results)
        file_result = results.file_results(file_idx);
        det_count = arrayfun(@(f) size(f.detection_list, 1), file_result.frames);
        point_count = arrayfun(@(f) size(f.point_cloud.xyz, 1), file_result.frames);
        human_count = arrayfun(@(f) size(f.human_cloud.xyz, 1), file_result.frames);
        stable_count = arrayfun(@(f) size(f.stable_cloud.xyz, 1), file_result.frames);

        fprintf('[%d] %s | frames=%d | det_frames=%d | max_points=%d | max_human=%d | max_stable=%d\n', ...
            file_idx, file_result.file_name, file_result.num_frames, nnz(det_count > 0), ...
            max(point_count, [], 'omitnan'), max(human_count, [], 'omitnan'), max(stable_count, [], 'omitnan'));
    end

    fprintf('\n');
end
