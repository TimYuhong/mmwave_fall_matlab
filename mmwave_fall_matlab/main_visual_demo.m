function visual_results = main_visual_demo(input_path)
%MAIN_VISUAL_DEMO Visualize RD and micro-Doppler products only.
%   visual_results = main_visual_demo(input_path)
%
%   Output:
%     visual_results.processing_result
%     visual_results.visual_products
%     visual_results.display_frame_idx
%     visual_results.cfar_overlay

    project_root = fileparts(mfilename('fullpath'));
    addpath(genpath(project_root));

    radar_cfg = radar_config(fullfile(project_root, 'config', 'Radar.cfg'));
    visual_cfg = visual_config();

    if nargin < 1 || isempty(input_path)
        input_path = visual_cfg.default_bin_path;
    end

    processing_result = main_demo(input_path);
    if numel(processing_result.file_results) ~= 1
        error('main_visual_demo:SingleFileOnly', ...
            'main_visual_demo only supports a single .bin file input.');
    end

    file_result = processing_result.file_results(1);
    if file_result.num_frames < 1
        error('main_visual_demo:NoFrames', ...
            'No valid frame was parsed from file: %s', file_result.file_path);
    end

    visual_products = compute_visual_products(file_result.file_path, radar_cfg, visual_cfg);
    display_frame_idx = local_choose_display_frame(file_result, visual_products, visual_cfg);

    file_label = file_result.file_name;
    frame_result = file_result.frames(display_frame_idx);
    rd_display_map = frame_result.rd_amplitude_map;
    cfar_overlay = local_build_cfar_overlay(frame_result, visual_cfg);

    fig_rd = show_rd_map(rd_display_map, file_result.range_axis_m, ...
        file_result.doppler_axis_mps, display_frame_idx, visual_cfg, file_label, cfar_overlay);
    fig_md = show_micro_doppler_map(visual_products.micro_doppler_map, ...
        visual_products.time_axis_s, visual_products.doppler_axis_mps, visual_cfg, file_label);

    if visual_cfg.save_figures
        if exist(visual_cfg.output_dir, 'dir') ~= 7
            mkdir(visual_cfg.output_dir);
        end
        saveas(fig_rd, fullfile(visual_cfg.output_dir, [file_label, '_rd.png']));
        saveas(fig_md, fullfile(visual_cfg.output_dir, [file_label, '_micro_doppler.png']));
    end

    visual_results = struct();
    visual_results.processing_result = processing_result;
    visual_results.visual_products = visual_products;
    visual_results.display_frame_idx = display_frame_idx;
    visual_results.cfar_overlay = cfar_overlay;

    if nargout == 0
        local_print_main_visual_summary(visual_results, file_result, visual_cfg);
    end
end

function display_frame_idx = local_choose_display_frame(file_result, visual_products, visual_cfg)
    if ~isempty(visual_cfg.preferred_frame_index)
        display_frame_idx = max(1, min(file_result.num_frames, visual_cfg.preferred_frame_index));
        return;
    end

    frame_energy = squeeze(sum(visual_products.micro_doppler_map, 1));
    if isempty(frame_energy)
        display_frame_idx = 1;
    elseif any(frame_energy > 0)
        [~, display_frame_idx] = max(frame_energy);
    else
        display_frame_idx = ceil(file_result.num_frames / 2);
    end
end

function cfar_overlay = local_build_cfar_overlay(frame_result, visual_cfg)
    cfar_overlay = struct( ...
        'frame_index', frame_result.frame_id, ...
        'total_detections', 0, ...
        'drawn_detections', 0, ...
        'range_m', zeros(0, 1), ...
        'doppler_mps', zeros(0, 1), ...
        'color', [1, 0, 0], ...
        'marker_size', 8, ...
        'line_width', 1.2);

    if ~isfield(visual_cfg, 'show_cfar_overlay') || ~visual_cfg.show_cfar_overlay
        return;
    end

    if isfield(visual_cfg, 'cfar_overlay_color') && numel(visual_cfg.cfar_overlay_color) == 3
        cfar_overlay.color = visual_cfg.cfar_overlay_color;
    end
    if isfield(visual_cfg, 'cfar_overlay_marker_size') && ~isempty(visual_cfg.cfar_overlay_marker_size)
        cfar_overlay.marker_size = visual_cfg.cfar_overlay_marker_size;
    end
    if isfield(visual_cfg, 'cfar_overlay_line_width') && ~isempty(visual_cfg.cfar_overlay_line_width)
        cfar_overlay.line_width = visual_cfg.cfar_overlay_line_width;
    end

    if ~isfield(frame_result, 'cfar_peaks') || isempty(frame_result.cfar_peaks)
        return;
    end

    cfar_peaks = frame_result.cfar_peaks;
    cfar_overlay.total_detections = height(cfar_peaks);
    if isempty(cfar_peaks)
        return;
    end

    skip_near_range_bins = 0;
    if isfield(visual_cfg, 'skip_near_range_bins') && ~isempty(visual_cfg.skip_near_range_bins)
        skip_near_range_bins = max(0, round(visual_cfg.skip_near_range_bins));
    end

    visible_mask = double(cfar_peaks.range_bin(:)) > skip_near_range_bins;
    cfar_peaks = cfar_peaks(visible_mask, :);
    if isempty(cfar_peaks)
        return;
    end

    overlay_mode = 'merged_topk';
    if isfield(visual_cfg, 'cfar_overlay_mode') && ~isempty(visual_cfg.cfar_overlay_mode)
        overlay_mode = char(visual_cfg.cfar_overlay_mode);
    end

    if strcmpi(overlay_mode, 'merged_topk') || strcmpi(overlay_mode, 'topk')
        top_k = 20;
        if isfield(visual_cfg, 'cfar_overlay_top_k') && ~isempty(visual_cfg.cfar_overlay_top_k)
            top_k = max(1, round(visual_cfg.cfar_overlay_top_k));
        end
        [~, sort_idx] = sort(double(cfar_peaks.amplitude(:)), 'descend');
        keep_count = min(top_k, numel(sort_idx));
        cfar_peaks = cfar_peaks(sort_idx(1:keep_count), :);
    end

    cfar_overlay.range_m = double(cfar_peaks.range_m(:));
    cfar_overlay.doppler_mps = double(cfar_peaks.doppler_mps(:));
    cfar_overlay.drawn_detections = numel(cfar_overlay.range_m);
end

function local_print_main_visual_summary(visual_results, file_result, visual_cfg)
    frame_result = file_result.frames(visual_results.display_frame_idx);
    rd_size = size(frame_result.rd_linear_cube);

    fprintf('\nmain_visual_demo completed\n');
    fprintf('file: %s\n', file_result.file_path);
    fprintf('display_frame: %d / %d\n', visual_results.display_frame_idx, file_result.num_frames);
    fprintf('rd_linear_cube_size: %d x %d x %d x %d | micro_doppler_frames: %d\n', ...
        rd_size(1), rd_size(2), rd_size(3), rd_size(4), visual_results.visual_products.num_frames);
    fprintf('cfar_overlay: total=%d | drawn=%d\n', ...
        visual_results.cfar_overlay.total_detections, ...
        visual_results.cfar_overlay.drawn_detections);

    if visual_cfg.save_figures
        fprintf('figures_saved_to: %s\n', visual_cfg.output_dir);
    end

    fprintf('\n');
end
