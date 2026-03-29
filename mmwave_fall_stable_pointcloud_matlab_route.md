# 基于毫米波雷达跌倒监测的稳点人体点云技术路线（MATLAB 版）

## 1. 文档目标

本文档面向“**基于毫米波雷达的跌倒监测**”研究，目标不是泛泛总结论文，而是给出一条**可落地的 MATLAB 工程路线**：

- 从原始 ADC / radar cube 数据出发，生成**稳定的人体点云**；
- 将“稀疏、跳点、鬼点、多径污染”的毫米波点云处理为“**可用于跌倒检测**”的稳点人体点云序列；
- 给出适合 **MATLAB** 的模块划分、函数接口、伪代码、参数建议；
- 给出可直接复制给 **Claude Code** 的详细提示词，用于自动生成 MATLAB 项目骨架与各模块代码。

---

## 2. 论文结论压缩：对你的课题真正有用的是什么

### 2.1 Review 论文：点云本质不是人体表面，而是散射中心集合

《Scattering Centers to Point Clouds》指出，毫米波 radar point cloud 本质上是雷达散射中心的压缩表达，常见点属性包括：

- `x, y, z`
- `v`（Doppler / radial velocity）
- `I` 或 `peak_val`（强度）

这意味着：

1. 点云**天然稀疏**；
2. 点的位置**会抖动**，因为它不是连续表面采样；
3. 后续必须做**聚类、时序累积、稳定化**，否则直接做跌倒检测很容易误判；
4. 质心、均值、标准差、长宽高等几何统计量适合做姿态/跌倒特征。 

**结论**：你的系统核心不是“单帧点云多好看”，而是“**跨帧稳点人体点云**是否稳定”。

---

### 2.2 Comprehensive mPoint：不能只靠 MTI 动态点

《Comprehensive mPoint》最重要的工程启发是：

- 传统 TI-mPoint 主要利用 `Range FFT -> MTI -> MVDR -> RAI -> CFAR`；
- 这种方法更偏向“运动响应”，容易丢失静态人体表面信息；
- 作者提出把 **动态分支** 和 **静态反射分支** 融合：
  - 用 `RDI + MTI` 得到 optimized RAI，减少动态噪声；
  - 用 `Range FFT` 直接形成 direct RAI，保留静态反射细节；
  - 再把两个 RAI 融合成 combined RAI 生成 3D 点云。

论文实验结果说明，这种“动静融合”相对 TI-mPoint：

- 点数增加约 **86%**；
- 点云准确率提高约 **42%**；
- 运行时间只增加约 **1.6%**。

**对跌倒监测的意义**：

跌倒不是纯动态任务。真正危险的是“**快速下落后进入静止/半静止状态**”。如果前端只保留动态点，跌倒后人体会被严重稀释。因此，**前端必须保留静态人体表面反射**。

---

### 2.3 Zhang 2024：稳点要靠长时累积 + DBSCAN + binary integration + 多径抑制

《Millimeter-Wave Radar Detection and Localization of a Human in Indoor Complex Environments》给你的核心不是“静止人体检测”这四个字，而是它的**稳点方法论**：

- 先做 **averaging filter** 去静态噪声；
- `Range FFT + Doppler FFT` 获得 HRRP / RD；
- 用 **CFAR** 找可能目标；
- 用 **Capon** 求角度；
- 对点做 **DBSCAN**；
- 用 **binary integration** 在时间上累计目标是否持续存在；
- 再根据传播路径做 **multipath matching**，去掉鬼点/假目标。

论文说明：

- 静态人体 SNR 低，单帧难检；
- 时间累积和 DBSCAN 能把“同一位置反复出现的小幅波动点”保留下来；
- 多径点和真目标点可能都会聚成簇，所以 **仅靠 DBSCAN 不够**，还要做多径匹配抑制；
- 在五种复杂环境中平均定位误差在 **0.195 m** 以内。

**对你的课题的直接结论**：

“稳点人体点云”的关键不是只做滤波，而是：

> **单帧检测 + 时序存在性验证 + 空间聚类 + 多径几何排除**

这四步一起做。

---

### 2.4 mmParse：稀疏和镜面反射会导致人体部位缺失

