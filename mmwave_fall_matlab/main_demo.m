function results = main_demo(input_path)
%MAIN_DEMO Process DCA1000 data up to Doppler FFT only.
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
%     results.pipeline
%     results.file_results(k).adc_stream
%     results.file_results(k).frames(frame_idx).adc_frame_cube
%     results.file_results(k).frames(frame_idx).mimo_cube
%     results.file_results(k).frames(frame_idx).range_cube
%     results.file_results(k).frames(frame_idx).clutter_free_cube
%     results.file_results(k).frames(frame_idx).rd_cube
%     results.file_results(k).frames(frame_idx).rd_power_map
%     results.file_results(k).frames(frame_idx).rd_amplitude_map

    project_root = fileparts(mfilename('fullpath'));
    addpath(genpath(project_root));

    radar_cfg = radar_config(fullfile(project_root, 'config', 'Radar.cfg'));

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
    results.pipeline = { ...
        'read_dca1000_adc', ...
        'reshape_frame_cube', ...
        'deinterleave_tdm_mimo', ...
        'range_fft', ...
        'static_clutter_remove', ...
        'doppler_fft'};
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
            frame_result = local_process_frame_until_2dfft(adc_frame_cube, radar_cfg);
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

function frame_result = local_process_frame_until_2dfft(adc_frame_cube, radar_cfg)
    mimo_cube = deinterleave_tdm_mimo(adc_frame_cube, radar_cfg);

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

    frame_result = struct( ...
        'frame_id', 0, ...
        'adc_frame_cube', adc_frame_cube, ...
        'mimo_cube', mimo_cube, ...
        'range_cube', range_cube, ...
        'clutter_free_cube', clutter_free_cube, ...
        'rd_cube', rd_cube, ...
        'rd_power_map', rd_power_map, ...
        'rd_amplitude_map', rd_amplitude_map);
end

function frame_result = local_empty_frame_result()
    frame_result = struct( ...
        'frame_id', 0, ...
        'adc_frame_cube', [], ...
        'mimo_cube', [], ...
        'range_cube', [], ...
        'clutter_free_cube', [], ...
        'rd_cube', [], ...
        'rd_power_map', [], ...
        'rd_amplitude_map', []);
end

function local_print_main_demo_summary(results)
    fprintf('\nmain_demo completed\n');
    fprintf('mode: %s\n', results.mode);
    fprintf('input: %s\n', results.input_path);
    fprintf('pipeline: %s\n', strjoin(results.pipeline, ' -> '));

    for file_idx = 1:numel(results.file_results)
        file_result = results.file_results(file_idx);
        max_rd_energy = 0;

        if ~isempty(file_result.frames)
            frame_energy = arrayfun(@(f) sum(f.rd_power_map(:)), file_result.frames);
            max_rd_energy = max(frame_energy);
        end

        fprintf('[%d] %s | frames=%d | adc_samples=%d | rd_bins=%dx%d | max_rd_energy=%.3e\n', ...
            file_idx, file_result.file_name, file_result.num_frames, ...
            file_result.num_adc_complex_samples, ...
            numel(file_result.range_axis_m), numel(file_result.doppler_axis_mps), ...
            max_rd_energy);
    end

    fprintf('\n');
end
