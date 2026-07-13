// 英文國家名列表（供下拉選單使用，值存入資料庫）
const List<String> kCommonCountries = [
  'Taiwan', 'Japan', 'South Korea', 'China', 'Hong Kong', 'Macau', 'Mongolia',
  'Thailand', 'Vietnam', 'Singapore', 'Malaysia', 'Indonesia',
  'Philippines', 'Cambodia', 'Myanmar',
  'India', 'Nepal', 'Sri Lanka', 'Maldives', 'Bhutan',
  'United Kingdom', 'France', 'Germany', 'Italy', 'Spain',
  'Portugal', 'Netherlands', 'Switzerland', 'Austria', 'Belgium',
  'Sweden', 'Norway', 'Denmark', 'Finland', 'Poland',
  'Czech Republic', 'Hungary', 'Greece', 'Croatia', 'Iceland',
  'United States', 'Canada', 'Mexico', 'Brazil', 'Argentina', 'Peru',
  'Australia', 'New Zealand',
  'UAE', 'Israel',
  'Egypt', 'Morocco',
];

const Map<String, String> _kEnToZh = {
  'Taiwan': '台灣', 'Japan': '日本', 'South Korea': '南韓', 'China': '中國',
  'Hong Kong': '香港', 'Macau': '澳門', 'Mongolia': '蒙古',
  'Thailand': '泰國', 'Vietnam': '越南', 'Singapore': '新加坡',
  'Malaysia': '馬來西亞', 'Indonesia': '印尼', 'Philippines': '菲律賓',
  'Cambodia': '柬埔寨', 'Myanmar': '緬甸',
  'India': '印度', 'Nepal': '尼泊爾', 'Sri Lanka': '斯里蘭卡',
  'Maldives': '馬爾地夫', 'Bhutan': '不丹',
  'United Kingdom': '英國', 'France': '法國', 'Germany': '德國',
  'Italy': '義大利', 'Spain': '西班牙', 'Portugal': '葡萄牙',
  'Netherlands': '荷蘭', 'Switzerland': '瑞士', 'Austria': '奧地利',
  'Belgium': '比利時', 'Sweden': '瑞典', 'Norway': '挪威',
  'Denmark': '丹麥', 'Finland': '芬蘭', 'Poland': '波蘭',
  'Czech Republic': '捷克', 'Hungary': '匈牙利', 'Greece': '希臘',
  'Croatia': '克羅埃西亞', 'Iceland': '冰島',
  'United States': '美國', 'Canada': '加拿大', 'Mexico': '墨西哥',
  'Brazil': '巴西', 'Argentina': '阿根廷', 'Peru': '秘魯',
  'Australia': '澳洲', 'New Zealand': '紐西蘭',
  'UAE': '阿聯', 'Israel': '以色列',
  'Egypt': '埃及', 'Morocco': '摩洛哥',
};

/// 依語系回傳顯示名稱（資料庫固定存英文）
String countryDisplayName(String enName, {required bool isZh}) =>
    isZh ? (_kEnToZh[enName] ?? enName) : enName;

const Map<String, String> _kCountryFlags = {
  // English names
  'Taiwan': '🇹🇼', 'Japan': '🇯🇵', 'South Korea': '🇰🇷', 'China': '🇨🇳',
  'Hong Kong': '🇭🇰', 'Macau': '🇲🇴', 'Mongolia': '🇲🇳',
  'Thailand': '🇹🇭', 'Vietnam': '🇻🇳', 'Singapore': '🇸🇬',
  'Malaysia': '🇲🇾', 'Indonesia': '🇮🇩', 'Philippines': '🇵🇭',
  'Cambodia': '🇰🇭', 'Myanmar': '🇲🇲',
  'India': '🇮🇳', 'Nepal': '🇳🇵', 'Sri Lanka': '🇱🇰',
  'Maldives': '🇲🇻', 'Bhutan': '🇧🇹',
  'United Kingdom': '🇬🇧', 'France': '🇫🇷', 'Germany': '🇩🇪',
  'Italy': '🇮🇹', 'Spain': '🇪🇸', 'Portugal': '🇵🇹',
  'Netherlands': '🇳🇱', 'Switzerland': '🇨🇭', 'Austria': '🇦🇹',
  'Belgium': '🇧🇪', 'Sweden': '🇸🇪', 'Norway': '🇳🇴',
  'Denmark': '🇩🇰', 'Finland': '🇫🇮', 'Poland': '🇵🇱',
  'Czech Republic': '🇨🇿', 'Hungary': '🇭🇺', 'Greece': '🇬🇷',
  'Croatia': '🇭🇷', 'Iceland': '🇮🇸',
  'United States': '🇺🇸', 'Canada': '🇨🇦', 'Mexico': '🇲🇽',
  'Brazil': '🇧🇷', 'Argentina': '🇦🇷', 'Peru': '🇵🇪',
  'Australia': '🇦🇺', 'New Zealand': '🇳🇿',
  'UAE': '🇦🇪', 'Israel': '🇮🇱',
  'Egypt': '🇪🇬', 'Morocco': '🇲🇦',
  // Chinese names
  '台灣': '🇹🇼', '日本': '🇯🇵', '南韓': '🇰🇷', '中國': '🇨🇳',
  '香港': '🇭🇰', '澳門': '🇲🇴', '蒙古': '🇲🇳',
  '泰國': '🇹🇭', '越南': '🇻🇳', '新加坡': '🇸🇬',
  '馬來西亞': '🇲🇾', '印尼': '🇮🇩', '菲律賓': '🇵🇭',
  '柬埔寨': '🇰🇭', '緬甸': '🇲🇲',
  '印度': '🇮🇳', '尼泊爾': '🇳🇵', '斯里蘭卡': '🇱🇰',
  '馬爾地夫': '🇲🇻', '不丹': '🇧🇹',
  '英國': '🇬🇧', '法國': '🇫🇷', '德國': '🇩🇪',
  '義大利': '🇮🇹', '西班牙': '🇪🇸', '葡萄牙': '🇵🇹',
  '荷蘭': '🇳🇱', '瑞士': '🇨🇭', '奧地利': '🇦🇹',
  '比利時': '🇧🇪', '瑞典': '🇸🇪', '挪威': '🇳🇴',
  '丹麥': '🇩🇰', '芬蘭': '🇫🇮', '波蘭': '🇵🇱',
  '捷克': '🇨🇿', '匈牙利': '🇭🇺', '希臘': '🇬🇷',
  '克羅埃西亞': '🇭🇷', '冰島': '🇮🇸',
  '美國': '🇺🇸', '加拿大': '🇨🇦', '墨西哥': '🇲🇽',
  '巴西': '🇧🇷', '阿根廷': '🇦🇷', '秘魯': '🇵🇪',
  '澳洲': '🇦🇺', '紐西蘭': '🇳🇿',
  '阿聯': '🇦🇪', '以色列': '🇮🇱',
  '埃及': '🇪🇬', '摩洛哥': '🇲🇦',
};

String countryFlag(String country) => _kCountryFlags[country] ?? '🌍';
