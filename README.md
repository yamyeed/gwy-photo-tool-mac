# 国考「照片处理工具」Mac 运行方案（免虚拟机、免 Windows）

在 Apple Silicon Mac 上，用 **Wine 11 兼容层**（Whisky fork，非虚拟机）运行公务员报名确认的官方 Windows「照片处理工具」，产出报名系统认可的 `报名照片.JPG`（约 10K）。

> 2026-11-04 在 macOS 26.3 / M 系列芯片上端到端实测通过：审核 → 保存 → 产物 10,163 bytes / 295×413 / 标准 JPEG。

## 为什么必须用官方工具

官方考务问答原文：「照片上传之前**均须**通过照片处理工具进行处理、保存，**否则无法完成照片上传和后续相关操作**」。自己用 PS / 预览裁剪压缩到 295×413、10K 是**过不了校验的**——报名系统会报「照片未经过官方处理工具处理」。官方也没有 Mac 版。

## 为什么可以这么做

- 官方工具就是一个普通的 32 位 Windows GUI 程序（PE32 / i386，MFC + 2006 年 OpenCV 1.0）。
- **Wine 11.0 的新 WoW64 已正式支持**在纯 64 位宿主（Apple Silicon）上运行 32 位 Windows 程序，不需要任何虚拟机、不需要 Windows 授权。
- 出片的是**官方程序本体**，产物与在 Windows 上完全一致，不修改、不逆向、不伪造任何校验数据。

## 快速开始（约 10 分钟，大部分是下载时间）

```bash
chmod +x setup_and_run.sh cleanup.sh
./setup_and_run.sh 你的证件照.jpg     # 也可不带参数，程序里自己选图
```

脚本自动完成：下载 Whisky（10 MB）→ 下载 Wine 11 运行时（332 MB，GitHub 直连慢会自动走镜像）→ 创建容器 → 从**官方 CDN** 下载照片工具并校验 SHA-256 → 从**微软官方** VC6 运行库提取 `mfc42.dll`（Wine 不自带，缺它启动报 `c0000135`）→ 启动窗口。

## 离线安装（不想等下载 / 网络不好）

用 `gwy-photo-mac-offline.tar`（340 MB，SHA-256 `7d4ac1d4…56358`，已含 Whisky + Wine 运行时）：

```bash
tar xf gwy-photo-mac-offline.tar      # 解出 offline_bundle/，与脚本同目录
./setup_and_run.sh 你的证件照.jpg      # 自动检测到离线包，跳过 GitHub 下载
```

离线包只含开源组件（Whisky GPL-3.0 / Wine LGPL-2.1，来源声明见包内 `BUNDLE_README.md`）；官方工具与微软 VC6 有版权限制不入包，安装时仍从官方源下载（合计 6 MB，带哈希校验）。

想自己重新打离线包（比如版本更新后）：`./make_offline_bundle.sh`。

窗口弹出后，人工操作三步：

1. **打开照片文件** → 选你的证件照（蓝/白底、JPG、宽≥295 高≥413、未经美颜）
2. 等待审核提示通过（程序内会显示照片）
3. **保存照片文件** → 得到约 10K 的 `报名照片.JPG`

之后全部在 Mac 浏览器完成：登录 `http://gwy.cpta.com.cn` → 上传照片 → 选考点 → 确认 → 缴费。

## 傻瓜式一键版（推荐给不懂命令行的用户）

把「照片处理助手.app」和 `offline_bundle/` 放在同一个文件夹，**双击 App** 即可：

选照片 → 自动准备环境 → 弹出官方工具窗口 → 出片后弹窗告诉你照片在哪。

首次打开被 macOS 拦截时：右键点击 App → 「打开」→ 再点「打开」（App 为 ad-hoc 签名，无开发者账号）。之后正常双击。

## 同类方案对比（2026-11 调研）

