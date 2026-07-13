import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 各國首都座標（英文國家名 → LatLng）
const Map<String, LatLng> kCountryCapitals = {
  'Taiwan':        LatLng(25.0330,  121.5654), // 台北
  'Japan':         LatLng(35.6762,  139.6503), // 東京
  'South Korea':   LatLng(37.5665,  126.9780), // 首爾
  'China':         LatLng(39.9042,  116.4074), // 北京
  'Hong Kong':     LatLng(22.3193,  114.1694),
  'Macau':         LatLng(22.1987,  113.5439),
  'Mongolia':      LatLng(47.8864,  106.9057), // 烏蘭巴托
  'Thailand':      LatLng(13.7563,  100.5018), // 曼谷
  'Vietnam':       LatLng(21.0285,  105.8542), // 河內
  'Singapore':     LatLng(1.3521,   103.8198),
  'Malaysia':      LatLng(3.1390,   101.6869), // 吉隆坡
  'Indonesia':     LatLng(-6.2088,  106.8456), // 雅加達
  'Philippines':   LatLng(14.5995,  120.9842), // 馬尼拉
  'Cambodia':      LatLng(11.5564,  104.9282), // 金邊
  'Myanmar':       LatLng(19.7633,   96.0785), // 奈比多
  'India':         LatLng(28.6139,   77.2090), // 新德里
  'Nepal':         LatLng(27.7172,   85.3240), // 加德滿都
  'Sri Lanka':     LatLng(6.9271,    79.8612), // 可倫坡
  'Maldives':      LatLng(4.1755,    73.5093), // 馬列
  'Bhutan':        LatLng(27.4728,   89.6390), // 廷布
  'United Kingdom':LatLng(51.5074,   -0.1278), // 倫敦
  'France':        LatLng(48.8566,    2.3522), // 巴黎
  'Germany':       LatLng(52.5200,   13.4050), // 柏林
  'Italy':         LatLng(41.9028,   12.4964), // 羅馬
  'Spain':         LatLng(40.4168,   -3.7038), // 馬德里
  'Portugal':      LatLng(38.7223,   -9.1393), // 里斯本
  'Netherlands':   LatLng(52.3676,    4.9041), // 阿姆斯特丹
  'Switzerland':   LatLng(46.9481,    7.4474), // 伯恩
  'Austria':       LatLng(48.2082,   16.3738), // 維也納
  'Belgium':       LatLng(50.8503,    4.3517), // 布魯塞爾
  'Sweden':        LatLng(59.3293,   18.0686), // 斯德哥爾摩
  'Norway':        LatLng(59.9139,   10.7522), // 奧斯陸
  'Denmark':       LatLng(55.6761,   12.5683), // 哥本哈根
  'Finland':       LatLng(60.1699,   24.9384), // 赫爾辛基
  'Poland':        LatLng(52.2297,   21.0122), // 華沙
  'Czech Republic':LatLng(50.0755,   14.4378), // 布拉格
  'Hungary':       LatLng(47.4979,   19.0402), // 布達佩斯
  'Greece':        LatLng(37.9838,   23.7275), // 雅典
  'Croatia':       LatLng(45.8150,   15.9819), // 薩格勒布
  'Iceland':       LatLng(64.1355,  -21.8954), // 雷克雅維克
  'United States': LatLng(38.9072,  -77.0369), // 華盛頓特區
  'Canada':        LatLng(45.4215,  -75.6919), // 渥太華
  'Mexico':        LatLng(19.4326,  -99.1332), // 墨西哥城
  'Brazil':        LatLng(-15.7801, -47.9292), // 巴西利亞
  'Argentina':     LatLng(-34.6037, -58.3816), // 布宜諾斯艾利斯
  'Peru':          LatLng(-12.0464, -77.0428), // 利馬
  'Australia':     LatLng(-35.2809, 149.1300), // 坎培拉
  'New Zealand':   LatLng(-41.2865, 174.7762), // 威靈頓
  'UAE':           LatLng(24.4539,   54.3773), // 阿布達比
  'Israel':        LatLng(31.7683,   35.2137), // 耶路撒冷
  'Egypt':         LatLng(30.0444,   31.2357), // 開羅
  'Morocco':       LatLng(34.0209,   -6.8416), // 拉巴特
};
