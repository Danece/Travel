import 'country_flag.dart';

// 以中文國家名稱為鍵的旗幟 emoji 對照表。
//
// 資料庫以英文名稱儲存，UI 有時需直接以中文查旗幟（例如從 Nominatim
// 逆地理編碼取得的地名），因此獨立提供此介面。
//
// 若輸入的名稱在 [_kZhFlags] 中無對應，退回使用 [country_flag.dart]
// 的 [countryFlag]（同樣支援中英文查詢），仍無對應則回傳 🌍。

/// 中文別名補充表：僅補充與 [country_flag.dart] 用詞不同的別名，
/// 避免在兩個檔案重複維護所有條目。
const Map<String, String> _kZhAliases = {
  '韓國': '🇰🇷',   // country_flag.dart 用「南韓」，此處補充常用別名
  '阿聯酋': '🇦🇪', // country_flag.dart 已有，此處明確列出方便查閱
};

/// 依中文國家名稱回傳旗幟 emoji。
///
/// 查詢順序：
/// 1. 先在 [_kZhAliases] 中找別名（補充與 [country_flag.dart] 用詞不同的條目）
/// 2. 再透過 [countryFlag] 查詢（涵蓋中英文名稱）
/// 3. 無對應時回傳 🌍
///
/// 範例：
/// ```dart
/// getCountryFlag('台灣')   // 🇹🇼
/// getCountryFlag('韓國')   // 🇰🇷
/// getCountryFlag('未知地點') // 🌍
/// ```
String getCountryFlag(String countryName) =>
    _kZhAliases[countryName] ?? countryFlag(countryName);
