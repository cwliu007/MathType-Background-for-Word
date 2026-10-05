# MathType Background for Microsoft Word

[English](README.md)

> **僅支援 Windows。** 本專案是為 Windows 上的 Microsoft Word 設計，**不適用於 macOS、Word for Mac、Word Online、iOS 或 Android**。

這是一組非官方的 Windows 工具，用來修正或自訂 Microsoft Word 中 MathType 公式的背景顏色。

## 可以解決哪些問題？

如果你正在搜尋 Microsoft Word 裡 MathType 公式背景異常、白底、黑底、灰底或背景顏色不一致的解決方法，本工具可能適合這些情況：

- MathType 公式背景和 Word 頁面顏色不一致
- MathType 公式出現不想要的白色方塊、灰色背景、黑色背景或其他不一致背景
- MathType 公式背景顏色突然改變
- 想讓新插入的 MathType 公式自動固定成白底
- 想在 Word 中修改 MathType 公式背景顏色
- 想一次更新既有文件中大量 MathType 公式的背景
- 切換 Word 佈景主題或頁面背景後，MathType 公式顯示不自然
- 想解決 MathType 背景問題，但不希望程式持續掃描整份文件

本專案特別對應常見搜尋詞，例如 **MathType 公式 白底**、**MathType 公式 背景顏色**、**MathType 公式 黑底**、**MathType 公式 白色方塊**、**Word MathType 背景**、**MathType dark mode 背景**。

目前提供兩個版本，兩者共用相同的輕量化 MathType 插入 hook 核心：

- **`wb_v0.0.65.cmd`**：完整 Ribbon 版，可選背景顏色、淺／中／深，點選 MathType 公式時自動套用目前顏色，並提供「更新所有」功能。
- **`wb_no_v0.0.13.cmd`**：極簡無 Ribbon 版，新插入 MathType 公式時自動設為白色背景。

> **相容性說明：****僅支援 Windows。** 本工具預期適用於 Windows 上的 Word 16.x，並大致可用於 MathType 6.9d 及其較接近的早期版本，只要 Word Ribbon／template 結構相容。其他 Windows 環境也可能可用，但實際相容性取決於 MathType 是否仍保留程式所需的 Ribbon callback 與 template 結構。

## 為什麼需要這個工具？

Word 中的 MathType 公式是 OLE inline object。受到 Word 佈景主題、頁面背景、顯示方式或複製內容影響，公式背景有時不會和文件頁面自然一致。

這兩個工具在 MathType 完成公式插入後，加上一個很小的 post-processing 步驟，自動控制該公式的背景。

## 核心設計原理

兩個版本都**不重新實作 MathType 的公式插入功能**。

實際流程是：

```text
MathType Ribbon 指令
        ↓
wb wrapper callback
        ↓
MathType 原始 callback
        ↓
MathType 照原本方式插入公式
        ↓
wb 找到剛插入的 MathType OLE object
        ↓
套用背景
```

安裝器**不修改 MathType 的 VBA project**。它只在確認相容的情況下修改 MathType Ribbon XML callback，而 wb 自己的 VBA 則放在另一個 Word global template 中。

修改前後，安裝器會確認 MathType 的 `vbaProject.bin` 與 VBA signature streams 完全沒有變動。

## 如何找到「剛插入的公式」？

呼叫 MathType 前，程式先記錄目前 Word 的插入位置，稱為 **anchor**。

MathType 完成後：

1. 如果 Word 直接把新公式呈現為目前選取的 inline shape，就直接使用它。
2. 否則只搜尋很小的局部範圍：目前段落、前一段與下一段。
3. 只保留 MathType OLE objects。
4. 找出位置距離原始 anchor 最近的 MathType 公式。

這類 MathType 6.x 版本常見的插入行為包括：

- **Inline equation**：完成後游標停在公式右側。
- **Display equation**：完成後游標停在下一行最前面。
- **Right-numbered display equation**：完成後游標同樣停在下一行最前面。

因此 previous / current / next paragraph 的局部搜尋能涵蓋這三種正常插入模式，又不需要掃描整份文件。

## 兩個版本的差異

| 功能 | `wb_no_v0.0.13` | `wb_v0.0.65` |
|---|---:|---:|
| 新插入公式自動白底 | 有 | 有 |
| Inline / Display / Right-numbered hook | 有 | 有 |
| 額外 Ribbon UI | 無 | 有 |
| 背景顏色選擇 | 無 | 有 |
| 淺／中／深 | 無 | 有 |
| 無背景 | 無 | 有 |
| 點選單一 MathType 公式時自動套目前顏色 | 無 | 有 |
| 更新整份文件的公式背景 | 無 | 有 |
| `WindowSelectionChange` | 無 | 有，且非常輕量 |
| Timer / polling | 無 | 無 |
| 持續掃描文件 | 無 | 無 |

