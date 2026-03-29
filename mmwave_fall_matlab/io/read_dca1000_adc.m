function [adc_stream, num_frames] = read_dca1000_adc(bin_path, radar_cfg)
%READ_DCA1000_ADC 读取 DCA1000 原始 ADC bin，并重建复数序列。
%
% 输入：
%   bin_path   : char/string
%       原始 ADC bin 文件路径。
%   radar_cfg  : struct
%       radar_config.m 返回的配置结构体。
%
% 输出：
%   adc_stream : complex double 列向量
%       复数 ADC 流，严格对齐 process_data_v1.py：
%       - sample_swap == 1: Q 为偶数位，I 为奇数位，adc = I + jQ
%       - sample_swap == 0: I 为偶数位，Q 为奇数位，adc = I + jQ
%   num_frames : double
%       根据 Radar.cfg 能完整切分出的帧数。

    fid = fopen(bin_path, 'r');
    if fid < 0
        error('read_dca1000_adc:OpenFailed', '无法打开 ADC 文件：%s', bin_path);
    end
    cleanup_obj = onCleanup(@() fclose(fid));

    raw_iq = fread(fid, inf, radar_cfg.io.int_type);
    if mod(numel(raw_iq), 2) ~= 0
        warning('read_dca1000_adc:OddLength', ...
            '原始 IQ 长度不是偶数，最后一个样本将被丢弃。');
        raw_iq = raw_iq(1:end-1);
    end

    if radar_cfg.io.sample_swap == 1
        q_samples = double(raw_iq(1:2:end));
        i_samples = double(raw_iq(2:2:end));
    else
        i_samples = double(raw_iq(1:2:end));
        q_samples = double(raw_iq(2:2:end));
    end

    % 严格沿用 process_data_v1.py 的复数重建方式：I + jQ
    adc_stream = complex(i_samples, q_samples);

    complex_samples_per_frame = prod(radar_cfg.io.frame_cube_shape);
    num_frames = floor(numel(adc_stream) / complex_samples_per_frame);
    adc_stream = adc_stream(1:num_frames * complex_samples_per_frame);

    clear cleanup_obj;
end
