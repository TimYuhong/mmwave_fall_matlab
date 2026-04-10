function [rd_cube, doppler_bin_axis] = doppler_fft(slow_time_cube, fft_cfg)
%DOPPLER_FFT 对慢时间维执行窗函数、FFT 和 fftshift。
%
% 函数签名：
%   [rd_cube, doppler_bin_axis] = doppler_fft(slow_time_cube, fft_cfg)
%
% 输入：
%   slow_time_cube : complex double
%       维度 [num_range_bins, num_loops, num_rx, num_tx]
%       第 2 维为慢时间（chirp loops）。
%
%   fft_cfg : struct
%       fft_cfg.fft_size    : Doppler FFT 点数，默认 size(slow_time_cube, 2)
%       fft_cfg.window_type : 窗函数类型，支持：
%                             'hann' / 'hamming' / 'blackman' / 'rect'
%       fft_cfg.apply_shift : 是否做 fftshift，默认 true
%
% 输出：
%   rd_cube : complex double
%       维度 [num_range_bins, num_doppler_bins, num_rx, num_tx]
%
%   doppler_bin_axis : double 列向量
%       长度 num_doppler_bins，对应 Doppler bin 索引轴。

    narginchk(2, 2);

    num_loops = size(slow_time_cube, 2);

    if isfield(fft_cfg, 'fft_size') && ~isempty(fft_cfg.fft_size)
        fft_size = fft_cfg.fft_size;
    else
        fft_size = num_loops;
    end

    if isfield(fft_cfg, 'window_type') && ~isempty(fft_cfg.window_type)
        window_type = fft_cfg.window_type;
    else
        window_type = 'hann';
    end

    if isfield(fft_cfg, 'apply_shift')
        apply_shift = logical(fft_cfg.apply_shift);
    else
        apply_shift = true;
    end

    win = local_make_window(window_type, num_loops);
    win = reshape(win, [1, num_loops, 1, 1]);

    windowed_cube = slow_time_cube .* win;
    rd_cube = fft(windowed_cube, fft_size, 2);

    if apply_shift
        rd_cube = fftshift(rd_cube, 2);
        doppler_bin_axis = ((-floor(fft_size / 2)):(ceil(fft_size / 2) - 1)).';
    else
        doppler_bin_axis = (0:fft_size-1).';
    end
end

function win = local_make_window(window_type, n)
    switch lower(string(window_type))
        case "hann"
            win = hann(n);
        case "hamming"
            win = hamming(n);
        case "blackman"
            win = blackman(n);
        case {"rect", "rectwin", "none"}
            win = rectwin(n);
        otherwise
            error('doppler_fft:UnsupportedWindow', ...
                '不支持的 Doppler 窗函数类型：%s', window_type);
    end

    win = win(:);
end