### 極簡版：`wb_no_v0.0.13.cmd`

這是最小、資源消耗最低的版本。

平常使用 Word 時幾乎完全 dormant。只有使用 MathType 的公式插入指令時才會執行。

它沒有：

- Timer
- Polling
- `SelectionChange`
- 背景文件掃描

這個版本需要找到相容的 MathType Word template，因為它直接 hook MathType 原有 Ribbon 的三個插入 callback。

### 完整 Ribbon 版：`wb_v0.0.65.cmd`

增加一組公式背景 Ribbon，包括：

- 更新所有公式背景
- 背景顏色選單
- White / Gray / Beige / Yellow / Blue / Green / Pink / No Background
- Light / Medium / Dark
- 點選單一 MathType 公式時自動套目前選擇的背景
- 根據目前 Word UI 顯示語言動態切換繁中／英文 Ribbon

它有一個非常輕量的 `WindowSelectionChange` handler。一般文字選取只做幾個條件判斷後立即退出，不會掃 paragraph、文件或所有公式。

只有按下「更新所有」時才會主動掃描目前文件中的 InlineShapes。

如果找不到已驗證相容的 MathType Ribbon，完整版本可以將背景控制 Ribbon 以 standalone 方式安裝，不會強行修改未知結構的 MathType template。

## 資源消耗

### `wb_no`

一般 Word 使用時幾乎沒有額外 CPU 工作。

只有 MathType 公式插入完成後才執行一次局部搜尋，而且範圍只限附近段落。

### `wb_v`

同樣非常輕量。

Word Selection 改變時會觸發一次 `WindowSelectionChange`，但一般文字選取幾乎立即退出。

只有使用者明確按下「更新所有」時才掃描整份文件。

兩個版本都**沒有 timer，也沒有 polling**。

## 安裝

1. 建議先儲存所有 Word 文件。
2. 執行想要的 `.cmd`。
3. Windows 要求 UAC 權限時按「是」。
4. 安裝器會動態偵測 Word 真正的 Startup path 與可用的 MathType template。
5. 安裝成功後會詢問是否立即 Restore。預設為 **No**；15 秒沒有輸入時會保留目前安裝並自動關閉 CMD。

安裝器在 UAC 提權前會先建立一個本機 TEMP 暫存副本。這是為了解決從 OneDrive 或其他同步資料夾直接啟動 installer 時，elevated process 重新讀取同步路徑可能不可靠的問題。

使用者仍然可以直接從 OneDrive 執行原始 `.cmd`；TEMP 副本只是安裝期間的暫存 staging。

## 兩個版本互相切換

兩個 installer 是互斥的。

- 安裝 `wb_v` 時，如果偵測到已安裝的 `wb_no`，會先安全還原並移除 `wb_no`。
- 安裝 `wb_no` 時，如果偵測到已安裝的 `wb_v`，會先安全還原並移除 `wb_v`。

只有在 `.wb_original` 與 MathType VBA integrity 檢查都安全的情況下才會進行切換。

## Restore

兩支 installer 本身都支援 restore：

```cmd
wb_v0.0.65.cmd restore
```

或：

```cmd
wb_no_v0.0.13.cmd restore
```

Restore 會在適用時恢復原始 MathType template，並移除 wb Word global add-in。

## Office / MathType 相容性

安裝器不只依賴單一硬編 Office 目錄，而是會動態檢查：

- Word 真正的 Startup path
- Word application directory
- Registry 中的 Word 安裝位置
- Program Files / Program Files (x86)
- 可用的 `Office*` 目錄

只有 MathType Ribbon 結構包含已驗證需要的 callback 時才會 patch。遇到未知的 MathType Ribbon 結構不會硬改。

預期相容範圍：

- **僅支援 Windows**
- Windows 10 / Windows 11
- Word 16.x 系列（包括 Office 2021 / Microsoft 365 類型安裝）
- MathType 6.9d 及其較接近的早期版本（Word Ribbon／template 結構需相容）

其他 MathType 版本是否可用，主要取決於所需的 Ribbon callback 與 template 結構是否仍存在。

本專案**不支援 Word for Mac 或其他非 Windows 版本的 Word**。

## 安全性注意事項

- 執行 installer 前請先儲存 Word 文件；安裝或 restore 時 Word 可能會被強制關閉。
- 修改 MathType template 前會建立 `.wb_original` 原始備份。
- 在覆蓋 patched MathType package 前會驗證 VBA integrity。
- 本工具為非官方工具，與 Wiris / MathType 或 Microsoft 無官方關係，也未獲其背書。

## 檔案

- [`installers/wb_v0.0.65.cmd`](installers/wb_v0.0.65.cmd) — 完整 Ribbon 版
- [`installers/wb_no_v0.0.13.cmd`](installers/wb_no_v0.0.13.cmd) — 極簡白底版