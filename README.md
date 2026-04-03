# ESTNeT OMNeT++ Kit

這個資料夾是可攜的控制層。目的是讓新環境只靠這個 kit 就能：

- 執行 `./setup.sh` 從頭建出 baseline
- 執行 `./run.sh` 啟動 OMNeT++ IDE
- 保留 `tools/run_stage.sh` 與 `scripts/00..90.sh` 作為可重跑、可定位問題的 debug 骨架

## Quick Start

```bash
cd /path/to/estnet-omnetpp-kit
./setup.sh
./run.sh
```

補充：

- `./setup.sh` 會先偵測環境，再在 Ubuntu/WSL 內自動執行 `sudo apt-get install`
- `./run.sh` 會先偵測環境，再自動決定預設 GL 模式
- 若只想看目前環境判斷結果，可執行 `./detect_env.sh`

若要把這份 portable kit 交給新環境中的 Codex agent，建議直接使用這句：

```text
請先閱讀 ./docs/codex-agent-portable-setup-run-prompt.md，然後完全依照該文件執行：
1. 偵測環境
2. 執行 ./setup.sh
3. 執行 ./run.sh
4. 若失敗，先判斷 root cause 是否為該環境特有，再做最小的 environment-scoped 修正
5. 不可破壞既有 WSL2 baseline
```

## Script Reference

### Main Entrypoints

- `./setup.sh`
  - 新環境主要入口
  - 會先偵測環境，再安裝 prerequisite packages，最後執行預設 stage flow
  - 用法：
    - `./setup.sh`
    - `./setup.sh baseline`
    - `./setup.sh full`
    - `./setup.sh ide`
    - `./setup.sh --skip-apt`
    - `./setup.sh --force`

- `./run.sh`
  - 日常啟動 OMNeT++ IDE 的主要入口
  - 會依目前環境自動選擇預設 GL 模式
  - 用法：
    - `./run.sh`
    - `./run.sh --software-gl`
    - `./run.sh --native-gl`

- `./verify_versions.sh`
  - 驗證目前 workspace 是否真的對應到：
    - OMNeT++ 5.5.1
    - INET 4.2
    - OpenSceneGraph 3.6.5
    - osgEarth 2.7
  - 會檢查 source pin、installed headers、`configure.user`、以及實際 runtime link
  - 每次執行都會覆寫：
    - `state/version-verification.md`
  - 用法：
    - `./verify_versions.sh`

- `./detect_env.sh`
  - 輸出目前偵測到的：
    - environment
    - distro
    - `VERSION_ID`
    - codename
    - virtualization
    - setup/run 預設策略
  - 用法：
    - `./detect_env.sh`

### Debug Entrypoints

- `./tools/run_all.sh`
  - 依 mode 一次執行多個 stage
  - 比 `setup.sh` 更偏 debug / 進階操作
  - 用法：
    - `./tools/run_all.sh ready`
    - `./tools/run_all.sh baseline`
    - `./tools/run_all.sh full`
    - `./tools/run_all.sh ide`
    - `./tools/run_all.sh ready --force`

- `./tools/run_stage.sh`
  - 只執行單一 stage
  - 用於局部重跑、問題定位、只修某一階段
  - 用法：
    - `./tools/run_stage.sh --list`
    - `./tools/run_stage.sh 40`
    - `./tools/run_stage.sh --force 50`

### Generated / Internal Scripts

- `./activate_env.sh`
  - 由 Stage 70 產生的統一環境腳本
  - 可手動 source
  - 用法：
    - `source ./activate_env.sh`

- `./tools/start_omnetpp.sh`
  - `run.sh` 內部實際呼叫的 launcher
  - 平常通常不需要直接呼叫

- `scripts/common.sh`
  - 共用函式庫
  - 不是獨立入口

- `scripts/00_env_check.sh` 到 `scripts/90_build_omnetpp_ide.sh`
  - 各 stage 的實作本體
  - 平常不要直接呼叫，建議經由 `./tools/run_stage.sh`

## Stage Reference

- `00`
  - 檢查 OS、WSL、compiler、cmake、git、java、python、make、Qt、OpenGL/GLX、WebKitGTK 等依賴

- `10`
  - 下載並 pin 所有 source

- `20`
  - build OpenSceneGraph 到 local prefix

- `30`
  - build osgEarth 2.7 Method A

