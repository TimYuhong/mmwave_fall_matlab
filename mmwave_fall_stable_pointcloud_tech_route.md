# 基于毫米波雷达跌倒监测的“稳点”人体点云生成：论文总结 + 工程技术路线 + Claude Code 提示词

## 0. 结论先行

如果你的目标是**为跌倒监测提取稳定、可持续、可用于后续建模的人体点云**，最值得落地的不是单独照搬某一篇论文，而是把 6 篇文章组合成一条**双分支 + 时序稳态融合**路线：

- **底层DSP主线**：`Range FFT -> Doppler FFT -> 自适应/动态CFAR -> DOA估计 -> 笛卡尔点云`
- **稳点增强关键**：不要只用 MTI/纯动态点云；应采用**静态分支 + 动态分支融合**，保留跌倒后“躺地静止”的人体散射点
- **时序稳点关键**：`DBSCAN/轨迹关联 + 滑窗累积 + 二值积分/出现率投票 + 多径抑制`
- **点云稠密化关键**：在稳定点云已经可用后，再叠加 `PointNet++/GRU/补全网络` 做增强；训练可借助图像/人体掩码，推理阶段只用雷达
- **面向跌倒监测**：输出不应只是单帧点，而应是**“人体主体稳定点云序列 + 质心轨迹 + 高度/姿态统计 + 置信度”**

---

## 1. 六篇论文对你的直接价值

## 1.1 Review：从散射中心到点云的标准处理链
**文献**：Mafukidze et al., *Scattering Centers to Point Clouds: A Review of mmWave Radars for Non-Radar-Engineers*.

### 你需要拿走的内容
1. 标准毫米波点云生成链路：
   - ADC/IQ 原始数据
   - Range FFT
   - Doppler FFT
   - CFAR 检测
   - 角度估计（azimuth/elevation）
   - 球坐标转笛卡尔坐标
   - 输出点特征：`x, y, z, v, intensity/peak`

2. 点云本质：
   - mmWave 点云是散射中心的压缩表达，不是连续表面；
   - 每帧点少、稀疏、强依赖视角与反射机制；
   - 后续所有“稳点”工作都必须围绕**稀疏、闪烁、散射不稳定**这三个问题来做。

3. 常见点云后处理：
   - range gating
   - clustering（尤其 DBSCAN）
   - 体素化/投影
   - 几何与统计特征提取

### 对跌倒监测的启发
这篇文献给你的不是新算法，而是**总框架边界**：你后面不论做稳点、骨架、跌倒分类，本质都建立在“CFAR检出的散射点 + 时序处理”上。

---

## 1.2 Zhang 2021：为什么不能只保留动态点
**文献**：Zhang et al., 2021, *Comprehensive mPoint*.

### 核心思想
作者指出 TI-mPoint 这类流程偏向使用 MTI / 动态目标信息，能把人从背景中分出来，但会带来两个问题：

1. **多径噪声点多**
2. **只能突出“动”的反射，不保留真实人体静态散射结构**

所以他们提出**comprehensive mPoint**：
- 一条分支：从 `MTI -> MVDR -> RAI` 得到更干净的动态目标区域
- 另一条分支：从 `Range FFT 直接得到 direct RAI`
- 再把两者结合成 `combined RAI`
- 最后同时取方位与俯仰信息生成 3D 点云

### 你应该怎么用
对**跌倒监测**，这篇论文非常关键，因为：
- **跌倒前**：人体快速运动，动态分支有用
- **跌倒瞬间**：多普勒显著，动态分支有用
- **跌倒后**：人体可能躺倒并趋于静止，**只用 MTI 会把人削弱甚至抹掉**

### 直接可落地的工程结论
你应该做**双分支稳点提取**：
- **动态分支**：用于找人、抑制背景
- **静态/直达分支**：用于保留跌倒后的主体散射结构
- **融合原则**：动态分支给 ROI，静态分支给真实形状

---

## 1.3 Wan 2024：动态CFAR而不是一刀切阈值
**文献**：Wan et al., 2024, *A Point Cloud Improvement Method for High-Resolution 4D mmWave Radar Imagery*.

### 核心思想
作者从 4D 成像质量角度提出：
- 天线/阵列设计提升点云质量
- 更重要的是**dynamic CFAR**
- 不是全图一个阈值，而是**按扫描区域、杂波分布、自适应地调节检测门限**

