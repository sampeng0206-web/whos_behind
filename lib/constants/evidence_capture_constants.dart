class EvidenceCaptureConstants {
  static const String pageTitle = '網購糾紛數位存證';
  static const String guideMessage = '請貼上或輸入爭議網址，載入網頁後，捲動網頁至您要存證的爭議畫面（如商品說明、賣家承諾或對話紀錄），然後點擊「擷取此畫面」按鈕。';
  
  static const List<String> nodeTags = [
    '商品頁面',
    '賣家資訊／評價',
    '對話紀錄（客服/LINE）',
    '訂單成立畫面',
    '付款成功畫面',
    '收到商品照片',
    '瑕疵/問題照片',
    '其他',
  ];

  static const String pdfTitle = '誰在亂搞？ —— 網購糾紛數位存證報告';
  
  static const String pdfLegalStatement = 
      '本報告由『誰在亂搞？』App 內建瀏覽器於使用者操作當下即時擷取畫面，並記錄原始網址與系統時間戳記，全程於使用者裝置本機完成，未經第三方伺服器處理或人工修圖。本 PDF 檔案之 SHA-256 數位指紋可作為『報告產出後未經變動』之佐證。';

  static const int minCaptures = 1;
  static const int maxCaptures = 6;
  static const int maxCustomTagLength = 10;
}