《mmParse》指出，商用 IWR6843 这类毫米波雷达只有 `3×4` 天线，角分辨率有限，再加上雷达前端常用 **CFAR** 压缩成离散检测点，因此每帧人体反射通常只有几十个点量级，远低于视觉/LiDAR。与此同时，人体皮肤的**镜面反射**会导致某些身体部位在某些帧完全消失。

论文的工程启发：

- 不要把“某帧没看到某个部位”误当成“该部位不存在”；
- 要利用**时间序列上的互补性**；
- 需要从多帧累积中恢复更完整的人体结构；
- 语义信息（头、躯干、四肢）可以提升后续动作识别与姿态判断。

**对跌倒监测的意义**：

跌倒检测不能只看单帧高度或单帧质心，应该结合：

- 连续若干帧的人体簇高度变化；
- 点云主方向由竖直转为水平；
- 下落后低位静止时间；
- 稳点 voxel 的空间分布变化。

---

### 2.5 Wan 2024：CFAR 不该“一把尺子量所有区域”

《A Point Cloud Improvement Method for High-Resolution 4D mmWave Radar Imagery》提出 **dynamic CFAR**，核心思想是：

- 环境杂波往往不是均匀分布的；
- 不同扫描区域应采用**不同阈值**；
- 通过区域判别和动态门限来提高点云质量。

**对室内跌倒监测的意义**：

家庭环境常见：

- 地面近处强反射；
- 墙角/家具边缘反射增强；
- 窗帘、植物、床沿、桌椅附近点强烈波动。

所以 CFAR 建议不要全局固定阈值，而应至少做：

- **近距/中距/远距分段门限**；
- 或 **地面区域 / 非地面区域分段门限**；
- 或根据噪声底估计自适应更新门限。

---

### 2.6 mmDEAR：前端稳点之后，再做学习型增密

《mmDEAR》提出了两阶段框架：

1. **点云增强模块**：用时序特征和多阶段 completion 把稀疏点云增密；
2. **2D-3D 融合人体重建模块**：融合增强点云与原始点云，改善人体结构估计。

关键工程启发：

- 原始点云的 3D 空间位置是真实的；
- 增强点云提供更完整的形状信息；
- 训练时可以用图像 mask 监督；
- 推理时仍可只用毫米波点云。

**对你的课题的建议**：

先把 **传统 DSP 稳点链** 做稳，再考虑增密网络。因为如果前端点云本身多径严重、簇不稳定，网络只会学到脏分布。

---

## 3. 面向跌倒监测的最终 MATLAB 工程路线

我建议你把整个系统拆成两级：

### 一级：稳点人体点云生成（必须先做稳）

```text
Raw ADC / radar cube
-> 静态噪声抑制
-> Range FFT
-> Doppler FFT
-> 动态/分区 CFAR
-> AoA / Capon(MVDR)
-> 球坐标转笛卡尔点云
-> 动静融合点云生成
-> 人体簇提取(DBSCAN)
-> 滑窗稳点累计(binary integration + voxel confidence)
-> 多径/鬼点抑制
-> 单目标跟踪
-> Stable Human Point Cloud Sequence
```

### 二级：跌倒检测

```text
Stable Human Point Cloud Sequence
-> 质心/高度/长宽高/主方向/速度/加速度/地面接近特征
-> 时序判别(HMM / SVM / XGBoost / BiLSTM)
-> 跌倒告警
```

**优先级建议**：

- 硕士阶段先做“一级 + 传统机器学习二级”；
- 如果时间充足，再加 mmDEAR 风格的“学习型点云增强”。

---

## 4. MATLAB 版系统模块设计

## 4.1 推荐工程目录