### 你应该怎么用
跌倒监测常见问题：
- 近距离地面反射强
- 床/桌/墙角固定杂波强
- 人体远离雷达时 SNR 降低
- 跌倒后低高度区域容易和地杂波混淆

所以你的 CFAR 不要只写一个固定阈值，而要做**区域自适应**：

### 推荐做法
把 Range-Azimuth 或 Range-Doppler 空间划成 3 类区域：
1. **近距强杂波区**
2. **人体活动主区**
3. **远距低SNR区**

对不同区域分别设置：
- 训练单元数
- 保护单元数
- 偏置系数
- 最低检测门限

### 直接价值
这个思路对“稳点”非常重要，因为**大量点云抖动根源不是聚类，而是前面检测门限不稳定**。

---

## 1.4 Xing 2024：时序累积 + DBSCAN + 二值积分 + 多径匹配
**文献**：Xing et al., 2024, *Millimeter-Wave Radar Detection and Localization of a Human in Indoor Complex Environments*.

### 核心思想
作者不是做人体形状恢复，而是做复杂室内环境下的人体检测定位。对你最有价值的有四个模块：

1. **平均滤波去静态噪声**
2. `Range/Doppler FFT + CFAR + Capon`
3. **DBSCAN 长时累积聚类**
4. **binary integration（二值积分）**
5. **基于传播路径匹配的多径假目标剔除**

### 你应该怎么用
这篇论文本质上回答了：  
**“如何把偶发闪烁点变成稳定人体点簇？”**

### 推荐落地方式
- 每帧先聚类：得到候选人体簇
- 对候选簇做跨帧关联：质心、速度、框尺寸联合匹配
- 在滑窗内做体素占据统计：
  - 某体素在窗口内出现比例 `>= tau_occ` 才保留
  - 否则视为随机闪烁点
- 对镜像位置、墙反射路径做几何排除

### 对跌倒监测的直接价值
这是你做“稳点人体点云”的**最重要传统DSP基座**。  
如果不做时序累积与二值积分，你拿到的大概率是“跳点云”，不是“稳点云”。

---

## 1.5 Wang 2023（mmParse）：时空特征融合解决稀疏和镜面反射
**文献**：Wang et al., 2023, *Human Parsing with Joint Learning for Dynamic mmWave Radar Point Cloud*.

### 核心思想
作者指出两大根因：
1. **稀疏**
2. **specular reflection（镜面反射）导致身体部分缺失**

对应方案：
- 以 `PointNet` 为骨干
- 使用**多任务学习**：主任务做人体彩点语义解析，辅任务做人姿态估计
- 使用**时空全局特征融合/非局部注意力**
- 通过时序信息补齐局部帧中缺失的身体部位理解

### 你应该怎么用
你做跌倒监测，不一定非要做人体彩点语义分割，但这篇论文告诉你：

> 单帧点云不可靠，必须利用时间序列来稳定“人体结构理解”。

### 落地转译
即便你不训练 mmParse 全模型，也建议在工程上引入：
- 滑窗时序点云堆叠
- 主体结构辅助任务（如关键点/身高中心线/躯干轴估计）
- 基于时序的特征提取器（GRU/Transformer/Temporal Conv）

### 直接价值
这篇文章给你的是**深度学习层面的稳点逻辑**：  
**稳定的不是点本身，而是“人体结构解释”**。

---

## 1.6 Yang 2025（mmDEAR）：先增密，再重建
**文献**：Yang et al., 2025, *mmDEAR: mmWave Point Cloud Density Enhancement for Accurate Human Body Reconstruction*.

### 核心思想
提出两阶段框架：
1. **点云增强模块**
   - PointNet++
   - 双向 GRU 做时序特征抽取
   - seed 生成
   - 多阶段补全/细化
   - 训练期用图像人体 mask 做监督
   - 推理期只用雷达点云
2. **2D-3D aware body reconstruction**
   - 同时利用原始点云和增强点云

### 你应该怎么用
如果你的最终目标是**跌倒监测而非人体重建**，不要一开始就上全量 mmDEAR。  
正确顺序应该是：

- 第一步：先把**DSP稳点人体点云**做扎实
- 第二步：若点太稀，再上**轻量级增密网络**
- 第三步：用增强点云给跌倒识别模型提供更稳定输入

