function visual_results = main_visual_demo(input_path)
%MAIN_VISUAL_DEMO 对单个 bin 文件做可视化处理，输出 RD 图和微多普勒图。
%
% 函数签名：
%   visual_results = main_visual_demo(input_path)
%
% 输入：
%   input_path : char/string，可选
%       单个 DCA1000 bin 文件路径。
%       如果不传，则默认读取：
%       F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin
%
% 输出：
%   visual_results : struct
%       .processing_result : main_demo.m 输出结果
%       .visual_products   : compute_visual_products.m 输出
%       .display_frame_idx : 当前展示的帧号

    project_root = fileparts(mfilename('fullpath'));
    addpath(genpath(project_root));

    radar_cfg = radar_config(fullfile(project_root, 'config', 'Radar.cfg'));
    aoa_cfg = aoa_config();
    visual_cfg = visual_config();
    antenna_layout = get_isk_antenna_layout(radar_cfg);

    if nargin < 1 || isempty(input_path)
        input_path = visual_cfg.default_bin_path;
    end

    processing_result = main_demo(input_path);
    if numel(processing_result.file_results) ~= 1
        error('main_visual_demo:SingleFileOnly', ...
            '当前 main_visual_demo 仅支持单个 bin 文件输入。');
    end

    file_result = processing_result.file_results(1);
    visual_products = compute_visual_products(file_result.file_path, radar_cfg, visual_cfg);

    det_counts = arrayfun(@(f) size(f.detection_list, 1), file_result.frames);
    if ~isempty(visual_cfg.preferred_frame_index)
        display_frame_idx = max(1, min(file_result.num_frames, visual_cfg.preferred_frame_index));
    elseif any(det_counts > 0)
        [~, display_frame_idx] = max(det_counts);
    else
        display_frame_idx = ceil(file_result.num_frames / 2);
    end

    file_label = file_result.file_name;
    frame_result = file_result.frames(display_frame_idx);
    rd_amplitude_map = visual_products.rd_amplitude_maps(:, :, display_frame_idx);
    angle_products = compute_range_angle_maps(frame_result, radar_cfg, antenna_layout, aoa_cfg, visual_cfg);

    fig_rd = show_rd_map(rd_amplitude_map, visual_products.range_axis_m, ...
        visual_products.doppler_axis_mps, display_frame_idx, visual_cfg, file_label);
    fig_md = show_micro_doppler_map(visual_products.micro_doppler_map, ...
        visual_products.time_axis_s, visual_products.doppler_axis_mps, visual_cfg, file_label);
    fig_ra = show_ra_map(angle_products.range_azimuth_map, angle_products.range_axis_m, ...
        angle_products.azimuth_axis_deg, display_frame_idx, visual_cfg, file_label);
    fig_re = show_re_map(angle_products.range_elevation_map, angle_products.range_axis_m, ...
        angle_products.elevation_axis_deg, display_frame_idx, visual_cfg, file_label);
    fig_pc = show_point_cloud_frame(frame_result, display_frame_idx, file_label);

    if visual_cfg.save_figures
        if exist(visual_cfg.output_dir, 'dir') ~= 7
            mkdir(visual_cfg.output_dir);
        end
        saveas(fig_rd, fullfile(visual_cfg.output_dir, [file_label, '_rd.png']));
        saveas(fig_md, fullfile(visual_cfg.output_dir, [file_label, '_micro_doppler.png']));
        saveas(fig_ra, fullfile(visual_cfg.output_dir, [file_label, '_ra.png']));
        saveas(fig_re, fullfile(visual_cfg.output_dir, [file_label, '_re.png']));
        saveas(fig_pc, fullfile(visual_cfg.output_dir, [file_label, '_point_cloud.png']));
    end

    visual_results = struct();
    visual_results.processing_result = processing_result;
    visual_results.visual_products = visual_products;
    visual_results.angle_products = angle_products;
    visual_results.display_frame_idx = display_frame_idx;

    if nargout == 0
        local_print_main_visual_summary(visual_results, file_result, visual_cfg);
    end
end

function local_print_main_visual_summary(visual_results, file_result, visual_cfg)
    frame_result = file_result.frames(visual_results.display_frame_idx);

    fprintf('\nmain_visual_demo completed\n');
    fprintf('file: %s\n', file_result.file_path);
    fprintf('display_frame: %d / %d\n', visual_results.display_frame_idx, file_result.num_frames);
    fprintf('detections: %d | point_cloud: %d | human_cloud: %d | stable_cloud: %d\n', ...
        size(frame_result.detection_list, 1), size(frame_result.point_cloud.xyz, 1), ...
        size(frame_result.human_cloud.xyz, 1), size(frame_result.stable_cloud.xyz, 1));

    if visual_cfg.save_figures
        fprintf('figures_saved_to: %s\n', visual_cfg.output_dir);
    end

    fprintf('\n');
end