```text
mmwave_fall_matlab/
├─ main_demo.m
├─ config/
│  ├─ radar_config.m
│  ├─ cfar_config.m
│  ├─ cluster_config.m
│  └─ fall_config.m
├─ io/
│  ├─ read_dca1000_bin.m
│  ├─ load_radar_cube.mat
│  └─ parse_ti_cfg.m
├─ dsp/
│  ├─ range_fft.m
│  ├─ doppler_fft.m
│  ├─ static_clutter_remove.m
│  ├─ dynamic_cfar_2d.m
│  ├─ cfar_ca_1d.m
│  ├─ cfar_os_2d.m
│  ├─ capon_aoa.m
│  ├─ angle_fft_aoa.m
│  ├─ sph2cart_points.m
│  └─ gen_pointcloud_comprehensive_mpoint.m
├─ pointcloud/
│  ├─ prefilter_human_roi.m
│  ├─ cluster_dbscan_human.m
│  ├─ build_voxel_confidence_map.m
│  ├─ binary_integration_track.m
│  ├─ suppress_multipath_geometry.m
│  ├─ merge_dynamic_static_points.m
│  ├─ track_human_kf.m
│  └─ export_pointcloud_sequence.m
├─ features/
│  ├─ extract_centroid_features.m
│  ├─ extract_bbox_features.m
│  ├─ extract_orientation_features.m
│  ├─ extract_floor_contact_features.m
│  └─ build_temporal_feature_window.m
├─ models/
│  ├─ train_svm_fall.m
│  ├─ train_xgboost_fall.m
│  ├─ train_bilstm_fall.m
│  └─ predict_fall_event.m
├─ vis/
│  ├─ show_rd_map.m
│  ├─ show_rai_map.m
│  ├─ show_pointcloud_frame.m
│  ├─ show_stable_voxel_map.m
│  └─ animate_fall_sequence.m
└─ docs/
   └─ experiment_log.md
```

---

## 4.2 推荐核心数据结构（MATLAB）

### 单帧原始点结构

```matlab
pt.x
pt.y
pt.z
pt.v
pt.snr
pt.intensity
pt.range
pt.azimuth
pt.elevation
pt.frame_id
```

### 单帧人体簇结构

```matlab
cluster.points          % NxD
cluster.centroid        % [x,y,z]
cluster.bbox            % [xmin xmax ymin ymax zmin zmax]
cluster.num_points
cluster.mean_snr
cluster.main_axis       % PCA主方向
cluster.is_static_like
cluster.is_valid_human
```

### 稳点体素结构

```matlab
stableVoxel.gridSize
stableVoxel.origin
stableVoxel.occCount    % 每个体素在滑窗内被命中的次数
stableVoxel.confidence  % occCount / windowLen
stableVoxel.points      % 输出稳点
```

### 跌倒事件结构

```matlab
event.startFrame
event.impactFrame
event.lowPostureFrame
event.recoverFrame
event.isFall
event.score
```

---

## 5. 一级：稳点人体点云生成的详细技术路线

## 5.1 输入层：原始 ADC / radar cube 读取

### 输入形式

你最可能遇到三种输入：

1. `DCA1000 .bin` 原始 ADC；
2. TI SDK 输出的 point cloud TLV；
3. 已离线保存的 `radarCube.mat`。

### MATLAB 建议

- 如果你要研究“前端怎么生成稳点”，优先使用 **原始 ADC / radar cube**；
- 不建议只用 SDK 已输出的 point cloud，因为很多稳点策略需要改 CFAR、AoA 和前端门限。

### 建议函数

```matlab
adc = read_dca1000_bin(filePath, cfg);
cube = reshape_adc_to_cube(adc, cfg);  % [numRx*numTx, numSamples, numChirps, numFrames]
```

---

## 5.2 静态噪声抑制

### 目标

去除：

- DC 分量
- 固定背景均值
- 慢变静态噪声

### 建议方法

**方案 A：均值相消**

```matlab
cube = cube - mean(cube, 3);   % chirp维或frame维
```

**方案 B：滑动背景建模**

```matlab
bg = alpha * bg_prev + (1-alpha) * cube;
cube_hp = cube - bg;
```

### 注意

跌倒监测不能把静态人体也一起滤掉，所以：

- 对“动态检测分支”可以强一点去背景；
- 对“静态补点分支”只做轻度背景抑制。

---

## 5.3 Range FFT

### 目标

把快时间维 IF 信号变成距离谱。

### MATLAB 模板

```matlab
function rangeCube = range_fft(cube, cfg)
    win = hann(cfg.numSamples, 'periodic');
    win = reshape(win, 1, [], 1, 1);
    cubeWin = cube .* win;
    rangeCube = fft(cubeWin, cfg.nfftRange, 2);
end
```

### 实践建议

- 先做 `hann/hamming`；
- 只保留正频率半轴；
- 输出每个 range bin 的复数值，后面 Doppler 和 AoA 还要用。

---

## 5.4 Doppler FFT

### 目标

从慢时间维得到速度信息。

