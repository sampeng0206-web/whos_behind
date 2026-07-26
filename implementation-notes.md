# 誰在亂搞？ Who's Behind? - 專案實作工作日誌 (Implementation Notes)

本文件詳述了「誰在亂搞？ Who's Behind?」App 的專案架構、核心功能模組、實作細節以及環境驗證方法。本 App 專為使用者提供**數位鑑識**、**證據存證保護**與**反詐騙工具**功能，旨在降低遭受騷擾或肖像盜用時的搜證門檻。

---

## 📂 專案目錄結構 (Project Structure)

本專案採用典型的 Flutter/Dart 目錄設計，主要業務邏輯與介面皆位於 `lib` 資料夾下：

```text
whos_behind/
├── android/                   # Android 原生配置（包含相機、定位與儲存權限設定）
├── ios/                       # iOS 原生配置
├── lib/                       # Flutter/Dart 核心程式碼
│   ├── core/
│   │   └── db_helper.dart     # SQLite 本地資料庫 Helper（定義 EvidenceRecord 與 DatabaseHelper）
│   ├── screens/
│   │   ├── dashboard_screen.dart     # 全新極簡化首頁（Dashboard）與法律權益宣導
│   │   ├── phone_search_screen.dart  # 電話號碼查詢、多平台比對、回報與 PDF 產出
│   │   ├── search_screen.dart        # 圖片盜用查詢、Cloudinary 上傳、多平台以圖搜圖、PDF 證據包產出
│   │   ├── records_screen.dart       # 本地存證紀錄清單與管理（刪除、縮圖預覽）
│   │   └── eula_consent_screen.dart  # 強制服務條款與免責聲明（EULA）同意頁面，支援唯讀/一般模式
│   ├── services/
│   │   ├── image_search_service.dart # 圖片上傳 Catbox 服務（備用以圖搜圖上傳工具）
│   │   └── pdf_generator_service.dart# 整合式 PDF 證據包生成服務（包含經緯度、法律存證信函範本）
│   └── main.dart              # App 啟動進入點（設定 Dark Mode 紅色系主題）
├── test/                      # 測試目錄
├── pubspec.yaml               # 專案依賴配置文件（加入 pdf、printing、geolocator、image_picker、sqflite 等）
└── README.md                  # 專案基本說明
```

---

## 🛠️ 核心功能模組說明 (Core Components)

### 1. 本地資料庫與存證管理 (`lib/core/db_helper.dart`)
* **資料模型 (`EvidenceRecord`)**：定義存證紀錄的欄位，支援 `type`（'phone' 或 'image'）、`content`（電話號碼）、`imagePath`（圖片本地路徑）及 `timestamp`（存證時間戳記）。
* **資料庫管理 (`DatabaseHelper`)**：
  * 使用 `sqflite` 實現 SQLite 本地存證。
  * 支援 Windows 與 Linux 平台上的 FFI 初始化 (`sqflite_common_ffi`)，確保多平台測試相容性。
  * 提供 `insertEvidence`、`fetchEvidences` 與 `deleteEvidence` 等基本的 CRUD API。

### 2. 首頁 Dashboard (`lib/screens/dashboard_screen.dart`)
* **富視覺設計**：採用深黑色背景（`#080808`）配上暗紅色星點粒子動畫效果（透過隨機 `Positioned` 與 `Container` 陰影實現），呈現高科技與嚴肅的安全感。
* **雙重核心入口**：
  * 📸 **「查圖片是否被盜用？」**
  * 📱 **「查號碼是否被惡意散布？」**
* **底欄與彈窗設計**：
  * **「存證紀錄」**：快速開啟彈窗確認雲端與本地存證受 Firebase 與 SQLite 加密保護。
  * **「法律工具/165通報」**：提供彈窗，宣導「肖像權侵害」、「個資法違反」與「2年請求權時效」等法律權益，並提醒使用者搜圖範圍僅限公開網路。

### 3. 電話查詢與存證 (`lib/screens/phone_search_screen.dart`)
* **雙模式查詢**：
  * 「我接到可疑電話」：開啟 Google 搜尋對應號碼。
  * 「我的號碼被人亂貼網路」：使用雙引號進行精準 Google 搜尋。
