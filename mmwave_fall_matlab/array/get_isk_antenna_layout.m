function antenna = get_isk_antenna_layout(radar_cfg)
%GET_ISK_ANTENNA_LAYOUT 返回与当前实物布局一致的 IWR6843ISK 阵列定义。
%
% 输入：
%   radar_cfg : struct
%       radar_config.m 返回的配置结构体。
%
% 输出：
%   antenna : struct
%       antenna.lambda_m           : 波长
%       antenna.rx_pos_lambda      : [4x2]，RX 相位中心位置，单位 λ
%       antenna.tx_pos_lambda      : [3x2]，TX 相位中心位置，单位 λ
%       antenna.virtual_pos_lambda : [12x2]，虚拟阵元位置，单位 λ
%       antenna.virtual_pos_m      : [12x2]，虚拟阵元位置，单位 m
%       antenna.virtual_labels     : {12x1}，虚拟通道标签
%
% 说明：
%   1. x 轴表示水平阵列方向，z 轴表示竖直方向。
%   2. 物理布局依据当前 ISK 实物拓扑：
%      RX1~RX4 同行，TX1/TX3 同行，TX2 上抬半个波长。
%   3. 虚拟通道顺序严格跟随 process_data_v1.py 的块顺序：
%      [TX1-RX1..4, TX3-RX1..4, TX2-RX1..4]
%   4. 这里使用相位中心近似，不引入板级毫米级补偿。

    lambda_m = radar_cfg.rf.lambda_m;

    % RX 沿水平线均匀排列，间距 lambda/2
    rx_pos_lambda = [ ...
        0.0, 0.0; ...
        0.5, 0.0; ...
        1.0, 0.0; ...
        1.5, 0.0];

    % TX1/TX3 位于水平阵列，TX2 上抬 half-lambda
    tx_pos_lambda = [ ...
        0.0, 0.0; ...
        1.0, 0.5; ...
        2.0, 0.0];

    virtual_pos_lambda = zeros(radar_cfg.frame.num_rx * radar_cfg.frame.num_tx, 2);
    virtual_labels = cell(radar_cfg.frame.num_rx * radar_cfg.frame.num_tx, 1);
    write_idx = 1;

    for tx_id = radar_cfg.frame.actual_tx_order
        for rx_id = radar_cfg.frame.rx_order
            virtual_pos_lambda(write_idx, :) = ...
                tx_pos_lambda(tx_id, :) + rx_pos_lambda(rx_id, :);
            virtual_labels{write_idx} = sprintf('TX%d_RX%d', tx_id, rx_id);
            write_idx = write_idx + 1;
        end
    end

    antenna = struct();
    antenna.lambda_m = lambda_m;
    antenna.rx_pos_lambda = rx_pos_lambda;
    antenna.tx_pos_lambda = tx_pos_lambda;
    antenna.virtual_pos_lambda = virtual_pos_lambda;
    antenna.virtual_pos_m = virtual_pos_lambda * lambda_m;
    antenna.virtual_labels = virtual_labels;
end
