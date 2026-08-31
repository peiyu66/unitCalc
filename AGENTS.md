# unitCalc 開發與發布工作約定

本文件適用於整個 unitCalc repository。它是使用者授權、由 Codex 主動維護的專案作業記憶，主要讀者是後續執行工作的 Codex；不以供使用者閱讀或手動維護為目的。內容可採最利於代理快速、準確執行的格式，不要求敘事性或一般文件可讀性。使用者在當次任務中的明確指示優先於本文件；若兩者可能衝突，先說明差異與影響。

## 本文件的維護

- Codex 可在不另行詢問的情況下更新本文件，以保存已確認且可重複使用的專案事實、工作方法、安全邊界、驗證方式或完成定義。
- 只有具跨任務價值的穩定資訊才寫入；暫時進度、單次診斷、未採用方案、聊天摘要與容易失效的外部狀態不寫入。
- 可直接重組、壓縮或刪除過時內容，使後續代理能更快採用；不需為人類閱讀保留原有篇章或措辭。
- 不記錄密碼、token、私鑰、驗證碼、個人資料或其他秘密；不以本文件取代 Git、Xcode、App Store Connect 或發布產物的即時查證。
- 更新本文件屬於專案維護，可與相關修改一併進行；仍須避免把無關變更混入範圍受限的 commit。

## 專案定位與目前基準

- unitCalc 是 SwiftUI 的 iPhone／iPad 通用計算機與台灣常用單位換算 App。
- unitCalc 是已在 App Store 正式上架並持續維護的免費 App；正式發行管道是 App Store Connect，不是 Ad Hoc、Enterprise、Development 安裝或以 IPA／GitHub Release 對外散布。
- 不搬用 simStock3 的 scheme、Bundle ID、Simulator、測試目標、資料模型、發布方式或其他專案專屬假設。
- 目前 Xcode scheme／target 為 `unitCalc`，Bundle ID 為 `tw.com.unlock.unitCalc`；任何發布操作前仍須從當前專案與 Archive 重新確認。
- 正式測試 targets 為 `unitCalcTests` 與 `unitCalcUITests`。前者涵蓋計算邊界、代表性單位換算、匯率解析、主要／備援來源與快取生命週期；後者驗證直橫向主要控制、單位橫向捲動、關於／隱私入口與基本按鍵操作。相關行為修改時同步擴充，不以臨時腳本取代。
- 目前最低系統版本為 iOS 15，使用 Swift 6 與完整 concurrency 檢查。除非任務明確要求，不為追求新 API 任意提高最低系統版本。
- 主要驗證裝置為 iPhone 13 mini 或更大螢幕、約 10 吋 iPad 與 13 吋 iPad；應兼顧直向、橫向、深色模式與合理的 Dynamic Type。
- App 的對外連線只應用於取得匯率。主要語意是臺灣銀行對台幣現金賣出匯率；若程式使用其他官方參考匯率作為備援，UI、紀錄、README 與隱私說明不得隱藏來源差異。
- 上述版本與設定都是可變狀態。開始工作與發布前必須重新讀取，不以本文件取代現況檢查。

## 開始工作

- 先閱讀根目錄 `README.md`、本文件、相關 `docs/`、Xcode 設定及現有發布文件，再決定如何整合任務。
- 開始修改前執行 Git 狀態檢查，確認目前 branch、upstream、ahead／behind 與工作樹差異。
- 遇到非本次產生的修改，先檢查並分類來源、與本次工作的重疊程度及風險；不得自行還原、覆蓋或混入無關 commit。
- 若遠端狀態會影響任務，先 fetch，再比較本機 HEAD、upstream 與工作樹；不得把舊的摘要或先前對話當作最新 Git 證據。
- 對不穩定的外部狀態（匯率端點、App Store Connect、簽章、憑證、遠端 branch）應即時查證。

## 修改範圍與程式設計

- 每次修改保持目的與範圍明確；避免順手重構與任務無關的區域。
- 保持 Swift 6 actor／concurrency 安全；可觀察且供 UI 使用的狀態須在合適的 actor 上更新。
- SwiftUI 版面以實際可用尺寸與容器為準，不以固定裝置方向、單一機型或快取的 Size Class 推斷視窗。
- 互動元件應兼顧觸控尺寸、Dynamic Type、深色模式、VoiceOver 標籤與 iPad 多工／視窗縮放。
- 單位、換算係數、顯示精度或匯率來源的修改屬於行為變更，必須用代表性案例驗證，不只確認畫面或編譯。
- 網路失敗不得破壞最後一次成功的匯率快取；更新 App、覆蓋安裝或一般測試不得無故清除快取與使用者狀態。
- 若新增資料庫、cache schema 或重算流程，實作前先定義資料保留、遷移、相容性與失敗恢復方式。
- 新增外部服務、分析、追蹤、帳號、個人資料收集或不同用途的網路連線時，必須同步檢查隱私政策與 App Store 隱私揭露。
- `PrivacyInfo.xcprivacy` 必須隨 App target 打包；目前 `UserDefaults` 僅保存 App 自身匯率快取，Required Reason 為 `CA92.1`。更改儲存範圍或加入 App Group 時重新核對，不沿用此理由。
- App 只透過 Apple 系統網路堆疊使用 HTTPS，build setting `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`；若日後加入自有或非豁免加密，必須重新評估出口合規聲明。

## 檔案與產物

- 不混入 `.DS_Store`、Xcode 個人狀態、DerivedData、建置產物、未要求的截圖、簽署輸出或臨時診斷檔。
- 不保存 GitHub token、Apple 密碼、私鑰、憑證內容、一次性驗證碼或其他秘密。
- 不任意修改 development team、Bundle ID、entitlements、signing style 或 provisioning 設定；若任務需要，先核對目標與發布影響。
- 行為、支援裝置、匯率來源或資料使用方式改變時，評估同步更新 `README.md`、`docs/`、隱私政策與 App Store metadata。