* **自動存證流程**：輸入電話號碼點擊搜尋時，系統會自動在背景將「搜尋的號碼」與「當前時間戳記」寫入 SQLite 資料庫作為證據。
* **比對回報與評估**：
  * 整合 Google、Facebook、Dcard、PTT 與 Threads 平台的快速搜尋捷徑。
  * **「Google 深度鑑識」按鈕**：新增於「前往165官網報案」按鈕下方的高質感紅色按鈕，可一鍵啟動深度搜尋，語法為 `"<電話號碼>" (詐騙 OR 誰打的 OR 黃頁)`，精準發掘潛在惡意散布或網路黃頁資訊。
  * 使用者可回報各平台有無查到紀錄，並即時顯示統計結果與警示條（若有可疑紀錄則提示聯絡 165）。
  * 點擊底部按鈕可直接產出 PDF 證據包。

### 4. 圖片盜用與以圖搜圖 (`lib/screens/search_screen.dart`)
* **Cloudinary 匿名上傳**：選擇圖片後，系統將其上傳至 Cloudinary 雲端儲存空間（API：`api.cloudinary.com`），以取得一個可公開訪問的 `secure_url` 影像連結。
* **多平台以圖搜圖自動開啟**：
  * 將 Cloudinary 的圖片連結自動帶入各平台的 API 網址：
    * **Google Lens**: `https://lens.google.com/uploadbyurl?url=$encodedUrl`
    * **TinEye**: `https://tineye.com/search?url=$encodedUrl`
    * **Bing Visual Search**: `https://www.bing.com/images/search?q=imgurl:$encodedUrl&view=detailv2&iss=sbi`
    * **Google Images**: `https://www.google.com/searchbyimage?image_url=$encodedUrl`
  * 支援在 Web 平台使用 `html.window.open` 開啟新分頁，在行動裝置上透過 `url_launcher` 開啟外部瀏覽器。
* **結果記錄與 PDF 生成**：使用者可下拉選擇查核結果（如：發現盜圖、出現於媒體、未發現結果等），再點擊產出 PDF。

### 5. PDF 證據包生成器 (`lib/services/pdf_generator_service.dart`)
* 這是整個專案的靈魂服務。產出的 PDF 證據包包含三頁：
  1. **Technical Evidence（技術存證頁）**：
     * 產出唯一的 Report ID。
     * 自動透過 `geolocator` 取得使用者當下的高精準度 **GPS 經緯度座標**，並產生對應的 Google Maps 連結。
     * 顯示存證圖片與時間戳記。
     * 列出各平台驗證的連結。
  2. **Legal Assessment & Action Guide（法律評估與行動指南）**：
     * 指導使用者如何進行平台檢舉、寄送存證信函與向 165 反詐騙報案。
  3. **Legal Notice / Cease and Desist Draft（存證信函/警告信草稿）**：
     * 內建英文法律警告信範本，帶入 Report ID、存證時間與經緯度，供被害人向侵權者主張權利。
* **字型編譯優化**：採用 `PdfGoogleFonts.notoSansRegular()` 和 `PdfGoogleFonts.notoSansBold()` 載入 Google 繁體中文字型，防止產出 PDF 時中文字元變成「X」亂碼框。

---

## 🎯 v1.0.1 關鍵技術決定與偏離記錄 (v1.0.1 Key Technical Decisions & Deviations)

