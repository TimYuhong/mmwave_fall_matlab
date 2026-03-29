function virtual_snapshot = stack_virtual_channels(rd_cube, range_bin, doppler_bin)
%STACK_VIRTUAL_CHANNELS 将 [rx, tx] 切片堆叠成 12x1 虚拟通道列向量。
%
% 输入：
%   rd_cube      : complex double
%       维度 [num_range_bins, num_doppler_bins, num_rx, num_tx]
%   range_bin    : double
%       1-based 距离 bin 索引。
%   doppler_bin  : double
%       1-based Doppler bin 索引。
%
% 输出：
%   virtual_snapshot : complex double 列向量
%       维度 [num_virtual_ant, 1]，顺序为
%       [TX1-RX1..4, TX2-RX1..4, TX3-RX1..4]

    slice = squeeze(rd_cube(range_bin, doppler_bin, :, :));   % [rx, tx]
    virtual_snapshot = reshape(slice, [], 1);
end