| 项目 | 路线 | 主要风险/劣势 |
|---|---|---|
| **本仓库** | **Wine 11 运行官方 exe 本体** | 需 ~1.2 GB 磁盘；首次启动需右键打开；出片需在窗口里点三下 |
| [gwyzpclgj-web](https://github.com/hr3lxphr6j/gwyzpclgj-web) | 浏览器 WASM 重实现（复刻 10 字节尾标记） | 重实现产物，官方服务端校验一变即失效；逆向正确性无官方背书 |
| [gwy-photo-mac](https://github.com/shoal-rat/gwy-photo-mac) | Python 原生 macOS 重实现 | README 自述「不保证与 EXE 输出完全一致，不保证被报名网站接受」 |
| [gwy-photo-tool-linux](https://github.com/earlcheungl/gwy-photo-tool-linux) | Linux/GTK 重实现 | 同上；仅 Linux |
| HivisionIDPhotos | AI 证件照生成 | 产物不带官方标记，**过不了**国考报名上传校验，只能做前置修图 |

本仓库的核心差异：**出片的是官方程序本体**，产物与 Windows 上逐字节同源，不存在"逆向复刻是否被服务器认可"的问题——这也是官方「必须使用照片处理工具处理」要求的字面满足方式。

## 上不了 GitHub？

国内网络可用镜像直链下载（内容与 Release 完全一致，脚本本身也已内置同样镜像回退）：

- 离线整包（340 MB）：
  `https://ghfast.top/https://github.com/yamyeed/gwy-photo-tool-mac/releases/download/v1.0.0/gwy-photo-mac-offline.tar`
- 仓库代码 zip：
  `https://ghfast.top/https://github.com/yamyeed/gwy-photo-tool-mac/archive/refs/heads/main.zip`

备用镜像：把上面链接里的 `ghfast.top` 换成 `gh-proxy.com`。下载后请核对 SHA-256（见 Release 说明）。镜像站为第三方公共服务，若失效请提 issue，或从网盘备份渠道获取。

## 发布给别人的三种姿势

1. **网盘整包（小白首选）**：`gwy-photo-mac-offline.tar` + 仓库其余文件打包成一个 zip 发给对方，解压后双击「照片处理助手.app」。
2. **GitHub Release（推荐）**：仓库代码推送后，把 tar 作为 Release 附件上传（单文件上限 2 GB）：
   ```bash
   gh release create v1.0.0 gwy-photo-mac-offline.tar --title "v1.0.0 离线整包" --notes "解压后与脚本同目录，双击 照片处理助手.app"
   ```
3. **纯脚本版**：只推代码，让对方跑 `./setup_and_run.sh`（自动联网下载，需要网络尚可）。

收到的人常见三问（可作 Issue 模板/自动回复）：
- 「App 打不开/已损坏」→ 右键 App → 打开；或终端 `xattr -cr 照片处理助手.app`
- 「窗口点不动」→ 退出鼠标增强工具；Tab+空格
- 「保存没反应」→ 点按钮左上角边缘；成功标志是界面出现「审核通过，保存退出」

## 踩过的坑（都实测过）

| 现象 | 原因与解法 |
|---|---|
| 启动即退出，日志 `Library MFC42.DLL not found ... c0000135` | Wine 11 该构建不带 MFC 运行库。脚本已自动从微软官方包提取 `mfc42.dll` 放到 exe 同目录 |
| 窗口出现但**点不动** | 程序其实健康（在等事件）。① 退出 Mac Mouse Fix 等鼠标增强工具；② 先点窗口标题栏激活；③ 用 **Tab + 空格** 键盘操作按钮 |
| 点「保存」没反应 | 坐标偏移（Retina 缩放下鼠标映射不准）。别点按钮正中心，试按钮左上角边缘 / 文字第一个字上 |
| 程序窗口不在前台 | 脚本从终端启动，用 `Cmd+Tab` 或调度中心找「wine」窗口 |
| GitHub 下载只有 30 KB/s | 脚本已内置 `ghfast.top` 等镜像回退 |

## 卸载

```bash
./cleanup.sh    # 删除约 1.2 GB：~/.gwy-photo-mac + Whisky 运行时 + 容器
```

## 边界说明（重要）

- 本仓库**不含**官方工具本体，运行时从官方 CDN（`cdn.cpta.com.cn`）下载并做 SHA-256 校验（`b9dc626c…d25bb`）；官方工具版权归国家人社部人事考试中心所有。
- 本仓库**不修改、不逆向、不绕过**官方工具的任何处理逻辑；它只是在 Mac 上提供了运行官方程序的环境。
- 版本为 2026-11-04 固定版（Whisky fork 3.7.0 / Wine 11 运行时 3.1.1）。若官方后续更换工具或系统升级导致失效，欢迎提 issue。
- 报名相关规则以官方为准：`gwy.cpta.com.cn`；技术咨询 010-87901966（考期每日 8:00–20:00）。

## License

脚本部分 MIT。官方软件与 Wine/Whisky 各自遵循其许可。
