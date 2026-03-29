# mmwave_fall_matlab

基于当前 `Radar.cfg`、IWR6843ISK 实际物理天线布局、以及 `process_data_v1.py` 中已对齐的 ADC 重组逻辑搭建的 MATLAB 项目。

当前工程默认面向：
- `4 RX / 3 TX / 128 ADC samples / 64 loops / 192 chirps per frame`
- 实际 TDM 发射顺序：`[TX1, TX3, TX2]`
- ADC 重组逻辑：严格按 `adcbufCfg` 和 `process_data_v1.py` 对齐
- 目标数据：`F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin`

## 项目目录

```text
mmwave_fall_matlab/
|-- main_demo.m
|-- main_visual_demo.m
|-- README.md
|-- config/
|   |-- Radar.cfg
|   |-- radar_config.m
|   |-- cfar_config.m
|   |-- aoa_config.m
|   |-- mpoint_config.m
|   |-- cluster_config.m
|   |-- stable_config.m
|   `-- visual_config.m
|-- io/
|   |-- parse_ti_cfg.m
|   |-- read_dca1000_adc.m
|   `-- reshape_frame_cube.m
|-- array/
|   |-- get_isk_antenna_layout.m
|   |-- deinterleave_tdm_mimo.m
|   `-- stack_virtual_channels.m
|-- dsp/
|   |-- range_fft.m
|   |-- static_clutter_remove.m
|   |-- doppler_fft.m
|   |-- dynamic_cfar_2d.m
|   `-- capon_aoa.m
|-- pointcloud/
|   |-- gen_pointcloud_comprehensive_mpoint.m
|   |-- prefilter_human_roi.m
|   |-- cluster_dbscan_human.m
|   |-- build_voxel_confidence_map.m
|   |-- binary_integration_track.m
|   |-- sph2cart_points.m
|   |-- detections_to_point_cloud.m
|   |-- cluster_human_points.m
|   |-- extract_primary_human.m
|   `-- accumulate_stable_points.m
|-- vis/
|   |-- compute_visual_products.m
|   |-- show_rd_map.m
|   |-- show_micro_doppler_map.m
|   |-- show_point_cloud_frame.m
|   `-- show_stable_voxel_overlay.m
`-- utils/
    |-- range_bin_to_meters.m
    `-- doppler_bin_to_mps.m
```

## 当前主链路

`ADC 读取 -> IQ 重组 -> frame cube 重排 -> TDM-MIMO 去交织 -> comprehensive mPoint 动静融合点云 -> ROI 预筛选 -> DBSCAN 人体簇提取 -> voxel 稳点累计`

其中：
- 动态分支：`Range FFT -> MTI -> Doppler FFT -> RDI 候选 -> Capon/MVDR optimized RAI`
- 静态分支：`Range FFT -> direct RAI`
- 融合输出：`[x, y, z, v, snr, intensity, sourceFlag]`
- `sourceFlag = 1` 表示动态分支点
- `sourceFlag = 2` 表示静态补点点

## 主要文件说明

- `main_demo.m`
  主处理入口。输出每个文件、每一帧的融合点云、人体簇、稳点体素结果。
- `main_visual_demo.m`
  可视化入口。弹出 RD 图、微多普勒图、点云图。
- `config/mpoint_config.m`
  mPoint 动静融合点云配置。
- `pointcloud/gen_pointcloud_comprehensive_mpoint.m`
  comprehensive mPoint 风格动静融合点云主函数。
- `pointcloud/prefilter_human_roi.m`
  根据房间 ROI、z、range、snr 做预筛选。
- `pointcloud/cluster_dbscan_human.m`
  DBSCAN 聚类并结合几何规则与轨迹连续性选择主人体簇。
- `pointcloud/build_voxel_confidence_map.m`
  将最近 `W` 帧人体点云累计到 voxel 网格，输出置信度图与稳点。
- `pointcloud/binary_integration_track.m`
  根据滑窗命中次数判定稳定体素。
- `vis/show_stable_voxel_overlay.m`
  将当前帧人体点云与稳定体素画在一起。

## 运行方式

### 1. 单文件主流程

