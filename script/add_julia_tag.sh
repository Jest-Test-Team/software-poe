#!/bin/bash

# 1. 檢查是否已安裝 GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "❌ 錯誤：請先安裝 GitHub CLI 並執行 'gh auth login' 登入"
    exit 1
fi

# 2. 取得當前登入的使用者名稱 (過濾掉雙引號與換行符號，確保字串純淨)
USERNAME=$(gh api user -q ".login" | tr -d '"' | tr -d '\r' | tr -d '\n')
echo "🔍 正在搜尋 @$USERNAME 擁有且包含 Julia 語言的專案..."

# 3. 搜尋符合條件的 repo (使用 owner: 代替 user: 更為精準)
REPOS=$(gh search repos "owner:$USERNAME language:julia" --json fullName --jq '.[].fullName')

if [ -z "$REPOS" ]; then
    echo "⚠️ 沒有找到任何包含 Julia 的專案。請確認專案的 GitHub 語言統計是否正確識別為 Julia。"
    exit 0
fi

# 4. 建立一個安全的暫存目錄來進行 Git 操作
TEMP_DIR=$(mktemp -d)
echo "📁 建立暫存工作目錄: $TEMP_DIR"

# 5. 開始迴圈處理每一個專案
for REPO in $REPOS; do
    echo "========================================"
    # 利用 basename 擷取 fullName (owner/repo) 中的 repo 名稱
    REPO_NAME=$(basename "$REPO")
    echo "🚀 正在處理: $REPO"
    
    cd "$TEMP_DIR" || exit
    
    # 下載專案 (使用 gh repo clone 支援 HTTPS/SSH 自動驗證，並使用 --depth 1 加快速度)
    gh repo clone "$REPO" -- --depth 1
    cd "$REPO_NAME" || continue

    # 檢查 README.md 是否存在 (考慮大小寫)
    README_FILE=$(ls | grep -i '^readme\.md$' | head -n 1)

    if [ -z "$README_FILE" ]; then
        echo "⏭️ 找不到 README.md，跳過此專案。"
        continue
    fi

    # 檢查是否已經加過標籤，避免重複附加
    if grep -iq "#JuliaLang" "$README_FILE"; then
        echo "✅ 已經包含 #JuliaLang 標籤，跳過..."
        continue
    fi

    # 6. 將標籤與連結附加到 README 檔案最下方
    printf "\n\n---\n*Powered by [#JuliaLang](https://julialang.org/) ⚡*\n" >> "$README_FILE"

    # 7. Git 提交
    git add "$README_FILE"
    git commit -m "docs: append #JuliaLang official hashtag and website link"
    
    # ⚠️ 安全機制：預設先將 git push 註解掉。
    # 建議您先跑一次，去暫存資料夾確認沒問題後，再把下面這行的註解拿掉
    # git push 

    echo "🎉 $REPO_NAME 處理完成！"
done

echo "========================================"
echo "🏁 所有專案處理完畢！"
echo "請至 $TEMP_DIR 檢查修改結果。若一切正確，請取消腳本中 git push 的註解並重新執行。"
# rm -rf "$TEMP_DIR"