## Git 工作方式

- 不使用 `git reset --hard`、`git checkout --` 等可能丟失資料的指令；不主動 amend、rebase 或 force push。
- 不以清理工作樹為理由刪除或覆蓋來源不明的變更。
- Commit 前檢查完整 diff、`git diff --check`、檔案範圍與驗證結果；commit 訊息描述實際成果，不誇大完成狀態。
- Push 前先 fetch 並確認遠端 branch 沒有領先；若遠端已有新提交，先比較並安全整合，不直接覆蓋本機或遠端。
- Commit、push、tag、App Store Connect 上傳與提交審查是不同動作。除非當次任務已明確包含，不因「修改完成」自動推定已授權所有後續動作。
- 文件-only 修改可以只 commit／push 到 GitHub，不需建立 App Store 版本；App 程式變更則必須評估 marketing version 與 build number 是否應提高。

## Xcode 與 Simulator

- 「建置成功」只證明程式可編譯；需要確認操作或畫面時，必須將同一次建置產物安裝並啟動到指定 Simulator。
- Simulator 尚未啟動時，先 boot，並等待 `bootstatus` 完成後再安裝或啟動。
- 覆蓋安裝預設保留既有 App 資料，不先 uninstall、erase 或清空 container。需要乾淨安裝測試時，明確指出會失去哪些測試資料。
- 以不同啟動參數或不同 build 重新執行前，先終止舊 PID，避免把舊程序誤認為新版本。
- 測試版應使用該次建置的明確 DerivedData／Products 路徑，避免誤裝其他專案或先前 build。
- 多裝置同步驗證可先建立同一份 generic iOS Simulator 產物，再覆蓋安裝到各目標 Simulator，避免用不同時間的 build 比較畫面。
- UI 驗證至少涵蓋本次受影響的最小與最大目標尺寸。自適應版面修改優先檢查 iPhone 13 mini、約 10 吋 iPad、13 吋 iPad，並依風險增加橫向、深色模式與大字體。
- 螢幕截圖只能證明當時可見狀態；滑動、按鍵、換算與生命週期行為需要實際操作或可重現測試證據。
- Simulator framebuffer 無法自動旋轉時，可在已安裝同一 build 的 App 程序內暫時把既有 root view 設為目標 bounds／safe-area insets，完成 layout 與離屏快照後立刻恢復。此方法只證明指定尺寸下的 SwiftUI 版面，不代表實際旋轉生命週期、系統 chrome 或觸控操作通過。
- 建置或 Simulator 異常耗時時主動介入，保留有用輸出、診斷原因，避免無限等待或重複執行相同失敗步驟。

## 驗證標準

- 驗證強度與修改風險相稱；至少執行受影響組態的 Debug build。
- 發布候選版本應另外執行 Release build，並視修改內容執行 Xcode Analyze、單元測試、UI 測試或代表性冒煙測試。
- 一般回歸測試以 `xcodebuild test -project unitCalc.xcodeproj -scheme unitCalc -destination <已確認的 Simulator>` 執行；測試輸出需保留實際通過案例，不能只以 target 可編譯代替。
- 換算邏輯修改必須用已知案例驗證輸入、輸出與方向，例如基本四則運算及至少一個受影響的跨單位換算。
- 匯率更新修改必須分別驗證：有效快取、過期快取、主要來源成功、主要來源失敗與備援來源、兩者皆失敗時的 UI。
- UI 修改須檢查是否裁切、重疊、誤觸、遮擋滑動，以及狀態切換後提示是否正確消失或出現。
- 若專案尚無正式 test target，可以使用隔離的冒煙測試補足當次證據，但必須在交付時明確說明這不是持久化自動測試套件。

## Push、Archive 與發布

- unitCalc 的正式發布目標固定為 App Store Connect。Archive／Distribute 時選用 App Store Connect 發行路徑與相符的正式簽章，不選 Ad Hoc、Development、Enterprise 或其他側載方式。
- 發布前核對 target、scheme、Bundle ID、marketing version、build number、最低系統版本、簽章 team、distribution method 與 Archive 內容。
- 完整 App Store 流程依序區分：測試完成、Archive 成功、必要的 Validate 成功、上傳成功、App Store Connect 處理並接收 build、metadata 完整、提交審查、通過審查、正式上架。匯出 IPA 不是本專案 App Store 上架的完成條件。
- 不得以 Archive 成功表示已上傳，也不得以上傳成功表示已提交、通過或上架。
- GitHub 用於原始碼與專案文件管理，不把 GitHub Release、IPA 或其他可安裝資產當作 unitCalc 的正式 App 發行管道。除非使用者日後明確改變發行政策，不建立這類替代發布流程。
- GitHub、Keychain、Apple signing 與 App Store Connect 檢查應在具備正確網路與憑證存取權的正式環境執行。受限環境失敗時先辨識是否為環境限制，不立即要求重新登入或更換憑證。
- 對不可逆、法律、金流、憑證、公開發布或代表使用者對外提交的動作，依當次明確授權與工具確認規則執行；一般讀取、檢查與解除非風險阻擋可直接完成。

## 完成與交付報告

- 清楚列出修改檔案、使用者可見行為、驗證裝置／組態、測試結果與尚未驗證的部分。
- 分別陳述工作樹修改、commit、push、Archive、上傳、提交審查與上架狀態，不用模糊的「已發布」概括。
- 若仍有非本次差異、已知警告、外部服務不穩定或測試缺口，交付時明確揭露。
- 未經要求不把暫時實驗、候選方案或失敗診斷寫成正式專案結論。