### 直接价值
这篇论文告诉你：
- **增密必须依赖时序**
- **增强网络训练可以借助图像监督**
- **但部署时可以只保留雷达输入**

这非常适合你后续做论文：  
训练阶段多模态，部署阶段纯毫米波。

---

## 2. 面向跌倒监测的最终工程路线（推荐你直接照这个做）

## 2.1 总体目标
输入：
- FMCW/TDM-MIMO 毫米波雷达 ADC/IQ 原始数据或雷达板输出的 radar cube

输出：
- `stable_human_point_cloud_t`
- `track_id`
- `centroid / bbox / body_height / body_spread / radial_velocity_stats`
- `fall_features`
- 可选：`enhanced_point_cloud_t`

---

## 2.2 一级方案：必须先做出来的 MVP（只用传统DSP+时序）
这是最值得你先完成的版本。

### Stage A. 数据读取与标定
1. 读取 ADC/IQ 原始数据
2. 解析配置：
   - sample rate
   - slope
   - chirp 数
   - Tx/Rx 数
   - frame period
3. 做天线通道幅相校准
4. 建立坐标系：
   - x：横向
   - y：深度/距离
   - z：高度
5. 做地面/雷达安装位姿标定

### Stage B. 基础 DSP 点检测
1. 每个 chirp 做 Range FFT
2. 跨 chirp 做 Doppler FFT
3. 得到 RDM / RA cube
4. 做 **区域自适应 CFAR**
   - 近距离区域高阈值
   - 中距离人体主活动区常规阈值
   - 远距离低SNR区低阈值+后验约束
5. 角度估计：
   - 资源够：Capon / MVDR
   - 实时要求高：Angle FFT
6. 球坐标转笛卡尔坐标
7. 输出点特征：
   - `x,y,z`
   - `v`
   - `snr`
   - `intensity/peak`
   - `range_bin,doppler_bin,az_bin,el_bin`

### Stage C. 双分支点云融合（稳点关键）
**分两条支路同时跑：**

#### 分支 1：动态分支
- `Range FFT -> MTI / Doppler -> CFAR -> DOA`
- 用途：快速定位活动人体，剔除背景

#### 分支 2：静态/直达分支
- `Range FFT -> direct RAI/angle estimation -> CFAR -> DOA`
- 不做强 MTI
- 用途：保留真实静态散射结构，特别是跌倒后躺地人体

#### 融合规则
- 用动态分支生成 ROI
- 在 ROI 内，从静态分支补点
- 对重复点按空间邻近 + SNR 合并
- 保留 `source_flag = dynamic/static/fused`

> 这是你生成“稳点人体点云”的第一关键模块。

### Stage D. 主体聚类与时序关联
1. 单帧用 DBSCAN 聚类
2. 过滤条件：
   - 点数下限
   - 合理人体高度范围
   - 合理横向/纵向尺度范围
3. 多帧跟踪：
   - 用卡尔曼滤波或匈牙利匹配
   - 匹配特征：质心距离 + 速度 + 高度 + bbox
4. 只保留稳定 track

### Stage E. 滑窗稳点生成
对每个 track，在长度 `W` 的滑窗内做：

1. 轨迹对齐（按质心或骨盆近似中心平移对齐）
2. 体素化（建议 5cm 或 7.5cm）
3. 统计每个体素的占据率
4. 保留出现率高的体素
5. 对低出现率、跳变体素做抑制
6. 输出：
   - `stable voxel cloud`
   - 再反投影成 `stable point cloud`

### Stage F. 多径与地杂波抑制
1. 地面高度阈值过滤
2. 墙面镜像几何排除
3. 对固定反射强点建立背景地图
4. 对不符合人体轨迹连续性的簇做删除
5. 对“突然出现但无时序连续性”的点做拒绝

### Stage G. 面向跌倒监测的特征输出
不要只输出点云，还要同步输出：
- 质心高度随时间曲线
- bbox 高宽比
- z 向离散度
- 速度峰值
- 落地后静止时长
- 地面附近点占比
- 躯干主方向（可由 PCA 求）

---

## 2.3 二级方案：在 MVP 上叠加“轻量增密”
当你发现点云稳定了，但仍然太稀，可以继续：

