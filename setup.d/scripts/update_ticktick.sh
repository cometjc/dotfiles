#!/bin/bash

# --- 全域設定變數 ---
APP_NAME="ticktick" # 請替換為您應用程式的實際套件名稱
DEB_URL="https://ticktick.com/static/getApp/download?type=linux_deb_x64"
TEMP_DIR="/tmp"
LOG_TAG="ticktick_updater.sh" # Journald 日誌標籤

# 腳本本身的安裝路徑和 cron 命令
UPDATER_SCRIPT_NAME="ticktick_updater.sh"
UPDATER_SCRIPT_PATH="/usr/local/bin/$UPDATER_SCRIPT_NAME"
# 每日凌晨 3 點執行，由 root 用戶執行，並將所有輸出導向 /dev/null
CRON_JOB_COMMAND="0 3 * * * root $UPDATER_SCRIPT_PATH >/dev/null 2>&1"

# --- 函數：記錄日誌到 journald ---
log_message() {
    logger -t "$LOG_TAG" -- "$1"
}

# --- 函數：維護腳本在 /usr/local/bin 和 /etc/crontab 中的存在 ---
maintain_self() {
    echo "--- 正在維護腳本安裝狀態 ---"

    # 檢查是否以 root 權限執行
    if [[ $EUID -ne 0 ]]; then
        echo "錯誤：此腳本需要 root 權限才能複製檔案和修改 /etc/crontab。請使用 sudo 執行。"
        exit 1
    fi

    # 1. 複製腳本本身到 /usr/local/bin/ 並賦予執行權限
    # $0 代表目前正在執行的腳本的路徑
    if [ ! -f "$UPDATER_SCRIPT_PATH" ] || ! cmp -s "$0" "$UPDATER_SCRIPT_PATH"; then
        echo "複製或更新 $UPDATER_SCRIPT_NAME 到 $UPDATER_SCRIPT_PATH..."
        cp "$0" "$UPDATER_SCRIPT_PATH"
        chmod +x "$UPDATER_SCRIPT_PATH"
        echo "複製完成並設定執行權限。"
    else
        echo "腳本已存在於 $UPDATER_SCRIPT_PATH 且內容一致，無需複製。"
    fi

    # 2. 維護 /etc/crontab 中的條目
    echo "正在維護 /etc/crontab 中的條目..."

    # 檢查 cron job 是否已存在且正確
    # 先刪除所有包含此腳本路徑的行，然後再添加正確的行，確保唯一性和正確性
    if grep -q "$UPDATER_SCRIPT_PATH" /etc/crontab; then
        echo "發現舊的 cron job 條目，正在更新..."
        # 使用 sed 刪除所有包含腳本路徑的行
        sed -i "\#$UPDATER_SCRIPT_PATH#d" /etc/crontab
    else
        echo "未發現 cron job 條目，將添加新的。"
    fi

    # 將新的 cron job 加入到 /etc/crontab
    # 使用 tee -a 寫入，並將輸出導向 /dev/null
    echo "$CRON_JOB_COMMAND" | tee -a /etc/crontab >/dev/null
    echo "Cron job 已成功添加/更新。將每日凌晨 3 點由 root 用戶執行。"

    echo "--- 腳本安裝狀態維護完成 ---"
}

# --- 函數：執行 TickTick 更新邏輯 ---
perform_update() {
    log_message "--- 開始檢查 $APP_NAME 更新 ---"

    # 確保此函數由 root 執行，因為它會執行 apt install
    if [[ $EUID -ne 0 ]]; then
        log_message "錯誤：更新操作需要 root 權限。請確保腳本由 root 用戶執行 (例如透過 /etc/crontab)。"
        exit 1
    fi

    # --- 1. 獲取目前已安裝的版本 ---
    CURRENT_VERSION=""
    if dpkg -s "$APP_NAME" &>/dev/null; then
        # 修正：確保版本號不包含額外的換行符或其他空白字元
        CURRENT_VERSION=$(dpkg -s "$APP_NAME" | grep "^Version:" | head -n 1 | awk '{print $2}' | tr -d '[:space:]')
        log_message "目前已安裝的 $APP_NAME 版本：$CURRENT_VERSION"
    else
        log_message "$APP_NAME 尚未安裝。將嘗試首次安裝。"
    fi

    # --- 2. 下載最新的 .deb 檔案 ---
    TEMP_DEB_PATH="$TEMP_DIR/${APP_NAME}_latest.deb"
    log_message "正在從 $DEB_URL 下載最新的 .deb 檔案到 $TEMP_DEB_PATH..."
    if ! wget -q -O "$TEMP_DEB_PATH" "$DEB_URL"; then
        log_message "錯誤：下載 .deb 檔案失敗。請檢查 URL 或網路連線。"
        rm -f "$TEMP_DEB_PATH" # 即使下載失敗也嘗試清理
        exit 1
    fi
    log_message "下載完成。"

    # --- 3. 從下載的 .deb 檔案中提取版本號 ---
    NEW_VERSION=$(dpkg-deb -I "$TEMP_DEB_PATH" 2>/dev/null | grep Version | awk '{print $2}')
    if [ -z "$NEW_VERSION" ]; then
        log_message "錯誤：無法從下載的 .deb 檔案中提取版本號。檔案可能已損壞或不是有效的 .deb 檔案。"
        rm -f "$TEMP_DEB_PATH"
        exit 1
    fi
    log_message "下載的 .deb 檔案版本：$NEW_VERSION"

    # --- 4. 比較版本並決定是否更新 ---
    INSTALL_REQUIRED=false
    if [ -z "$CURRENT_VERSION" ]; then
        # 應用程式尚未安裝，直接安裝
        log_message "$APP_NAME 尚未安裝，將進行首次安裝。"
        INSTALL_REQUIRED=true
    elif dpkg --compare-versions "$NEW_VERSION" gt "$CURRENT_VERSION"; then
        log_message "發現新版本 ($NEW_VERSION) 大於目前版本 ($CURRENT_VERSION)。準備更新..."
        INSTALL_REQUIRED=true
    else
        log_message "目前版本 ($CURRENT_VERSION) 已是最新或更高版本 ($NEW_VERSION)。無需更新。"
    fi

    # --- 5. 安裝或更新 ---
    if [ "$INSTALL_REQUIRED" = true ]; then
        log_message "正在安裝/更新 $APP_NAME..."
        # 由於此腳本將由 root 執行，直接使用 apt install 即可
        if apt install -y "$TEMP_DEB_PATH"; then
            log_message "$APP_NAME 成功安裝/更新到版本 $NEW_VERSION。"
        else
            log_message "錯誤：安裝/更新 $APP_NAME 失敗。請檢查錯誤訊息。"
        fi
    fi

    # --- 6. 清理暫存檔案 ---
    rm -f "$TEMP_DEB_PATH"
    log_message "清理暫存檔案 $TEMP_DEB_PATH。"
    log_message "--- $APP_NAME 更新檢查結束 ---"
}

# --- 主執行邏輯 ---
echo "TickTick 自動更新器啟動..."

# 每次執行都先維護自身在系統中的狀態
maintain_self

# 然後執行實際的更新邏輯
perform_update

echo "TickTick 自動更新器執行結束。"
exit 0
