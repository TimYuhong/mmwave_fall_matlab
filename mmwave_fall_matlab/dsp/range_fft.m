function [range_cube, range_bin_axis] = range_fft(adc_cube, fft_cfg)
%RANGE_FFT 对 FMCW MIMO radar cube 的快时间维执行窗函数和 FFT。
%
% 函数签名：
%   [range_cube, range_bin_axis] = range_fft(adc_cube, fft_cfg)
%
% 输入：
%   adc_cube : complex double
%       维度 [num_adc_samples, num_loops, num_rx, num_tx]
%       第 1 维为快时间（ADC samples）。
%
%   fft_cfg : struct
%       fft_cfg.fft_size    : 距离 FFT 点数，默认 size(adc_cube, 1)
%       fft_cfg.window_type : 窗函数类型，支持：
%                             'hann' / 'hamming' / 'blackman' / 'rect'
%
% 输出：
%   range_cube : complex double
%       维度 [num_range_bins, num_loops, num_rx, num_tx]
%       第 1 维为距离 bin。
%
%   range_bin_axis : double 列向量
%       长度 num_range_bins，对应输出距离 bin 的索引轴。
%
% 说明：
%   1. 本函数只负责快时间维频谱变换，不做距离门限裁剪。
%   2. 如果需要把 bin 转成米，请结合 Radar.cfg 推导的距离分辨率使用。

    narginchk(2, 2);

    num_adc_samples = size(adc_cube, 1);
    if isfield(fft_cfg, 'fft_size') && ~isempty(fft_cfg.fft_size)
        fft_size = fft_cfg.fft_size;
    else
        fft_size = num_adc_samples;
    end

    if isfield(fft_cfg, 'window_type') && ~isempty(fft_cfg.window_type)
        window_type = fft_cfg.window_type;
    else
        window_type = 'hann';
    end

    % 生成快时间维窗函数，并扩展到 4 维便于逐点相乘
    win = local_make_window(window_type, num_adc_samples);
    win = reshape(win, [num_adc_samples, 1, 1, 1]);

    % 对快时间维加窗后做 FFT
    windowed_cube = adc_cube .* win;
    range_cube = fft(windowed_cube, fft_size, 1);

    range_bin_axis = (0:fft_size-1).';
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
            error('range_fft:UnsupportedWindow', ...
                '不支持的距离窗函数类型：%s', window_type);
    end

    win = win(:);
end