### Stage H. 轻量增密网络
输入：
- `W` 帧对齐后的稳定人体点云序列

网络推荐：
- `PointNet++ encoder + BiGRU + coarse-to-fine completion head`

监督可选：
1. 最优：雷达-相机同步，用 2D mask / pseudo depth 做监督
2. 次优：用动作捕捉或人体网格的投影监督
3. 无图像场景：用跨帧一致性 + 形状先验约束

推理时：
- 只用雷达点云

### 增密后的用途
- 提升跌倒后躺地人体轮廓稳定性
- 给姿态估计/动作分类提供更完整输入
- 作为论文创新点：`stable cloud + densified cloud` 双输入

---

## 2.4 三级方案：结构先验增强
如果你要继续发论文，可以上这一层。

### Stage I. 结构辅助任务
参考 mmParse 思路，加一个辅助分支：
- 人体关键点回归
- 或人体部位分类
- 或躯干轴 + 四肢端点估计

主任务仍是：
- 稳点人体点云提取 / 跌倒检测

辅助任务的作用：
- 让网络学到人体结构
- 减少镜面反射造成的局部缺失影响
- 提高跌倒后“躺倒姿态”的解释稳定性

---

## 3. 我建议你的代码仓库结构

```text
mmwave_fall_stablecloud/
├── configs/
│   ├── radar_iwr6843.yaml
│   ├── dsp_default.yaml
│   ├── tracker.yaml
│   ├── densify.yaml
│   └── fall.yaml
├── data/
│   ├── raw_adc/
│   ├── radar_cube/
│   ├── labels/
│   └── calibration/
├── src/
│   ├── io/
│   │   ├── adc_reader.py
│   │   ├── cfg_parser.py
│   │   └── calib_loader.py
│   ├── dsp/
│   │   ├── range_fft.py
│   │   ├── doppler_fft.py
│   │   ├── static_clutter.py
│   │   ├── dynamic_cfar.py
│   │   ├── doa_mvdr.py
│   │   ├── doa_capon.py
│   │   ├── cartesian.py
│   │   └── dual_branch_fusion.py
│   ├── postproc/
│   │   ├── dbscan_cluster.py
│   │   ├── multipath_filter.py
│   │   ├── track_kalman.py
│   │   ├── voxel_stabilizer.py
│   │   └── background_map.py
│   ├── models/
│   │   ├── pointnet2_encoder.py
│   │   ├── temporal_gru.py
│   │   ├── completion_head.py
│   │   ├── parsing_aux_head.py
│   │   └── fall_net.py
│   ├── features/
│   │   ├── body_stats.py
│   │   ├── pca_axis.py
│   │   └── fall_features.py
│   ├── train/
│   │   ├── train_densify.py
│   │   ├── train_fall.py
│   │   └── losses.py
│   └── eval/
│       ├── eval_detection.py
│       ├── eval_stability.py
│       ├── eval_densify.py
│       └── eval_fall.py
├── scripts/
│   ├── run_dsp_pipeline.py
│   ├── build_stable_cloud_dataset.py
│   ├── train_densify.sh
│   └── train_fall.sh
└── README.md
```

---

## 4. “稳点人体点云”评价指标（你论文里一定要写）

## 4.1 点云稳定性指标
1. **Centroid Jitter**
   - 同一静止人体在连续帧的质心抖动标准差
2. **Voxel Occupancy Consistency**
   - 滑窗内稳定体素占比
3. **Track Continuity**
   - 连续跟踪成功率
4. **False Stable Point Rate**
   - 被保留下来的伪稳定点比例
5. **Human Point Retention**
   - 真实人体点保留率

## 4.2 跌倒监测相关指标
1. 跌倒检测 F1 / Recall / Precision
2. 跌倒起始时刻误差
3. 跌倒后静止状态识别准确率
4. 躺地人体保持检测率

## 4.3 若加入增密网络
1. Chamfer Distance
2. EMD（可选）
3. 关键点误差
4. 下游跌倒识别增益

---

## 5. 推荐实验顺序（非常重要）

### Step 1
先实现：
- Range FFT
- Doppler FFT
- CFAR
- Capon/MVDR
- Cartesian 点云输出

### Step 2
实现：
- DBSCAN
- track association
- voxel occupancy stabilizer