### MATLAB 模板

```matlab
function rdCube = doppler_fft(rangeCube, cfg)
    win = hann(cfg.numChirps, 'periodic');
    win = reshape(win, 1, 1, [], 1);
    tmp = rangeCube .* win;
    rdCube = fftshift(fft(tmp, cfg.nfftDoppler, 3), 3);
end
```

### 工程要点

- 动态分支需要保留 Doppler；
- 静态分支中 `v≈0` 附近的点不能一刀切删除，因为跌倒后静止人体很关键。

---

## 5.5 CFAR：建议使用动态 / 分区 CFAR

### 为什么不能只用固定 CFAR

室内环境中：

- 近地面强反射大；
- 墙角和家具边缘反射强；
- 靠近植物、窗帘、床边时噪声底明显变化。

### 推荐做法

#### 方案 A：分区 CA-CFAR

按 range 划成：

- `0~1.2m`
- `1.2~2.5m`
- `2.5m+`

每段使用不同的：

- training cells
- guard cells
- scaling factor
- Pfa

#### 方案 B：2D dynamic CFAR

对每个局部 block 估计噪声底，再按区域动态调整阈值：

```matlab
thr = alpha(regionId) * localNoise + beta(regionId);
```

### MATLAB 建议接口

```matlab
[detMask, detList] = dynamic_cfar_2d(rdMap, cfarCfg);
```

### detList 建议字段

```matlab
[rbin, dbin, snr, noiseFloor, regionId]
```

---

## 5.6 AoA / Capon(MVDR)

### 为什么建议优先 Capon

- 角度分辨率通常优于简单 Angle FFT；
- 对相邻人体反射点分离更稳；
- 对室内复杂环境更适合。

### MATLAB 建议接口

```matlab
[azSpec, elSpec, azPeak, elPeak] = capon_aoa(snapshot, cfg);
```

### 实践策略

- 开发初期可先用 Angle FFT 跑通；
- 结果稳定后替换成 Capon。

---

## 5.7 结合 comprehensive mPoint 的“动静融合点云生成”

这是本工程最关键的一步。

### 动态分支

```text
Range FFT -> MTI -> Doppler FFT(RDI) -> MVDR/RAI -> optimized RAI
```

作用：

- 通过运动信息找到“真实人体大概在哪”；
- 抑制一部分背景与多径噪声。

### 静态分支

```text
Range FFT -> direct RAI (不经强MTI)
```

作用：

- 保留静止人体表面反射；
- 保住跌倒后人体仍然存在的静态点。

### 融合策略

1. 先用动态分支得到候选 range-angle 区域；
2. 再到 direct RAI 中提取该区域更细的静态反射；
3. 按 `range + snr + angle consistency` 对 azimuth / elevation 平面相关联；
4. 生成 3D 点。

### MATLAB 建议接口

```matlab
pcFrame = gen_pointcloud_comprehensive_mpoint(rangeCube, rdCube, cfg);
```

### 输出建议

```matlab
pcFrame = [x, y, z, v, snr, intensity, sourceFlag];
```

其中：

- `sourceFlag = 1` 表示动态分支点；
- `sourceFlag = 2` 表示静态补点分支点。

---

## 5.8 ROI 预筛选

### 为什么需要

跌倒监测一般是室内固定部署，人体活动区域可先验限定。

### 推荐筛选条件

```matlab
z in [-0.2, 2.2]
range in [0.3, 5.0]
y in room_width_range
x in room_depth_range
snr > snr_min
```

### 地面噪声处理

可加一条：

```matlab
if z < groundZ + margin && abs(v) < smallVel
    标记为可疑地面杂波
end
```

但不要直接删干净，因为跌倒后人体会接近地面。

---

## 5.9 单帧人体簇提取：DBSCAN

### 为什么选 DBSCAN

- 不需要先验簇数；
- 能把离群点自然当噪声；
- 很适合稀疏雷达点云。

### MATLAB 参考

MATLAB Statistics Toolbox 有 `dbscan` 可直接用。

```matlab
labels = dbscan(pcXYZ, eps, minPts);
```

### 参数建议（起点）

- `eps = 0.15 ~ 0.30 m`
- `minPts = 4 ~ 8`

### 单目标人体簇选择规则

从所有 cluster 里选：

