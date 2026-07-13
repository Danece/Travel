/// 英文國家名稱 → 繁體中文對照表。
///
/// 用途：將 Nominatim API、CSV 匯入、或資料庫中儲存的英文國家名
/// 轉換為介面顯示用的繁體中文。
/// 無對應條目時，[toChineseName] 直接回傳原始英文，不會拋出錯誤。
const Map<String, String> countryNameMap = {
  // ── 東北亞 ────────────────────────────────────────────────────────────────
  'Taiwan': '台灣',
  'Japan': '日本',
  'South Korea': '韓國',
  'China': '中國',
  'Hong Kong': '香港',
  'Macau': '澳門',
  'Mongolia': '蒙古',

  // ── 東南亞 ────────────────────────────────────────────────────────────────
  'Thailand': '泰國',
  'Vietnam': '越南',
  'Singapore': '新加坡',
  'Malaysia': '馬來西亞',
  'Indonesia': '印尼',
  'Philippines': '菲律賓',
  'Cambodia': '柬埔寨',
  'Myanmar': '緬甸',

  // ── 南亞 ──────────────────────────────────────────────────────────────────
  'India': '印度',
  'Nepal': '尼泊爾',
  'Sri Lanka': '斯里蘭卡',
  'Maldives': '馬爾地夫',
  'Bhutan': '不丹',

  // ── 西歐 ──────────────────────────────────────────────────────────────────
  'United Kingdom': '英國',
  'France': '法國',
  'Germany': '德國',
  'Italy': '義大利',
  'Spain': '西班牙',
  'Portugal': '葡萄牙',
  'Netherlands': '荷蘭',
  'Belgium': '比利時',
  'Switzerland': '瑞士',
  'Austria': '奧地利',
  'Ireland': '愛爾蘭',

  // ── 北歐 ──────────────────────────────────────────────────────────────────
  'Sweden': '瑞典',
  'Norway': '挪威',
  'Denmark': '丹麥',
  'Finland': '芬蘭',
  'Iceland': '冰島',

  // ── 南歐 / 東南歐 ─────────────────────────────────────────────────────────
  'Greece': '希臘',
  'Croatia': '克羅埃西亞',
  'Slovenia': '斯洛維尼亞',

  // ── 中東歐 ────────────────────────────────────────────────────────────────
  'Czech Republic': '捷克',
  'Hungary': '匈牙利',
  'Poland': '波蘭',
  'Slovakia': '斯洛伐克',
  'Romania': '羅馬尼亞',
  'Russia': '俄羅斯',

  // ── 北美洲 ────────────────────────────────────────────────────────────────
  'United States': '美國',
  'Canada': '加拿大',
  'Mexico': '墨西哥',

  // ── 南美洲 ────────────────────────────────────────────────────────────────
  'Brazil': '巴西',
  'Argentina': '阿根廷',
  'Peru': '秘魯',

  // ── 大洋洲 ────────────────────────────────────────────────────────────────
  'Australia': '澳洲',
  'New Zealand': '紐西蘭',

  // ── 中東 ──────────────────────────────────────────────────────────────────
  'United Arab Emirates': '阿聯酋',
  'Israel': '以色列',
  'Jordan': '約旦',
  'Turkey': '土耳其',

  // ── 非洲 ──────────────────────────────────────────────────────────────────
  'Egypt': '埃及',
  'Morocco': '摩洛哥',
  'South Africa': '南非',
  'Kenya': '肯亞',
};

/// 將英文國家名稱轉為繁體中文顯示名稱。
///
/// [countryNameMap] 有對應條目時回傳中文；無對應時直接回傳 [englishName]，
/// 確保即使遇到資料庫中未知的國家名稱也能正常顯示。
String toChineseName(String englishName) =>
    countryNameMap[englishName] ?? englishName;

// 中文 → 英文反向對照（由 countryNameMap 自動產生，避免手動維護兩份資料）
final Map<String, String> _kZhToEn = {
  for (final e in countryNameMap.entries) e.value: e.key,
};

/// 將繁體中文國家名稱轉回英文鍵（資料庫儲存值）。
///
/// 用途：將 GeocodingService 回傳的中文名稱對應回資料庫使用的英文鍵。
/// 無對應時回傳 null（呼叫端應讓使用者手動選擇）。
String? toEnglishName(String chineseName) => _kZhToEn[chineseName];