### Step 3
实现：
- dual-branch fusion（动态分支 + 静态分支）

### Step 4
做 ablation：
- 只有动态分支
- 只有静态分支
- 双分支融合
- 双分支 + 滑窗稳点

### Step 5
再决定是否加：
- PointNet++ + GRU densify module

> 顺序不要反。  
> 否则你会陷入“深度网络在修补前端DSP错误”的泥潭。

---

## 6. 可直接复制给 Claude Code 的详细提示词

下面给你的是**可直接复制**的提示词。建议按顺序执行。

---

## Prompt 1：先搭完整工程骨架

```text
你现在是我的高级算法工程师和Python项目架构师。请为一个“基于毫米波雷达的跌倒监测稳点人体点云生成”项目搭建完整代码仓库。

项目目标：
1. 输入 FMCW/TDM-MIMO 毫米波雷达原始 ADC/IQ 数据或 radar cube。
2. 实现基础DSP流程：Range FFT、Doppler FFT、CFAR、DOA估计、笛卡尔点云生成。
3. 实现双分支点云生成：
   - 动态分支：用于抑制背景、快速定位人体。
   - 静态/直达分支：用于保留跌倒后趋于静止的人体散射点。
4. 实现时序稳点模块：
   - DBSCAN聚类
   - 多帧轨迹关联
   - 滑窗体素占据统计
   - 二值积分/出现率投票
5. 输出 stable human point cloud sequence，并为后续跌倒检测预留接口。
6. 代码必须工程化、可运行、模块清晰、可扩展到深度学习增密网络。

技术要求：
- Python 3.10+
- 使用 numpy / scipy / scikit-learn / matplotlib / pyyaml
- 深度学习部分预留 PyTorch 接口，但第一阶段先不要写复杂训练逻辑
- 所有模块都要带类型注解
- 所有核心函数都写 docstring
- 所有可调参数统一走 yaml 配置
- 给出完整目录结构、关键文件内容、README、main 入口脚本

请直接输出：
1. 项目目录树
2. 每个核心模块的职责
3. 所有关键 Python 文件的初版实现代码
4. 一个可运行的最小 demo（允许用模拟数据）
5. README 中写清运行命令
不要只给伪代码，要给能继续开发的真实代码骨架。
```

---

## Prompt 2：实现 DSP 主链路

```text
基于当前仓库，请你继续实现毫米波雷达点云生成的 DSP 主链路，要求直接写可运行代码，不要只写解释。

必须实现以下模块：
1. range_fft.py
   - 支持窗函数
   - 支持复数IQ输入
   - 输出 range profile / range cube
2. doppler_fft.py
   - 沿 chirp 维做 Doppler FFT
   - 输出 range-doppler map
3. dynamic_cfar.py
   - 实现可配置的 CA-CFAR 或 OS-CFAR
   - 支持按 range zone 使用不同阈值参数
   - 能输出检测点索引、门限值、SNR
4. doa_capon.py / doa_mvdr.py
   - 对检测到的目标做角度估计
   - 输出 azimuth / elevation
5. cartesian.py
   - 把 range、azimuth、elevation 转成 x,y,z
   - 保留 doppler、snr、intensity 等字段

实现要求：
- 每个模块有单元测试或最小自检代码
- 尽量使用向量化实现
- 所有输入输出 shape 写清楚
- 用 dataclass 定义点云点结构或 numpy structured array
- 给 scripts/run_dsp_pipeline.py 增加串联调用逻辑
- 用模拟 radar cube 生成一份示例输出点云

请输出修改后的完整代码，而不是摘要。
```

---

## Prompt 3：实现“双分支稳点点云生成”

```text
继续在现有仓库中实现“双分支稳点人体点云生成”模块，目标是避免只使用 MTI 导致跌倒后静止人体点云丢失。

我要的设计如下：
A. 动态分支
- 输入 radar cube
- 经过背景抑制/动态增强后，完成检测、角度估计、点云生成
- 更偏向突出运动人体

B. 静态/直达分支
- 尽量少做强 MTI
- 直接从 Range FFT / angle estimation 保留静态散射结构
- 输出更完整但噪声更大的候选点云

C. 融合模块 dual_branch_fusion.py
- 先用动态分支给出 ROI
- 再从静态分支中在 ROI 附近补点
- 对重复点按空间距离和SNR融合
- 给每个点打 source_flag（dynamic/static/fused）
- 输出最终 fused stable candidate cloud

实现要求：
1. 给出清晰的数据结构定义
2. 写成可插拔模块，便于后续 ablation
3. 代码中加入必要的日志输出
4. 给一个模拟案例，展示：
   - 只有动态分支
   - 只有静态分支
   - 双分支融合
   三者点数、SNR、空间覆盖范围的对比
5. README 增加本模块使用说明

请直接输出新增和修改后的完整代码。
```

