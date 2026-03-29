function doppler_mps = doppler_bin_to_mps(doppler_bin, radar_cfg)
%DOPPLER_BIN_TO_MPS 将 1-based Doppler bin 索引转换为径向速度（m/s）。
%
% 输入：
%   doppler_bin : double / 向量
%       1-based Doppler bin 索引，默认对应 fftshift 之后的频谱。
%   radar_cfg   : struct
%       radar_config.m 返回的配置结构体。
%
% 输出：
%   doppler_mps : double / 向量
%       与 doppler_bin 形状一致的径向速度，单位 m/s。

    fft_size = radar_cfg.fft.doppler_fft_size;
    center_bin = floor(fft_size / 2) + 1;
    signed_index = double(doppler_bin) - center_bin;
    doppler_mps = signed_index * radar_cfg.metrics.doppler_resolution_mps;
end