- 点数最多；
- 质心落在人活动 ROI；
- 高度/宽度符合人体先验；
- 连续帧与历史轨迹距离最近。

### 接口建议

```matlab
humanCluster = cluster_dbscan_human(pcFrame, clusterCfg, trackState);
```

---

## 5.10 稳点生成：binary integration + voxel confidence

这是“稳点人体点云”的核心实现。

### 思路

不要把每一帧所有点都当可信点，而是做**时序投票**：

1. 把人体簇点云离散到 voxel 网格；
2. 统计每个 voxel 在最近 `W` 帧中被命中的次数；
3. 若 `occCount >= T_occ`，则判为稳点；
4. 输出这些稳点的中心或加权平均位置。

### 推荐参数

- `voxelSize = 0.05 ~ 0.10 m`
- `W = 8 ~ 12 frames`
- `T_occ = ceil(0.5 * W)` 到 `ceil(0.7 * W)`

### 为什么有效

- 真正的人体表面反射点会在相近空间反复出现；
- 多径鬼点位置往往漂；
- 随机杂波不会在同一 voxel 持续稳定命中。

### MATLAB 伪代码

```matlab
function stablePts = build_voxel_confidence_map(clusterSeq, cfg)
    % clusterSeq: 最近W帧的人体簇点
    occ = containers.Map();
    for t = 1:length(clusterSeq)
        pts = clusterSeq{t};
        vox = floor((pts(:,1:3) - cfg.origin) ./ cfg.voxelSize);
        vox = unique(vox, 'rows');
        for i = 1:size(vox,1)
            key = sprintf('%d_%d_%d', vox(i,1), vox(i,2), vox(i,3));
            if isKey(occ, key)
                occ(key) = occ(key) + 1;
            else
                occ(key) = 1;
            end
        end
    end

    stablePts = [];
    keysCell = keys(occ);
    for k = 1:numel(keysCell)
        if occ(keysCell{k}) >= cfg.T_occ
            idx = sscanf(keysCell{k}, '%d_%d_%d');
            p = cfg.origin + (idx(:)' + 0.5) * cfg.voxelSize;
            stablePts = [stablePts; p]; %#ok<AGROW>
        end
    end
end
```

### 建议升级

在 voxel confidence 上加权：

```text
confidence = a * 出现频次 + b * 平均SNR + c * 与历史轨迹一致性
```

---

## 5.11 多径 / 鬼点抑制

### 为什么必须做

单靠 DBSCAN 会把“真目标簇”和“稳定鬼点簇”都保留下来。

### 推荐做法

#### 方法 1：几何镜像排除

若已知：

- 墙面位置
- 大平面家具边界
- 雷达安装位姿

则对可疑点计算镜像点位置，若与某反射路径理论位置高度一致，则标记为鬼点。

#### 方法 2：动态一致性排除

如果某簇与主人体簇在：

- 高度变化趋势
- 速度变化趋势
- 质心移动方向

上长期不同步，则可作为伪簇排除。

#### 方法 3：主路径优先

对同一时刻的多个候选簇：

- 优先选择与上一帧轨迹最近的簇；
- 优先选择 SNR 更高、点数更多、空间形态更像人体的簇。

### MATLAB 接口建议

```matlab
pcClean = suppress_multipath_geometry(pcStable, roomModel, trackState, mpCfg);
```

---

## 5.12 单目标跟踪

### 作用

- 保持连续身份；
- 稳定人体中心轨迹；
- 支撑跌倒事件时序分析。

### 推荐方法

- 初版：常速度卡尔曼滤波（Kalman Filter）
- 后续：IMM / UKF

### 状态向量建议

```matlab
state = [x, y, z, vx, vy, vz]';
```

### 观测向量

```matlab
obs = [cx, cy, cz]';
```

### 接口建议

```matlab
trackState = track_human_kf(humanCluster.centroid, trackState, dt);
```

---

## 6. 二级：跌倒检测特征设计（基于稳点人体点云）

## 6.1 必做特征

### A. 质心高度下降特征

```text
centroid_z(t)
Δz/Δt
最大下降速度
impact前后高度差
```

### B. 包围盒形态特征

```text
height = zmax - zmin
width_x = xmax - xmin
width_y = ymax - ymin
height / max(width_x, width_y)
```

跌倒后常见现象：

