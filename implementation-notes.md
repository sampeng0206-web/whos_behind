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
│   │   └── records_screen.dart       # 本地存證紀錄清單與管理（刪除、縮圖預覽）
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
