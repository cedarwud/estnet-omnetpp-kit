# Codex Agent Prompt For Portable Setup And Run

你現在在一台新的 Linux 環境中工作。這台機器可能是：

- VMware 中的 Ubuntu 20.04 / 22.04 / 24.04
- VirtualBox 中的 Ubuntu 20.04 / 22.04 / 24.04
- 原生 Ubuntu Desktop 20.04 / 22.04 / 24.04

專案是 portable kit，根目錄下應有：

- `setup.sh`
- `run.sh`
- `detect_env.sh`
- `verify_versions.sh`
- `tools/`
- `scripts/`
- `docs/`

目標：

1. 先偵測當前環境
2. 再執行 portable kit 的 setup
3. 再執行 portable kit 的 run
4. 如果失敗，先判斷那是什麼環境特有問題，再做最小修正
5. 修正必須是 environment-scoped，不可為了新環境破壞既有 WSL2 baseline
6. 所有修改都必須可追蹤、可重跑、可保留 log
7. 不要把已 build 的 workspace 當成可攜資產；只把 portable control layer 當成 Git 應提交內容

工作原則：

- 先探索，不要直接改檔
- 優先使用既有入口：
  - `./detect_env.sh`
  - `./setup.sh`
  - `./run.sh`
- 若 `./setup.sh` 因 `sudo` / 非互動 session 無法安裝 prerequisite packages，不可卡住或反覆重試；必須改走：
  - `./setup.sh --print-apt-command`
  - 請使用者在可輸入 sudo 密碼的 shell 中手動執行該命令
  - 然後再繼續 `./setup.sh --skip-apt`
- 若 setup 失敗，只重跑對應 stage：
  - `./tools/run_stage.sh --list`
  - `./tools/run_stage.sh --force <stage>`
- 不要一次改很多地方
- 不要用破壞性指令，例如 `rm -rf`、`git reset --hard`、`git checkout --`
- 若修改邏輯，只能做最小修正
- 若某個 workaround 只適用於特定環境，必須把判斷條件寫進 `scripts/common.sh` 或 `setup/run` 對應腳本，不可直接覆蓋全域預設
- 不可因為 VMware/VirtualBox/native Linux 的問題而破壞 WSL 的既有行為

你必須先執行並記錄：

- `./detect_env.sh`
- `uname -a`
- `cat /etc/os-release`
- `systemd-detect-virt || true`

你必須先整理出這個環境指紋：

- `environment=`
- `distro=`
- `distro_version=`
- `distro_codename=`
- `virtualization=`

執行策略：

1. 先跑 `./detect_env.sh`，確認現有腳本對這個環境的判斷是否合理
2. 再跑 `./setup.sh`
3. 若 `./setup.sh` 回報需要 sudo 但目前 session 無法互動輸入密碼：
   - 先跑 `./setup.sh --print-apt-command`
   - 要求使用者手動執行輸出的 `sudo apt-get` 命令
   - 再跑 `./setup.sh --skip-apt`
4. setup 成功後再跑 `./run.sh`
5. 若 run 失敗，再判斷是否需要：
   - 保持 native GL
   - 改用 software GL
   - 調整 Qt / IDE / Browser / WebKit / OpenGL / GLX 相關依賴
   - 針對 Ubuntu 22.04 / 24.04 調整 apt package 名稱或版本相容性
   - 對 `libwebkit2gtk-*` 這類版本相關套件，不可假設 `20.04/22.04/24.04` 名稱相同
6. 若失敗，先分類問題屬於哪一類：
   - package/dependency naming issue
   - compiler/cmake/build issue
   - Qt/IDE/browser issue
   - OpenGL/GLX/runtime issue
   - osgEarth/OSG runtime asset/path issue
   - environment detection issue
7. 只有在確認問題是該環境特有時，才新增 version/environment-specific 分支
8. 修正後只重跑失敗的 stage，不要整套重跑
9. 每次修正後都要驗證：
   - 新環境是否恢復正常
   - WSL 既有邏輯是否仍保留
   - 預設行為是否仍符合：
     - WSL -> software GL
     - 非 WSL -> native GL
     - 除非有明確證據顯示該特定環境需要不同預設

修改限制：

- 優先修改：
  - `scripts/common.sh`
  - `setup.sh`
  - `tools/start_omnetpp.sh`
  - 個別 stage 腳本
- 若是 Ubuntu 版本差異，優先以：
  - `distro`
  - `distro_version`
  - `distro_codename`
  - `virtualization`
  作為條件分支
- 不要把某個新環境的 workaround 直接套用到所有環境
- 不要把 runtime workaround 誤寫成 build requirement
- 不要刪除 WSL 既有 software GL 預設，除非有充分證據

文件要求：

- 若你有修改環境判斷或參數策略，更新：
  - `README.md`
  - `docs/spec.md`
  - `docs/stages.md`
  - `docs/final-order.md`
- 若新增了新的 portability 注意事項，也更新：
  - `docs/pre-push-checklist.md`

最後交付時請明確列出：

1. 你偵測到的環境指紋
2. setup/run 是否成功
3. 若失敗，root cause 是什麼
4. 你做了哪些最小修正
5. 哪些修正是 environment-specific
6. 為什麼這些修正不會破壞 WSL2 baseline
7. 若仍有問題，哪些屬於該虛擬化/桌面環境本身限制，哪些屬於版本相容問題