- `height` 快速下降；
- 水平展宽增加；
- 纵向/横向比值明显下降。

### C. PCA 主方向特征

人体由站立变为躺倒时：

- 主轴从接近竖直，转为接近水平。

### D. 地面接近特征

```text
zmin 接近 ground plane
低位保持时长 > T_low
```

### E. 稳点保持特征

跌倒后若人体卧地静止：

- 低位 voxel 的稳定出现次数增加；
- 高位 voxel 快速消失。

---

## 6.2 推荐事件逻辑

```text
触发阶段:
    质心高度在短时间内快速下降
冲击阶段:
    下落速度或加速度达到峰值
落地阶段:
    zmin 接近地面
保持阶段:
    低位姿态维持超过 T_hold
输出:
    fall = true
```

### 初版规则式阈值

```matlab
if dz_dt < -VzThr && bboxHeight < Hthr && lowPoseDuration > Tthr
    fallFlag = true;
end
```

### 推荐第二版

提取滑窗特征后用：

- SVM
- XGBoost
- BiLSTM

---

## 7. MATLAB 实现顺序（最推荐）

## 第 1 阶段：先跑通单帧点云链

目标：

- 读入 ADC；
- 输出每帧点云；
- 可视化 RD map、RAI、3D 点云。

交付：

- `range_fft.m`
- `doppler_fft.m`
- `dynamic_cfar_2d.m`
- `capon_aoa.m`
- `show_pointcloud_frame.m`

---

## 第 2 阶段：实现动静融合点云

目标：

- 复现 comprehensive mPoint 的核心思路；
- 输出比纯 MTI 更完整的人体点云。

交付：

- `gen_pointcloud_comprehensive_mpoint.m`
- `merge_dynamic_static_points.m`

---

## 第 3 阶段：实现人体簇 + 稳点

目标：

- DBSCAN 提人；
- 滑窗体素累计；
- binary integration；
- 输出 stable point cloud。

交付：

- `cluster_dbscan_human.m`
- `build_voxel_confidence_map.m`
- `binary_integration_track.m`

---

## 第 4 阶段：实现多径抑制 + 跟踪

目标：

- 去掉镜像簇；
- 输出稳定人体轨迹。

交付：

- `suppress_multipath_geometry.m`
- `track_human_kf.m`

---

## 第 5 阶段：做跌倒检测

目标：

- 从 stable point cloud 提取时序特征；
- 训练分类器；
- 输出 fall/no-fall。

交付：

- `extract_*_features.m`
- `train_svm_fall.m`
- `predict_fall_event.m`

---

## 第 6 阶段：再尝试学习型增密

目标：

- 在稳点链路可用之后，尝试 mmDEAR 风格增强。

建议：

- 前端仍然保留 MATLAB DSP；
- 增密网络单独用 Python/PyTorch；
- 增强结果再回 MATLAB 做跌倒识别对比实验。

---

## 8. 推荐实验指标

## 8.1 前端点云指标

- 平均每帧人体点数
- 稳点比例
- 质心抖动标准差
- 包围盒抖动标准差
- 人体簇连续跟踪率
- 鬼点误检率

## 8.2 跌倒检测指标

- Accuracy
- Precision
- Recall
- F1
- Specificity
- False Alarm Rate
- Detection Delay

## 8.3 最值得你写进论文的指标

建议重点报告：

1. **稳定点占比提升**；
2. **跌倒后卧地阶段的人体保留率**；
3. **多径环境下误检簇下降比例**；
4. **跌倒检测 F1 与误报率**。

---

## 9. MATLAB 版最小可行原型（MVP）

如果你想最快出结果，建议只做下面这条最短链：

```text
ADC
-> Range FFT
-> Doppler FFT
-> 分区CFAR
-> Capon
-> 点云生成
-> ROI筛选
-> DBSCAN提人
-> 10帧voxel累计稳点
-> 质心高度 + 包围盒高度 + 低位保持
-> SVM跌倒检测
```

这条链已经足够形成：

- 一个可复现实验系统；
- 一篇硕士论文的主实验；
- 后续再加入多径抑制和增密网络做提升实验。

---

## 10. Claude Code 详细提示词（MATLAB 版）

下面给你的是可以**直接复制给 Claude Code** 的提示词，按阶段执行。

---

## Prompt 1：创建整个 MATLAB 项目骨架