---

## Prompt 4：实现“时序稳点”模块

```text
继续开发。现在实现 stable human point cloud 的时序稳态模块。

目标：
把单帧跳动的人体点云，变成跨帧连续、抖动更小、伪点更少的 stable human point cloud sequence。

需要实现的模块：
1. dbscan_cluster.py
   - 对单帧点云做聚类
   - 过滤离群点
2. track_kalman.py
   - 对人体簇进行多目标跟踪（先支持单目标也可以）
   - 用卡尔曼滤波维护质心、速度、bbox
3. voxel_stabilizer.py
   - 把同一 track 的滑窗点云对齐到统一参考系
   - 进行体素化
   - 统计每个体素在窗口内的出现率
   - 出现率超过阈值的体素保留
   - 再导出稳定点云
4. background_map.py
   - 维护固定环境反射点的背景地图
   - 用于排除稳定但非人体的假点

参数建议支持：
- 窗口长度 W
- voxel_size
- occupancy_threshold
- min_cluster_points
- eps / min_samples
- track_max_age
- match_distance_threshold

输出：
- stable_cloud
- raw_cluster_cloud
- track_state
- stability_metrics（例如 centroid jitter、occupancy consistency）

另外请补充：
- 一个 end-to-end demo，展示原始点云和稳点云的对比
- matplotlib 可视化脚本
- 简单评估函数：计算质心抖动和稳定体素比例

请直接输出完整代码和运行方法。
```

---

## Prompt 5：实现复杂室内环境下的多径抑制

```text
继续开发多径抑制模块，目标是在室内跌倒监测场景中减少墙面、地面、家具反射导致的假人体点。

请新增 multipath_filter.py，并完成以下功能：
1. 地面高度过滤
   - 根据雷达安装高度与地面平面模型过滤明显地杂波
2. 镜像路径假目标排除
   - 给定墙面/地面简化几何模型
   - 检查某些点是否更符合镜像反射路径而不是真实人体轨迹
3. 时序连续性校验
   - 对只出现1-2帧、且不满足轨迹连续性的高能点做删除
4. 背景强反射点屏蔽
   - 对长期固定存在的热点建立 blacklist

要求：
- 代码可读，参数可配
- 给出一个模拟场景测试
- 在 demo 中输出过滤前后点数变化
- 在 README 中写清楚该模块适用假设与局限

请直接给完整代码。
```

---

## Prompt 6：加入轻量增密网络（可选第二阶段）

```text
现在在已有 stable point cloud pipeline 基础上，增加一个轻量级点云增密网络，目标是让人体点云更完整，方便后续跌倒检测或姿态估计。

模型要求：
1. 输入：长度为 W 的 stable human point cloud sequence
2. 编码器：PointNet++ 或简化 PointNet encoder
3. 时序模块：BiGRU 或 Temporal Transformer
4. 解码器：coarse-to-fine completion head
5. 输出：densified human point cloud
6. 训练阶段允许引入伪标签或图像掩码监督接口
7. 推理阶段只依赖雷达点云

请完成：
- models/pointnet2_encoder.py
- models/temporal_gru.py
- models/completion_head.py
- train/train_densify.py
- train/losses.py

损失函数建议支持：
- Chamfer Distance
- temporal consistency loss
- occupancy regularization
- optional silhouette/mask projection loss 接口

同时请提供：
- 一个 synthetic dataset stub
- 训练脚本
- 推理脚本
- 评估脚本

要求：
- 代码必须能继续开发，不要只写论文式伪代码
- 所有 tensor shape 注释清楚
- 配置文件补齐
- README 增加训练说明
```

---

## Prompt 7：直接对接跌倒检测模型