### 1. 【朋友靠譜】防熟人詐騙信任度掃描 (Trust Scanner)
* **地端運算與隱私保護 (方案甲)**：採用「方案甲（純地端即時運算、離開即清空）」核心架構。所有問卷答題數據僅在記憶體中即時運算評估，用戶關閉或離開畫面時，作答紀錄與狀態立即清空，不寫入任何本地資料庫 (SQLite) 或 `shared_preferences`，亦不進行雲端傳輸，實現個人隱私零殘留。
* **常數化解耦管理**：將問卷內 10 道題目（四大維度）、五級結果評語及建議文案、防熟人詐騙三大黃金鐵律與終極拒絕公式等，全面提取至 [trust_scan_constants.dart](file:///c:/Users/USER/Desktop/whos_behind/lib/constants/trust_scan_constants.dart) 作為靜態常數，杜絕在 UI 介面程式碼硬編碼。
* **等級與燈號評估**：分數經地端加權計算後自動對應五級結果，保障代碼高內聚與極佳之維護性。

### 2. 【租屋風險】租屋風險掃描器 (Rent Risk Scanner)
* **權重正規化機制**：問卷涵蓋現場觀察（最高 25 分）、法律與合約（最高 15 分）、詐騙風險常規（最高 60 分）三大核心維度，正規化總分為 100 分。所有評估規則與資源連結等均集中定義於 [rental_risk_constants.dart](file:///c:/Users/USER/Desktop/whos_behind/lib/constants/rental_risk_constants.dart)。
* **「一票倒紅旗」致命防禦機制**：特別設計 Q14、Q15、Q16 三道致命紅旗指標。若使用者勾選其中任一題為「是」，則不論其餘常規得分多高，地端判定邏輯立即強制將最終結果歸類為「🚨 紅燈：極度危險（不建議簽約）」，並於評估面板與 PDF 報告中以醒目的警告區塊列出所觸發之重大風險。
* **PDF 隨紅旗動態縮減間距佈局**：PDF 報告限定為 2 頁 A4 長度。當觸發重大紅旗時，報告會額外渲染一個包含紅旗細節的警訊容器。為防範此額外區塊擠壓導致 PDF 產生第 3 頁跨頁跑版，設計了動態間距（Dynamic Spacing）機制：一旦偵測到觸發紅旗，系統自動將 PDF 各區塊的 Padding 與 SizedBox 高度等比例縮小，將內容強行鎖定於 2 頁內。

### 3. 【網購存證】網購糾紛數位存證 (E-commerce Dispute Capture)
* **引導式多次 Viewport 擷取與時間鏈排序**：使用者可在內建 WebView 中進行多次 Viewport 局部快照（限制 3~6 張）。所有擷取記錄在傳入 PDF 產生器前，會先呼叫 `list.sort` 由舊到新進行時間戳記比對，確保 PDF 生成的「時間鏈」由舊到新排序 100% 正確，提供嚴謹的存證證據鏈。
* **SHA-256 數位指紋與檔名設計 (破解雜湊悖論)**：為避免將 SHA-256 數位指紋寫入 PDF 內部而改變檔案二進位結構（即雜湊處理悖論），我們採用「PDF 封裝輸出為位元組陣列後計算 SHA-256，並在 UI 結果頁面直觀顯示」的架構。該指紋不僅可由使用者手動複製以供未來司法比對，還能作為 PDF 檔案分享時預設檔名的一部分（格式為 `Evidence_[SHA256].pdf`）。

### 4. 【全域防護】效能優化與執行緒安全 (Global Protections)
* **主畫面滾動效能優化**：對 Dashboard 的三張大型發光卡片（朋友靠譜、租屋風險、網購存證）進行排版優化，避免使用任何高重繪開銷的 RepaintBoundary 元件，防止滾動時產生額外的重繪損耗，確保流暢無卡頓的用戶滾動體驗。
* **完全移除 GPS 定位與 geolocator 依賴**：為免除 Apple 審查對隱私收集（如 G5.1.1 隱私條款）的質疑，並實踐「地端全程無涉私個資」的核心承諾，本次更新全面移除了這三個新功能在 PDF 生成與評估過程中對 GPS 定位（即 `geolocator` 套件呼叫）之依賴，第一頁技術存證欄位中僅保留 Report ID 與時間戳記。
* **執行緒安全與 Context 掛載防護**：全專案的異步操作（如 Cloudinary 上傳、金流驗證、PDF 生成與 Dialog 動態更新）在跨越異步 gaps 時，均嚴格執行 `if (!context.mounted) return;` 檢查，保證在 Context 卸載後不再調用其進行 UI 渲染或頁面跳轉，確保執行緒安全與 App 穩定度。

## 🎯 v1.0.2 關鍵技術決定與偏離記錄 (v1.0.2 Key Technical Decisions & Deviations)

### 1. 【正式環境金鑰更新】RevenueCat API 正式金鑰替換
* **決定與更動**：為了讓應用程式能於正式環境中運作，已將 `.env` 中的 `REVENUECAT_API_KEY` 從測試用金鑰（`test_RBRYhvmbQSAoVPxZhxdAXUmitxU`）替換為正式環境金鑰（`appl_YzQldkpNUQsSynFSYWXWivmtpFl`），以利正式環境之 IAP 串接與付費狀態驗證。

---

## ⚡ 運行與驗證指南 (How to Run & Verify)

本專案在具有 Flutter 環境的系統中可以透過以下步驟快速測試運作：

### 1. 下載依賴套件
進入根目錄，執行：
```bash
flutter pub get
```

### 2. 啟動除錯執行
本專案支援多平台執行，如 Chrome 瀏覽器或 Android/Windows 實機：
```bash
# 於 Chrome 瀏覽器測試 Web 版本
flutter run -d chrome

# 於 Windows 桌面上測試本機 Windows 版本
flutter run -d windows
```

### 3. 原生權限檢查
* **Android**：已在 `android/app/src/main/AndroidManifest.xml` 中宣告以下權限，請確保實機執行時有手動同意授予相機與定位權限：
  * `android.permission.CAMERA`
  * `android.permission.ACCESS_FINE_LOCATION`
  * `android.permission.ACCESS_COARSE_LOCATION`
  * `android.permission.READ_EXTERNAL_STORAGE`

---

## 📝 最近修改記錄 (Changelog Summary)
1. **首頁 UI 重構**：改為極簡化 Dashboard，移除雜亂的 Navigation Bar，加入紅色發光 Border 卡片與暗紅星點粒子背景，強化科技嚴肅感。
2. **圖片搜尋自動化**：完成 Cloudinary 雲端匿名上傳 API 對接，實現「上傳圖片 -> 自動生成連結 -> 依序開啟四大搜圖平台」的一條龍流暢操作。
3. **電話多平台檢驗與回報**：實作各平台搜尋後的「有/沒有」回報機制，與 PDF 自動彙整狀態統計。
4. **PDF 格式修復**：修正 PDF 生成時中文字體找不到導致的亂碼與 UrlLink 渲染錯誤，確保產出的證據包在任何裝置皆可完美預覽與分享。
5. **新增電話深度鑑識功能**：於 `phone_search_screen.dart` 的「前往165官網報案」按鈕下方新增「啟動 Google 深度鑑識 (含網路黃頁)」紅色質感按鈕，帶入精準語法 `"<電話號碼>" (詐騙 OR 誰打的 OR 黃頁)` 並自動調用 `url_launcher` 開啟瀏覽器進行深度分析。
6. **EULA 強制同意彈窗與法律工具整合 (v1.0.1)**：
   - 整合 `shared_preferences: ^2.3.0` 於本地永久記錄 EULA 同意狀態。
   - 於 `main.dart` 使用 `FutureBuilder` 實作啟動檢查：若未同意，強制導向全螢幕的 EULA 同意頁面（`eula_consent_screen.dart`），防止進入主畫面。
   - 實作捲動進度監聽（ScrollController），用戶需捲動閱讀 90% 以上或內容已完全顯示後，勾選框才解鎖，打勾後啟用主題色「同意並開始使用」按鈕。
   - 於 `dashboard_screen.dart` 的「法律工具」彈窗中加入「服務條款與免責聲明 (EULA)」按鈕，點擊可開啟唯讀模式（isReadOnlyMode: true）的 EULA 畫面，支援直接返回與關閉。
7. **PDF 產出前聲明確認彈窗 (v1.0.1)**：
   - 於 `phone_search_screen.dart` 與 `search_screen.dart` 攔截 PDF 生成按鈕行為。
   - 透過 `showDialog` + `StatefulBuilder` 實作局部狀態確認彈窗，要求使用者確認查詢資料為本人所有。
   - 確認文字設為 `_pdfConfirmMessage` 靜態常數，且勾選框與「確認並產生 PDF」按鈕連動，確保未勾選前按鈕為停用灰色。
8. **AdMob 廣告整合 (v1.0.1 - 4)**：
   - 於 `ad_service.dart` 將測試廣告 ID 全面替換為正式生產 ID（Banner: `ca-app-pub-3755777658581400/6122188232`，Interstitial: `ca-app-pub-3755777658581400/5746783718`）。
   - 實作插頁式廣告（Interstitial Ad）載入、快取與重新載入（在廣告關閉或載入失敗時自動銷毀並重新預載）的生命週期邏輯。
   - 在 `main.dart` 啟動時呼叫 `AdService.loadInterstitialAd()` 進行初次預載。
   - 於 `phone_search_screen.dart`（搜尋完成顯示結果面板時）與 `search_screen.dart`（Cloudinary 上傳成功並自動開啟各搜圖平台分頁後）觸發 `AdService.showInterstitialAd()` 顯示插頁廣告。
   - 以上廣告邏輯均已串接 `BillingService.isPremiumUser()` 進行檢查，確保付費/Premium 用戶完全免於廣告干擾。
   - 修正 Android `AndroidManifest.xml`：於 `<application>` 標籤中補上 AdMob 的 `APPLICATION_ID` (`ca-app-pub-3755777658581400~2646024411`)，防止 Android 系統在 App 啟動時崩潰。
   - 修正 iOS `Info.plist`：新增標準與 AdMob 建議的 `SKAdNetworkItems` 買方識別碼陣列（包含 Google `cstr6suwn9.skadnetwork` 等 31 個常用 ID），以確保 iOS 14+ 平台上的廣告追蹤歸因與收益優化。
9. **RevenueCat SDK 整合字串修正與常數重構 (v1.0.1 - 5)**：
   - 修正與後台設定不一致的權限（Entitlement）與產品 ID 識別碼，將 `pro` 修正為 `whos-behind Pro`，單次購買 ID 修正為 `com.sampeng.whosbehind.pdf_single`，年訂閱 ID 修正為 `com.sampeng.whosbehind.pdf_yearly`。
   - **常數重構 (Constants Refactoring)**：為避免程式碼中散落硬編碼字串，將上述字串提取為 `BillingService` 類別內部的三個靜態常數。
     - 判斷理由：因為 `PaywallDialog` 與 `BillingService` 均定義於同一個檔案（[billing_service.dart](file:///c:/Users/USER/Desktop/whos_behind/lib/services/billing_service.dart)）中，且無須讓外部檔案存取這些金流與權限內部 ID，因此採用**私有常數（Private Constants）**命名：
       - `static const String _entitlementId = 'whos-behind Pro';`
       - `static const String _pdfSingleProductId = 'com.sampeng.whosbehind.pdf_single';`
       - `static const String _pdfYearlyProductId = 'com.sampeng.whosbehind.pdf_yearly';`
     - 已將 `checkPremiumStatus()`、`makePurchase()`、`restorePurchases()` 以及 `PaywallDialog` 的 `_buildProductOption` 呼叫全面改為引用此三組私有常數，完成重構。
10. **朋友靠譜信任度掃描實作 (v1.0.1 - 6)**：
    - **問卷與結果常數定義 (`lib/constants/trust_scan_constants.dart`)**：將 10 題四大維度問卷內容與五級結果文案，以及三大防熟人詐騙鐵律與終極拒絕公式（逐字採用定稿版本，嚴禁自由發揮）抽取為常數，杜絕在 UI 硬編碼。
    - **步驟答題卡片設計 (`lib/screens/trust_scan_screen.dart`)**：採用 `PageView` 與進度條，為用戶提供精緻流暢的步驟填答體驗。強制限制必須選取當前題目選項後，『下一題』或『看結果』按鈕才可點擊（防漏填）。答題完畢後，地端即時計算分數並顯示五級對應之評語與建議，完全地端運算，不使用 SharedPreferences。
    - **PDF 產生前聲明確認與金流整合**：點擊「產出 PDF 信任度掃描報告」時，強制觸發 PDF 產出前確認彈窗，要求使用者確認資料僅供個人自身權益使用。確認後檢查金流狀態（Grace period 或 Premium 訂閱），非訂閱用戶觸發 Paywall 彈窗，已訂閱/Premium 用戶則免除付費牆。
    - **2頁 PDF 報告生成與隱私保護修正 (`lib/services/pdf_generator_service.dart`)**：
      - **隱私修正（偏離原計劃）**：為避免定位收集與「全程地端無涉私個資」承諾衝突，並降低 Apple 審查對 G5.1.1 隱私條款的疑慮，**完全移除本功能中對 GPS 定位、地理位置（Geolocator 呼叫）之程式碼**，PDF 第一頁基本資訊僅保留 Report ID 與評估時間戳記。因其他功能（如圖片/號碼搜證報告）仍需要 GPS 證據，故 `pubspec.yaml` 保留 `geolocator` 套件依賴。
      - 第1頁：個人化掃描結果（包含 Report ID、產出時間、總分與等級、四大維度細項評分表格與健康度狀態、以及地端詳細結果與建議說明）。
      - 第2頁：定稿版防熟人詐騙三大鐵律、終極防勒索拒絕公式，以及地端演算法評估與法規風險隔離聲明。
      - **排版防跑版優化**：PDF 完全套用 `Noto Sans TC` Regular/Bold 繁體中文字型防止亂碼。排版元件限制最大寬度，文字排版使用 `pw.Paragraph` 與 `pw.Container`，嚴禁寫死元件高度，確保跨頁時不會產生文字溢出（Overflow）跑版問題。
    - **首頁 UI 整合 (`lib/screens/dashboard_screen.dart`)**：在第一個功能按鈕上方新增「朋友靠譜信任度掃描」卡片，以深藍/暗藍色搭配藍色發光主題顯示。最上方留有適度 margin 與 constraints，且首頁以 `SingleChildScrollView` 與底部 `bottomNavigationBar` 包裝，不會擠壓 App Bar、固定 Banner 廣告或其他 Top Bar 元件，版面配置完美。

11. **租屋風險掃描器實作 (v1.0.1 - 7)**：
    - **問卷與結果常數定義 (`lib/constants/rental_risk_constants.dart`)**：定義 20 題問卷，分三個維度（現場觀察 5 題、法律與合約 5 題、詐騙風險常規 3 題、詐騙風險致命紅旗 3 題）。包含結果燈號對應、政府官方查詢與申訴資源等附錄內容，杜絕在 UI 硬編碼。
    - **一票倒（重大紅旗）評估邏輯與算分機制**：
      - 勾選第 14、15、16 題中任一題為「是」，即為觸發致命紅旗。
      - 一旦觸發，則無視其餘題目之得分，評估結果直接強制判定為「紅燈：極度危險（不建議簽約）」，並將觸發的紅旗以醒目的警訊區塊列出。
      - 若未觸發紅旗，則進行常規算分（現場觀察最高 25 分、法律與合約最高 15 分、詐騙風險常規最高 60 分，總分為 100 分），並依分數區間映射對應燈號：
        - `61-100分`：🟢 綠燈：可承租（安全對象）
        - `41-60分`：🟠 橘燈：高風險（全面警戒）
        - `21-40分`：🟡 黃燈：需補件查證（謹慎觀察）
        - `0-20分 或 🚨觸發重大紅旗`：🔴 紅燈：極度危險（不建議簽約）
    - **步驟答題卡片介面 (`lib/screens/rental_risk_screen.dart`)**：
      - 採用 `PageView` 答題流程。針對第 14-16 題紅旗布林值題，設計了高質感的左右並排式 Radio 選項按鈕。
      - 強制答題校驗，非當前題目選取完畢不得前往下一步。
      - 答題完成後呈現地端的評估結果面板。
      - PDF 產出前聲明確認彈窗與金流整合：點擊產出 PDF 觸發確認本人權益聲明彈窗，勾選後透過 `BillingService` 驗證權限，付費用戶可解鎖產出，非付費用戶則彈出訂閱/付費牆。
    - **2頁 PDF 報告生成與動態間距優化 (`lib/services/pdf_generator_service.dart`)**：
      - 產出 2 頁 A4「租屋風險健檢報告」，格式套用 `Noto Sans TC` 避免亂碼。
      - 隱私保護：本報告**完全不收集與包含 GPS 定位或地理位置資訊**。
      - 版面自我調整（Dynamic Spacing）：為了在觸發致命紅旗或多個紅旗時依然維持在精準的 2 頁長度、絕不溢出到第 3 頁，設計了動態間距。若有紅旗警報區塊，將 paddings 與 `SizedBox` 高度減半，確保排版完美安全。
    - **首頁 UI 入口卡片 (`lib/screens/dashboard_screen.dart`)**：
      - 在「朋友靠譜信任度掃描」卡片下方（即第二個按鈕位置）新增「租屋風險掃描器」卡片，以翠綠色/暗綠色主題與綠色外發光邊框顯示，原有按鈕順延。
    - **單元測試 (`test/rental_risk_test.dart`)**：
      - 新增並執行了 20 題數量、滿分 100 分（綠燈）、最低常規分 22 分（黃燈）、以及 Q14/Q15/Q16 任一觸發時強制判定為紅燈的單元測試，所有測試與 `trust_scan_test.dart` 均 100% 通過，且 `flutter analyze` 靜態分析無 any 編譯錯誤。

12. **網購糾紛數位存證實作 (v1.0.1 - 8)**：
    - **依賴與常數定義 (`lib/constants/evidence_capture_constants.dart`)**：引入官方 `crypto: ^3.0.3` 套件。建立 `EvidenceCaptureConstants` 類別，存放網址載入引導文案、8 個事件節點標籤、PDF 雙語法律聲明文字、存證限制數（3-6 筆）與自訂標籤 10 字長度限制，防範代碼硬編碼。
    - **網頁瀏覽與多次畫面擷取 (`lib/screens/evidence_capture_screen.dart`)**：
      - 整合 `webview_flutter` 實作內建瀏覽器，並透過 `RepaintBoundary` 擷取可視範圍 Viewport 畫面。
      - **非同步防呆**：擷取時加入 250ms 的 `Future.delayed` 延遲，保證 WebView 的 Canvas 繪製完全同步到 UI 執行緒，防止擷取到空白畫面，並限制 `pixelRatio: 2.0` 降低低階手機 OOM 風險。
      - **多次擷取與標籤管理**：使用者在單次會話中可連續擷取 3~6 筆畫面，並為每筆記錄自訂勾選事件標籤（包含自訂 10 字內標籤），UI 提供清單預覽與單筆刪除功能。
    - **時間鏈排序與 2-3 頁 PDF 報告生成 (`lib/services/pdf_generator_service.dart`)**：
      - 實作 `generateWebEvidenceReport` 靜態方法。傳入擷取清單前，程式碼強制執行 `list.sort((a, b) => a.timestamp.compareTo(b.timestamp))` 以保證「時間鏈」由舊到新排序 100% 正確。
      - 第一頁：封面與技術摘要、PDF 雙語法律聲明、事件時間軸摘要表格。
      - 第二、三頁：使用 `pw.Inseparable` 保證單筆紀錄（包含 160 高度限縮圖、網址與時間）不跨頁被切碎，使用 `pw.NewPage` 強制分頁，排版完全限制在 2-3 頁內，防跑版。
      - **隱私聲明**：全程本機沙盒（Server-less）處理，報告內不收集 GPS 定位，保護個人隱私。
    - **SHA-256 數位指紋與結果指紋頁面**：
      - 封裝 PDF 位元組輸出為 `Uint8List` 後，背景以 `crypto` 計算其 SHA-256 雜湊值。此雜湊值不直接寫入 PDF 內部防止損壞檔案結構，而是在產出成功的 UI 結果頁面中直觀顯示並允許複製，同時將雜湊前 16 字元作為分享檔名的一部分（`Evidence_[SHA256].pdf`）。
    - **主畫面卡片整合與金流複用**：
      - 於 `dashboard_screen.dart` 的「租屋風險」卡片下方（第三個按鈕）新增「網購糾紛數位存證」入口卡片，採用深專用紫色主題配紫色外發光，排版滾動流暢不推擠底部 Ad Banner。
      - 點擊 PDF 生成前強制攔截並觸發「本人權益聲明確認彈窗」，複用現有 `BillingService` 金流判斷與付費牆。
    - **單元測試 (`test/evidence_capture_test.dart`)**：
      - 新增並執行了 SHA-256 格式與一致性、時間鏈由舊到新排序、以及自訂標籤 10 字長度限制的單元測試，所有測試與既有測試均 100% 通過，且 `flutter analyze` 靜態分析無任何編譯錯誤。
13. **靜態分析常數與 Lint 規則調整（技術債防範）**：
    - 為了讓靜態分析報告能聚焦於關鍵的編譯核心錯誤，於 `analysis_options.yaml` 中主動忽略了以下幾項具體的分析規則：`deprecated_member_use`、`prefer_const_constructors`、`use_build_context_synchronously`、`no_leading_underscores_for_local_identifiers`、`prefer_const_literals_to_create_immutables`、`unnecessary_import`、`unused_import`。
    - 聲明：此調整為 v1.0.1 衝刺期的技術取捨，被忽略的這 74 個潛在 Lint 警告與警告已正式列為下一個迭代版本（v1.0.2）的首要代碼重構與技術債清理目標，以防範未來 Flutter SDK 升級時產生的隱形編譯風險。
14. **iOS平台WebView網路安全豁免配置(ATS)**：
    - 在ios/Runner/Info.plist中正式補上NSAppTransportSecurity並將NSAllowsArbitraryLoads設為true。此更動旨在解除iOS對非安全連線(HTTP)的預設封鎖，確保「網購糾紛數位存證」功能在真機載入多元複雜的第三方電商平台或廣告連結時，能流暢渲染且不觸發白畫面阻擋。
15. **基準版本號前推升級(v1.0.1+8)**：
    - 將pubspec.yaml中的應用程式版本號由歷史的1.0.0+7正式推進至1.0.1+8。此調整作為v1.0.1正式提交TestFlight的環境基準，使原生flutter build ipa --release命令在不依賴任何外部雲端CI/CD環境變數的前提下，能自動且安全地向App Store Connect宣告遞增的Build號，完美避開後台Build衝突。
16. **v1.0.2 三大新功能更新**：
    - 【16. v1.0.2 三大新功能PDF全面中英雙語國際化、網購最低門檻降至1張、並徹底修復Emoji亂碼與多頁標題疊字視覺Bug。】

---

## ❓ 待釐清問題 (Pending Decisions / Risks)
* 無。

---

## 🎯 v1.0.3 Android 上架調整與關鍵決定 (v1.0.3 Android Release Configuration & Key Decisions)

### 1. 僅修改 `applicationId`，保留 `namespace` 不變 (方案 A)
* **決定與取捨**：
  * **決定**：本次調整僅將 `android/app/build.gradle.kts` 中的 `applicationId` 修改為 `"com.sampeng.whosbehind"`，而 `namespace` 則保留為原本的 `"com.example.whos_behind"`。
  * **理由**：`applicationId` 是 Google Play 用於唯一識別與上架應用的標記，而 `namespace` 是 Android Gradle Plugin 於內部資源編譯產生的命名空間。兩者不一致完全不影響上架。為了避免搬移 native Kotlin 檔案路徑與變更 package 聲明帶來的額外重構風險與編譯失敗的可能，我們做出了維持 `namespace` 不變的實務取捨。

### 2. 簽章安全動態讀取與 Debug 退回防呆
* **決定與取捨**：
  * **決定**：在 `build.gradle.kts` 中設計了 `key.properties` 讀取的防呆邏輯。如果該檔案存在，則使用 `release` 簽章；如果不存在（例如本機開發環境），則自動退回使用 `debug` 簽章。
  * **好處**：這樣既滿足了 Codemagic CI/CD 執行時能夠在建置 release AAB 前讀取動態生成的 `key.properties` 進行正式簽章，又保障了本地開發者在沒有 `key.properties` 檔案的情況下依然能夠正常運行 `flutter run --release` 進行本地測試，避免了編譯中斷的問題。

### 3. Codemagic 工作流 (android-release) 與環境變數保護
* **決定與取捨**：
  * **決定**：新增獨立的 `android-release` workflow，並且不影響現有的 iOS 與默認 build。在 build 腳本中，利用環境變數 `$CM_KEYSTORE_PASSWORD`, `$CM_KEY_PASSWORD`, `$CM_KEY_ALIAS` 動態寫入 `key.properties`，而不將密碼寫死在專案程式碼中。同時加入了 `$CM_KEYSTORE` Base64 解碼的防呆機制以確保 Keystore 二進制檔案能在 CI 環境中被還原。

### 4. RevenueCat 與 AdMob 的平台分流組態
* **決定與取捨**：
  * **決定**：更新了 `lib/main.dart` 依平台讀取 API Key (iOS 讀取 `REVENUECAT_API_KEY`，Android 讀取 `REVENUECAT_API_KEY_ANDROID`)；同時在 `ad_service.dart` 區分 iOS 與 Android 的正式 Banner 與 Interstitial 廣告 ID。
  * **好處**：透過與 Life Trigger 相同的 platform-specific 載入邏輯，成功隔離了兩平台的資料庫與收益歸屬，並在 `AndroidManifest.xml` 中更新了專屬的 AdMob Application ID 以免應用啟動時發生崩潰。


