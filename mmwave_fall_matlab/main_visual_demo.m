function visual_results = main_visual_demo(input_path)
%MAIN_VISUAL_DEMO Visualize RD and micro-Doppler products only.
%   visual_results = main_visual_demo(input_path)
%
%   Output:
%     visual_results.processing_result
%     visual_results.visual_products
%     visual_results.display_frame_idx

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
    rd_amplitude_map = visual_products.rd_amplitude_maps(:, :, display_frame_idx);

    fig_rd = show_rd_map(rd_amplitude_map, visual_products.range_axis_m, ...
        visual_products.doppler_axis_mps, display_frame_idx, visual_cfg, file_label);
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

function local_print_main_visual_summary(visual_results, file_result, visual_cfg)
    frame_result = file_result.frames(visual_results.display_frame_idx);
    rd_size = size(frame_result.rd_amplitude_map);

    fprintf('\nmain_visual_demo completed\n');
    fprintf('file: %s\n', file_result.file_path);
    fprintf('display_frame: %d / %d\n', visual_results.display_frame_idx, file_result.num_frames);
    fprintf('rd_map_size: %d x %d | micro_doppler_frames: %d\n', ...
        rd_size(1), rd_size(2), visual_results.visual_products.num_frames);

    if visual_cfg.save_figures
        fprintf('figures_saved_to: %s\n', visual_cfg.output_dir);
    end

    fprintf('\n');
end