```text
继续在现有项目上实现跌倒检测模块，输入不再是原始雷达点，而是 stable human point cloud sequence 或 densified point cloud sequence。

要求实现：
1. features/fall_features.py
   - 计算质心高度变化
   - 速度峰值
   - 身体长度/高度比变化
   - 地面邻近点占比
   - PCA 主方向变化
   - 跌倒后静止时间
2. models/fall_net.py
   - 支持两种模式：
     a. 传统特征 + MLP / XGBoost 风格接口
     b. 时序点云特征 + GRU/Transformer 分类器
3. train/train_fall.py
4. eval/eval_fall.py

请同时实现：
- 数据集接口：一个样本包含 W 帧稳定人体点云及标签（fall / non-fall）
- 训练与验证循环
- confusion matrix、precision、recall、F1 输出
- ablation 开关：
  - raw cloud
  - stable cloud
  - densified cloud
  三种输入的对比实验接口

请直接输出完整代码、配置文件和运行命令。
```

---

## Prompt 8：让 Claude Code 自动做论文复现实验
如果你想让 Claude Code 帮你直接做 ablation，可以继续贴下面这段：

```text
现在请你基于整个仓库，补齐完整实验体系，目标是验证“稳点人体点云”对跌倒监测的增益。

请设计并实现以下实验：
1. Baseline A：单帧原始点云
2. Baseline B：动态分支点云
3. Baseline C：静态分支点云
4. Ours-1：双分支融合点云
5. Ours-2：双分支融合 + 时序稳点
6. Ours-3：双分支融合 + 时序稳点 + 增密网络

每组实验都要输出：
- 平均点数
- 质心抖动
- 稳定体素比例
- 跌倒检测 Precision / Recall / F1
- 推理延迟
- 显存/内存占用（尽量统计）

同时请生成：
- eval/ablation_runner.py
- 自动汇总 csv
- 自动画图脚本
- README 实验章节
- 最终表格模板（适合论文直接使用）

不要只给实验计划，要补齐代码。
```

---

## 7. 参数初始化建议（你可以直接先这么设）

```yaml
dsp:
  range_window: hann
  doppler_window: hann
  cfar_type: ca
  cfar_guard_cells: [2, 2]
  cfar_train_cells: [8, 4]
  cfar_pfa: 1.0e-4

zones:
  near:
    range_m: [0.0, 1.5]
    threshold_scale: 1.35
  mid:
    range_m: [1.5, 4.0]
    threshold_scale: 1.0
  far:
    range_m: [4.0, 8.0]
    threshold_scale: 0.85

cluster:
  eps_m: 0.18
  min_samples: 5
  min_points_per_human: 12

tracker:
  max_age: 8
  match_dist_m: 0.6

stabilizer:
  window_size: 8
  voxel_size_m: 0.05
  occupancy_threshold: 0.35
  min_stable_voxels: 20

multipath:
  ground_z_min: -0.15
  ground_z_max: 0.10
  wall_mirror_check: true
  temporal_min_hits: 3
```

---

## 8. 你真正应该写成论文创新点的部分

如果你打算发“毫米波雷达跌倒监测”论文，最有潜力的创新组合是：

### 方案 A（最稳）
**Dual-Branch Stable Human Point Cloud Generation for Fall Monitoring**
- 双分支点云
- 时序稳点
- 多径抑制
- 跌倒检测

### 方案 B（更偏学习）
**Stable-and-Densified Human Point Cloud for mmWave Fall Detection**
- 双分支稳点
- 轻量增密
- 跌倒检测

### 方案 C（更冲论文）
**Structure-Aware Stable Human Point Cloud Learning**
- 双分支稳点
- 结构辅助任务（关键点/人体部位）
- 跌倒检测

---

## 9. 最后给你的建议

### 必做
先做出来：
- 双分支点云
- DBSCAN + tracking
- sliding window voxel stabilizer

### 后做
再补：
- 增密网络
- 结构辅助任务

### 不建议
一开始就直接做大网络端到端。  
因为如果前端点云生成不稳，后端网络只是在学习噪声。

---

## 10. 一句话版本
**你的最优路线不是“直接做跌倒分类”，而是先把“动态分支找人 + 静态分支补形状 + 时序滑窗稳点 + 多径抑制”这条稳点人体点云链路做出来，再把它喂给跌倒检测模型。**