在 MATLAB 中运行：

```matlab
addpath(genpath('F:\2026\fall_project\mmwave_fall_matlab'));
results = main_demo('F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin');
```

运行后常用查看方式：

```matlab
r = results.file_results(1);
f = r.frames(50);

f.point_cloud.points
f.human_cloud.xyz
f.stable_cloud.xyz
```

### 2. 目录批处理

```matlab
addpath(genpath('F:\2026\fall_project\mmwave_fall_matlab'));
results = main_demo('F:\Data_bin\parlor\fall');
```

### 3. 可视化 RD 图、微多普勒图、点云图

```matlab
addpath(genpath('F:\2026\fall_project\mmwave_fall_matlab'));
visual_results = main_visual_demo('F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin');
```

说明：
- RD 图和微多普勒图默认使用 `parula`
- 默认忽略前 `6` 个近距离 range bin
- 当前默认开启“仅显示层归一化”，不改底层原始幅度数据

### 4. 查看稳定体素与当前帧人体点云

```matlab
addpath(genpath('F:\2026\fall_project\mmwave_fall_matlab'));
results = main_demo('F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin');

r = results.file_results(1);
frame_idx = 50;
show_stable_voxel_overlay(r.frames(frame_idx).human_cloud, ...
    r.frames(frame_idx).stable_cloud, ...
    sprintf('Frame %d Stable Voxels', frame_idx));
```

## 主要输出结构

### `results.file_results(k).frames(frame_idx)`

包含：
- `frame_id`
- `detection_list`
- `point_cloud`
- `filtered_cloud`
- `cluster_result`
- `human_cloud`
- `stable_cloud`
- `voxel_map`
- `mpoint_debug`

### `point_cloud`

关键字段：
- `point_cloud.points [N,7]`
- `point_cloud.xyz [N,3]`
- `point_cloud.v_mps [N,1]`
- `point_cloud.snr_db [N,1]`
- `point_cloud.intensity [N,1]`
- `point_cloud.source_flag [N,1]`

### `stable_cloud`

关键字段：
- `stable_cloud.xyz [K,3]`
- `stable_cloud.confidence [K,1]`
- `stable_cloud.hit_count [K,1]`
- `stable_cloud.num_valid_frames`

## 配置说明

### `config/mpoint_config.m`

主要字段：
- `min_range_m`, `max_range_m`
- `skip_near_range_bins`
- `dynamic_candidate_top_k`
- `dynamic_min_snr_db`
- `static_min_snr_db`
- `range_consistency_bins`
- `angle_consistency_deg`
- `snr_consistency_db`
- `static_max_points_per_anchor`

### `config/cluster_config.m`

主要字段：
- `room_roi_x_m`, `room_roi_y_m`, `room_roi_z_m`
- `range_gate_m`
- `min_snr_db`
- `dbscan_epsilon_m`
- `dbscan_min_points`
- `min_cluster_points`
- `valid_height_range_m`
- `valid_width_range_m`
- `valid_depth_range_m`
- `max_track_distance_m`

推荐初值：
- `eps = 0.32`
- `minPts = 6`

### `config/stable_config.m`

主要字段：
- `window_length_frames`
- `min_valid_frames`
- `voxel_size_m`
- `occ_threshold`
- `align_by_centroid`

推荐初值：
- `voxelSize = 0.08`
- `W = 8`
- `T_occ = 0.50`

### `config/visual_config.m`

主要字段：
- `default_bin_path`
- `range_roi_m`
- `skip_near_range_bins`
- `colormap_name`
- `enable_normalization`
- `normalization_method`
- `preferred_frame_index`
- `save_figures`

## 备注

- `compute_visual_products.m` 当前仍然用于生成 RD 图和微多普勒图的可视化中间量。
- `detections_to_point_cloud.m`、`cluster_human_points.m`、`extract_primary_human.m`、`accumulate_stable_points.m` 这些旧模块仍保留在工程中，方便你做对照实验，但主流程已经切到新的 mPoint + ROI/DBSCAN + voxel 稳点链路。
- 如果你后面要，我可以继续把 README 再补成“每个函数输入输出维度总表”版本。 
