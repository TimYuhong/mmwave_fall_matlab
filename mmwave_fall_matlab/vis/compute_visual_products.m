function visual_products = compute_visual_products(input_path, radar_cfg, visual_cfg)
%COMPUTE_VISUAL_PRODUCTS 计算 RD 图和微多普勒图所需中间量。
% 输入：
%   input_path  : char/string
%       单个 DCA1000 bin 文件路径。
%   radar_cfg   : struct
%       radar_config.m 输出。
%   visual_cfg  : struct
%       visual_config.m 输出。
%
% 输出：
%   visual_products : struct
%       .rd_amplitude_maps  [range, doppler, frame]
%       .micro_doppler_map  [doppler, frame]
%       .range_axis_m       [range, 1]
%       .doppler_axis_mps   [doppler, 1]
%       .time_axis_s        [frame, 1]
%       .range_roi_bins     [1, 2]
%       .num_frames         标量

    [adc_stream, num_frames] = read_dca1000_adc(input_path, radar_cfg);
    frame_cubes = reshape_frame_cube(adc_stream, radar_cfg);

    num_range_bins = radar_cfg.fft.range_fft_size;
    num_doppler_bins = radar_cfg.fft.doppler_fft_size;
    rd_amplitude_maps = zeros(num_range_bins, num_doppler_bins, num_frames);
    micro_doppler_map = zeros(num_doppler_bins, num_frames);

    range_axis_m = range_bin_to_meters((1:num_range_bins).', radar_cfg);
    doppler_axis_mps = doppler_bin_to_mps((1:num_doppler_bins).', radar_cfg);
    time_axis_s = ((0:num_frames-1).' * radar_cfg.frame.frame_periodicity_ms) / 1e3;

    range_mask = range_axis_m >= visual_cfg.range_roi_m(1) & ...
                 range_axis_m <= visual_cfg.range_roi_m(2);
    range_mask(1:min(visual_cfg.skip_near_range_bins, numel(range_mask))) = false;
    if ~any(range_mask)
        range_mask = true(size(range_axis_m));
        range_mask(1:min(visual_cfg.skip_near_range_bins, numel(range_mask))) = false;
    end
    if ~any(range_mask)
        range_mask = true(size(range_axis_m));
    end
    range_roi_bins = [find(range_mask, 1, 'first'), find(range_mask, 1, 'last')];

    for frame_idx = 1:num_frames
        frame_cube = frame_cubes(:, :, :, frame_idx);
        mimo_cube = deinterleave_tdm_mimo(frame_cube, radar_cfg);

        [range_cube, ~] = range_fft(mimo_cube, struct( ...
            'fft_size', radar_cfg.fft.range_fft_size, ...
            'window_type', radar_cfg.fft.range_window));

        clutter_free_cube = static_clutter_remove(range_cube, struct('method', 'mean'));

        [rd_cube, ~] = doppler_fft(clutter_free_cube, struct( ...
            'fft_size', radar_cfg.fft.doppler_fft_size, ...
            'window_type', radar_cfg.fft.doppler_window, ...
            'apply_shift', true));

        rd_power_map = squeeze(sum(sum(abs(rd_cube).^2, 4), 3));
        rd_amplitude_map = sqrt(max(rd_power_map, 0));
        rd_amplitude_maps(:, :, frame_idx) = rd_amplitude_map;

        % 简化假设：微多普勒图通过对指定距离 ROI 上的 RD 原始幅度做积分获得。
        micro_doppler_map(:, frame_idx) = sum(rd_amplitude_map(range_mask, :), 1).';
    end

    visual_products = struct();
    visual_products.rd_amplitude_maps = rd_amplitude_maps;
    visual_products.micro_doppler_map = micro_doppler_map;
    visual_products.range_axis_m = range_axis_m;
    visual_products.doppler_axis_mps = doppler_axis_mps;
    visual_products.time_axis_s = time_axis_s;
    visual_products.range_roi_bins = range_roi_bins;
    visual_products.num_frames = num_frames;
end