```text
你现在是资深毫米波雷达算法工程师和 MATLAB 架构工程师。
请为我创建一个完整的 MATLAB 项目，项目名称为 mmwave_fall_matlab。
项目目标：基于 FMCW MIMO 毫米波雷达原始 ADC / radar cube 数据，完成稳点人体点云生成，并用于跌倒检测。

请直接输出：
1. 完整的项目目录树；
2. 每个 .m 文件的用途说明；
3. main_demo.m 的主流程；
4. 所有 config 文件的字段定义；
5. 每个函数输入输出的数据结构。

要求：
- 不要写成 Python；必须写成 MATLAB。
- 所有函数命名采用 snake_case 风格。
- 所有函数都给出 MATLAB function 签名。
- 数据流必须覆盖：ADC读取 -> Range FFT -> Doppler FFT -> CFAR -> AoA -> 点云生成 -> DBSCAN聚类 -> 稳点voxel累计 -> 跌倒特征提取 -> 分类。
- 输出要工程化，可直接据此建项目。
```

---

## Prompt 2：生成前端 DSP 主链 MATLAB 代码

```text
你现在继续为项目 mmwave_fall_matlab 编写 MATLAB 代码。
请一次性输出以下函数的完整 MATLAB 实现，要求每个函数都可独立保存为 .m 文件：

1. range_fft.m
2. doppler_fft.m
3. static_clutter_remove.m
4. dynamic_cfar_2d.m
5. capon_aoa.m
6. sph2cart_points.m

背景要求：
- 输入数据是 FMCW MIMO radar cube。
- range_fft 在快时间维做窗函数和 FFT。
- doppler_fft 在慢时间维做窗函数和 fftshift。
- dynamic_cfar_2d 不能是固定阈值版本，而要支持分区动态门限。
- capon_aoa 输出方位角、俯仰角谱和峰值位置。
- sph2cart_points 把 range、azimuth、elevation 转为 x,y,z。

代码要求：
- 全部使用 MATLAB 语法。
- 每个函数都写清楚输入、输出、维度说明。
- 每个关键步骤加中文注释。
- 不能只给伪代码，必须给可运行的 MATLAB 代码。
- 如果某一步需要简化，请明确说明简化假设。
```

---

## Prompt 3：生成 comprehensive mPoint 风格的动静融合点云模块

```text
请为 MATLAB 项目 mmwave_fall_matlab 编写函数 gen_pointcloud_comprehensive_mpoint.m。

目标：复现“动态分支 + 静态分支融合”的思路，用于生成人体更完整、更稳定的 3D 点云。

请严格按下面流程实现：
1. 对 radar cube 做 Range FFT。
2. 动态分支：
   - 对 Range FFT 结果做 MTI；
   - 再做 Doppler FFT 形成 RDI；
   - 基于 RDI 进行目标候选筛选；
   - 通过 MVDR / Capon 形成 optimized RAI。
3. 静态分支：
   - 从 Range FFT 结果直接形成 direct RAI；
   - 不使用强运动抑制，保留静态人体表面反射。
4. 融合：
   - 用动态分支定位目标 range-angle 候选区域；
   - 再在 direct RAI 中提取更细致的静态反射；
   - 通过 range 一致性、SNR 一致性、角度邻域一致性融合 azimuth 与 elevation 点；
   - 输出 3D 点云 [x, y, z, v, snr, intensity, sourceFlag]。

要求：
- 必须给完整 MATLAB 代码；
- 不能写成论文描述，要写成工程实现；
- 给出必要的子函数；
- 给出 main_demo.m 中的调用示例；
- sourceFlag 中 1 表示动态分支点，2 表示静态补点点；
- 在注释中解释为什么该模块适合跌倒后静态人体保留。
```

---

## Prompt 4：生成 DBSCAN 人体提取与稳点 voxel 模块