- `31`
  - build osgEarth 2.7 Method B

- `40`
  - 修改 `configure.user`
  - 執行 `./configure`
  - build OMNeT++

- `50`
  - 準備並 build INET 4.2
  - 修正 INET IDE metadata

- `60`
  - clone/prepare estnet 與 estnet-template
  - 補 estnet-template 必要 runtime config

- `70`
  - 產生統一 `activate_env.sh`

- `80`
  - 做 activation / binary / library / runtime policy smoke test

- `90`
  - build 並掛接 OMNeT++ IDE payload

## Environment Detection

`setup.sh` 與 `run.sh` 都會在一開始自動偵測環境。  
目前會辨識：

- Linux 發行版
- `VERSION_ID`
- codename
- virtualization 類型
- 是否為 WSL

目前的預設策略是：

- `WSL`
  - `run` 預設使用 software GL

- 非 `WSL`
  - `run` 預設使用 native GL

這代表：

- 在 WSL2/WSLg，直接 `./run.sh` 就會自動套用 software GL workaround
- 在 VMware / VirtualBox / 原生 Ubuntu Desktop，直接 `./run.sh` 會先走 native GL

需要手動覆蓋時可用：

```bash
./run.sh --software-gl
./run.sh --native-gl
```

`--software-gl` 的意義：

- 強制使用 Mesa llvmpipe
- 避開 WSLg 的 D3D12/OpenGL 轉譯不穩定問題

這是 WSL baseline workaround，不取代 VMware 或其他穩定 Linux GUI 環境的最終圖形驗證。

## Setup Notes

`./setup.sh` 在 Ubuntu/WSL 會自動安裝 prerequisite packages。  
目前包含：

- build-essential / cmake / pkg-config
- default-jre / default-jdk
- bison / flex
- maven / swig
- Qt 開發套件
- `libwebkit2gtk-4.0-37`
- OpenGL / X11 開發套件
- curl / gdal / geos / sqlite3 開發套件

補充：

- `libwebkit2gtk-4.0-37` 是 IDE 內建 Browser widget 的 runtime dependency
- 它不是 simulation / OSG / osgEarth build 的核心依賴，但加進 setup 比較穩
- 若你已自行準備好系統套件，可用 `./setup.sh --skip-apt`

## Upstream Scripts After Setup

以下腳本是 setup 後會出現的 upstream 腳本，不是 portable kit 的主要對外入口：

- `omnetpp-5.5.1/configure`
  - OMNeT++ upstream configure script
  - 由 Stage 40 使用

- `omnetpp-5.5.1/setenv`
  - OMNeT++ upstream environment script
  - 可手動 source，但日常建議優先用 `source ./activate_env.sh`

- `inet/setenv`
  - INET upstream environment script
  - 可手動 source，但日常建議優先用 `source ./activate_env.sh`

## Portability Notes

這個 kit 預期用在新環境 fresh setup。  
不要把舊環境已經 build 過的下列目錄一起帶過來：

- `sources/`
- `build/`
- `third_party/`
- `omnetpp-5.5.1/`
- `inet/`
- `estnet/`
- `estnet-template/`
- `activate_env.sh`
- `logs/`
- `state/`

原因：

- `git worktree` metadata
- OMNeT++ / INET 產生的 makefiles
- configure 結果
- build artifact 的 RPATH

都可能包含環境相關路徑。這些是可重建產物，不應該被當成可攜資產。

真正需要帶走的只有：

- `versions.env`
- `paths.env`
- `setup.sh`
- `run.sh`
- `detect_env.sh`
- `verify_versions.sh`
- `tools/`
- `scripts/`
- `README.md`
- `.gitignore`
- `.env.local.example`
- `docs/spec.md`
- `docs/stages.md`
- `docs/final-order.md`
- `docs/pre-push-checklist.md`

推送到 GitHub 前，請先看：

- `docs/pre-push-checklist.md`

## Env Files

- `versions.env` 與 `paths.env`
  - 版本控制中的專案設定
  - 應提交到 Git

- `.env.local`
  - 本機覆寫檔
  - 預設不提交

- `.env.local.example`
  - 本機覆寫範本

如果照這個 kit 在新位置重新 `setup`，理論上不會重現「搬移已建好 workspace 後 worktree / link path 壞掉」的問題。