```text
继续为 MATLAB 项目 mmwave_fall_matlab 编写代码。
请输出以下 4 个 MATLAB 文件的完整实现：

1. prefilter_human_roi.m
2. cluster_dbscan_human.m
3. build_voxel_confidence_map.m
4. binary_integration_track.m

功能要求：
- prefilter_human_roi：根据房间 ROI、z 高度、range、snr 去除明显非人体点；
- cluster_dbscan_human：对点云做 DBSCAN，并根据点数、包围盒尺寸、与历史轨迹距离等规则选出人体簇；
- build_voxel_confidence_map：把最近 W 帧人体簇点云累计到 voxel 网格中，输出置信度图和稳点；
- binary_integration_track：根据体素在滑窗中的命中次数判断该体素是否为稳点。

实现要求：
- 代码必须是 MATLAB；
- voxelSize、windowLen、occThreshold 都从 cfg 中读取；
- 输出的人体稳点要适合后续跌倒检测；
- 给出一个可视化函数示例，把稳定体素和当前帧点云画在一起；
- 给出调参建议，例如 eps、minPts、voxelSize、W、T_occ 的推荐初值。
```

---

## Prompt 5：生成多径抑制与跟踪模块

```text
请继续为 MATLAB 项目 mmwave_fall_matlab 编写多径抑制和跟踪模块。
输出以下 MATLAB 文件：

1. suppress_multipath_geometry.m
2. track_human_kf.m
3. select_primary_human_cluster.m

目标：
- suppress_multipath_geometry：根据房间中的墙面、家具大平面、镜像关系和历史轨迹，去除可能的鬼点簇；
- track_human_kf：使用常速度 Kalman Filter 跟踪人体质心；
- select_primary_human_cluster：在多个候选簇中选出最可能的人体主簇。

要求：
- 用 MATLAB 实现；
- roomModel 中包含墙面、地面、家具平面参数；
- 给出镜像点判别逻辑；
- 给出轨迹关联代价函数，例如 距离 + 速度一致性 + 点数权重 + 平均SNR权重；
- 所有代码必须可读、可改、可扩展。
```

---

## Prompt 6：生成跌倒特征提取与分类模块

```text
请继续为 MATLAB 项目 mmwave_fall_matlab 编写跌倒检测模块。
输出以下 MATLAB 文件：

1. extract_centroid_features.m
2. extract_bbox_features.m
3. extract_orientation_features.m
4. extract_floor_contact_features.m
5. build_temporal_feature_window.m
6. train_svm_fall.m
7. predict_fall_event.m

任务目标：
- 基于稳点人体点云序列完成跌倒检测；
- 特征覆盖：质心高度下降、速度变化、包围盒高度、宽高比、PCA 主方向、最低点接近地面、低位保持时间；
- 输出 fall / non-fall 和置信分数。

要求：
- 用 MATLAB 实现；
- 训练模块先采用 SVM；
- predict_fall_event.m 要支持规则阈值模式和模型推理模式；
- 给出一个 demo，演示如何从 stable point cloud sequence 提取特征并做分类；
- 给出混淆矩阵、precision、recall、F1 的评估代码。
```

---

## Prompt 7：让 Claude Code 做一次完整重构

```text
现在请你作为毫米波雷达 MATLAB 项目的代码审查专家，对整个 mmwave_fall_matlab 项目进行一次重构建议。

请完成以下内容：
1. 检查所有函数的输入输出是否一致；
2. 检查变量命名是否统一；
3. 检查哪些函数应该拆分；
4. 检查哪些配置项应该集中到 config；
5. 给出性能瓶颈分析；
6. 指出哪些 for 循环可以向量化；
7. 给出 parfor、gpuArray、MATLAB Coder 的可优化位置；
8. 生成一份 REFACTOR_TODO.md。

要求：
- 只从 MATLAB 工程化角度出发；
- 不要泛泛而谈；
- 直接给可执行的重构任务列表。
```

---

## 11. 我对你最推荐的落地策略

如果你现在就要开始做，最优顺序只有一句话：

> **先用 MATLAB 把“动静融合 + DBSCAN + voxel稳点 + 低位保持跌倒判别”跑通，再决定是否接 mmDEAR 类网络。**

这条路线最符合你的研究目标，也最容易产出：

- 可视化结果；
- 论文实验表；
- 中期答辩代码；
- 后续可扩展深度学习版本。

---

## 12. 最后给你的简化版一句话路线

```text
Range FFT -> Doppler FFT -> 分区CFAR -> Capon -> 动静融合点云 -> DBSCAN提人 -> 滑窗voxel稳点 -> 多径抑制 -> 时序特征 -> 跌倒检测
```

这就是这批论文对你课题最有价值的 MATLAB 工程主线。
