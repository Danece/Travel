import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('zh', 'TW'));
  }

  static const delegate = _AppLocalizationsDelegate();

  bool get isEn => locale.languageCode == 'en';

  // ── Navigation ────────────────────────────────────────────────────────────
  String get navHome => isEn ? 'Home' : '首頁';
  String get navMarkers => isEn ? 'Markers' : '標記';
  String get navMap => isEn ? 'Map' : '地圖';
  String get navSettings => isEn ? 'Settings' : '設定';

  // ── Common ────────────────────────────────────────────────────────────────
  String get cancel => isEn ? 'Cancel' : '取消';
  String get confirm => isEn ? 'Confirm' : '確認';
  String get delete => isEn ? 'Delete' : '刪除';
  String get save => isEn ? 'Save' : '儲存';
  String get retry => isEn ? 'Retry' : '重試';
  String get gotIt => isEn ? 'Got it' : '知道了';
  String get errorPrefix => isEn ? 'Error: ' : '錯誤：';
  String get loadFailed => isEn ? 'Load failed' : '載入失敗';
  String get signIn => isEn ? 'Sign In' : '登入';
  String get signOut => isEn ? 'Sign Out' : '登出';
  String get processing => isEn ? 'Processing...' : '處理中…';

  // ── Home page ─────────────────────────────────────────────────────────────
  String get homeSubtitle => isEn ? 'Record every precious journey' : '記錄每一段珍貴旅程';
  String get homeQuickActions => isEn ? 'Quick Actions' : '快速入口';
  String get homeAddMarker => isEn ? 'Add Marker' : '新增標記';
  String get homeSearchRecords => isEn ? 'Search Records' : '查詢紀錄';
  String get homeOpenMap => isEn ? 'Open Map' : '開啟地圖';
  String get homeStats => isEn ? 'Statistics' : '統計概覽';
  String get homeRecentAdded => isEn ? 'Recently Added' : '最近新增';
  String get homeViewAll => isEn ? 'View All' : '查看全部';
  String get homeNoRecords => isEn ? 'No travel records' : '尚無旅遊紀錄';
  String get homeStartRecord => isEn ? 'Tap "Add Marker" to start recording' : '點擊「新增標記」開始記錄旅程';
  String get homeTotalMarkers => isEn ? 'Travel Footprints' : '旅遊足跡';
  String get homeTotalCountries => isEn ? 'Countries Visited' : '造訪國家';
  String get homeAvgRating => isEn ? 'Average Rating' : '平均評分';
  String get homeTopCategory => isEn ? 'Top Category' : '熱門種類';
  String get footprintDistrib => isEn ? 'Footprint Distribution' : '旅遊足跡分佈';
  String countriesListTitle(int n) => isEn ? 'Countries Visited ($n)' : '造訪國家清單（$n 個）';
  String get ratingDistrib => isEn ? 'Rating Distribution' : '評分分佈';
  String get categoryDistrib => isEn ? 'Category Distribution' : '標記種類分佈';
  String recordCount(int n) => isEn ? '$n records' : '$n 筆';

  // ── Marker list page ──────────────────────────────────────────────────────
  String get markerPageTitle => isEn ? 'Travel Markers' : '旅遊地標';
  String get searchHint => isEn ? 'Search marker name...' : '搜尋地標名稱…';
  String get clearSearch => isEn ? 'Clear search' : '清除搜尋';
  String get filterCountry => isEn ? 'Country' : '國家';
  String get filterRating => isEn ? 'Rating' : '評分';
  String get filterDate => isEn ? 'Date' : '日期';
  String get filterCategory => isEn ? 'Category' : '種類';
  String get clearFilters => isEn ? 'Clear Filters' : '清除篩選';
  String get noRecordsYet => isEn ? 'No travel records' : '尚無旅遊紀錄';
  String get startRecording => isEn ? 'Tap below to start recording your travel footprints' : '點擊下方按鈕開始記錄您的旅遊足跡';
  String get addNow => isEn ? 'Add Now' : '立即新增';
  String get addMarker => isEn ? 'Add Marker' : '新增地標';
  String get deleteMarker => isEn ? 'Delete Marker' : '刪除地標';
  String deleteMarkerConfirm(String title) => isEn ? 'Delete "$title"?' : '確定要刪除「$title」嗎？';
  String get filterCountryTitle => isEn ? 'Filter by Country' : '篩選國家';
  String get filterMinRating => isEn ? 'Minimum Rating' : '最低評分';
  String starsAbove(int n) => isEn ? '$n★ and above' : '$n★ 以上';
  String get selectDateRange => isEn ? 'Select Date Range' : '選擇拜訪日期區間';
  String get filterCategoryTitle => isEn ? 'Filter by Category' : '篩選種類';
  String filterCountryActive(int n) => isEn ? 'Country ($n)' : '國家（$n）';
  String filterCategoryActive(int n) => isEn ? 'Category ($n)' : '種類（$n）';
  String get swipeToDelete => isEn ? 'Delete' : '刪除';

  // ── Create / Edit marker page ─────────────────────────────────────────────
  String get createMarkerTitle => isEn ? 'Add Marker' : '新增地標';
  String get editMarkerTitle => isEn ? 'Edit Marker' : '編輯地標';
  String get saving => isEn ? 'Saving...' : '儲存中…';
  String get saveMarker => isEn ? 'Save Marker' : '儲存地標';
  String get saveChanges => isEn ? 'Save Changes' : '儲存變更';
  String get basicInfo => isEn ? 'Basic Info' : '基本資訊';
  String get titleField => isEn ? 'Title *' : '標題 *';
  String get titleHint => isEn ? 'e.g. Tokyo Tower' : '例：東京鐵塔';
  String get countryField => isEn ? 'Country *' : '國家 *';
  String get selectCountry => isEn ? 'Select Country' : '請選擇國家';
  String get visitDate => isEn ? 'Visit Date' : '拜訪日期';
  String get selectDate => isEn ? 'Select visit date' : '選擇拜訪日期';
  String get overallRating => isEn ? 'Overall Rating' : '整體評分';
  String get markerCategory => isEn ? 'Category' : '標記種類';
  String get coordinates => isEn ? 'Coordinates' : '座標位置';
  String get latitude => isEn ? 'Latitude *' : '緯度 *';
  String get latHint => isEn ? 'e.g. 25.0330' : '例：25.0330';
  String get longitude => isEn ? 'Longitude *' : '經度 *';
  String get lngHint => isEn ? 'e.g. 121.5654' : '例：121.5654';
  String get pickOnMap => isEn ? 'Pick on Map' : '使用地圖選取座標';
  String get travelNotes => isEn ? 'Travel Notes' : '旅遊心得';
  String get notesHint => isEn ? 'Record your experience, recommendations...' : '記錄這次旅遊的感受、推薦理由…';
  String travelPhotos(int count, int max) => isEn ? 'Photos ($count/$max)' : '旅遊照片（$count/$max）';
  String get fromGallery => isEn ? 'Choose from Gallery' : '從相簿選取';
  String get multipleSelection => isEn ? 'Multiple selection supported' : '可一次選取多張';
  String get takePhoto => isEn ? 'Take Photo' : '拍照';
  String get addPhoto => isEn ? 'Add Photo' : '新增照片';
  String get cover => isEn ? 'Cover' : '封面';
  String maxPhotosReached(int n) => isEn ? 'Max $n photos reached' : '最多只能新增 $n 張照片';
  String onlyAddedFirst(int n) => isEn ? 'Max reached, only added first $n' : '已達上限，僅新增前 $n 張';
  String get markerSaved => isEn ? 'Marker saved!' : '地標已儲存！';
  String get markerUpdated => isEn ? 'Marker updated!' : '地標已更新！';
  String saveFailed(String e) => isEn ? 'Save failed: $e' : '儲存失敗：$e';
  String updateFailed(String e) => isEn ? 'Update failed: $e' : '更新失敗：$e';
  String get titleRequired => isEn ? 'Please enter title' : '請輸入標題';
  String get countryRequired => isEn ? 'Please select country' : '請選擇國家';
  String get dateRequired => isEn ? 'Please select visit date' : '請選擇拜訪日期';
  String get latRequired => isEn ? 'Please enter latitude' : '請輸入緯度';
  String get lngRequired => isEn ? 'Please enter longitude' : '請輸入經度';
  String get formatError => isEn ? 'Invalid format' : '格式錯誤';

  // ── Marker detail page ────────────────────────────────────────────────────
  String get editTooltip => isEn ? 'Edit' : '編輯';
  String get deleteTooltip => isEn ? 'Delete' : '刪除';
  String get countryLabel => isEn ? 'Country' : '國家';
  String get dateLabel => isEn ? 'Date' : '日期';
  String get categoryLabel => isEn ? 'Type' : '種類';
  String get ratingLabel => isEn ? 'Rating' : '評分';
  String get coordsLabel => isEn ? 'Coords' : '座標';
  String get travelNotesSection => isEn ? 'Travel Notes' : '旅遊心得';
  String get noPhotos => isEn ? 'No photos' : '尚無照片';
  String get longPressHint => isEn ? 'Long press to remove photo' : '長按照片可移除';
  String get removePhoto => isEn ? 'Remove Photo' : '移除照片';
  String get removePhotoConfirm => isEn ? 'Remove this photo?' : '確定要移除這張照片嗎？';
  String get remove => isEn ? 'Remove' : '移除';
  String get deleteMarkerTitle => isEn ? 'Delete Marker' : '刪除地標';
  String deleteMarkerContent(String title) =>
      isEn ? 'Delete "$title"?\nThis cannot be undone.' : '確定要刪除「$title」嗎？\n此操作無法復原。';
  String addPhotoCount(int count, int max) => isEn ? 'Add Photo ($count / $max)' : '新增照片（$count / $max）';
  String maxPhotosLabel(int max) => isEn ? 'Max $max photos reached' : '已達照片上限（$max 張）';

  // ── Settings page ─────────────────────────────────────────────────────────
  String get settingsTitle => isEn ? 'Settings' : '設定';
  String get appearance => isEn ? 'Appearance' : '外觀';
  String get themeMode => isEn ? 'Theme Mode' : '主題模式';
  String get themeSystem => isEn ? 'System' : '跟隨系統';
  String get themeLight => isEn ? 'Light' : '淺色';
  String get themeDark => isEn ? 'Dark' : '深色';
  String get themeColorful => isEn ? 'Colorful' : '繽紛';
  String get language => isEn ? 'Language' : '語言';
  String get displayLanguage => isEn ? 'Display Language' : '顯示語言';
  String get backup => isEn ? 'Backup' : '備份';
  String get autoBackupFrequency => isEn ? 'Auto Backup Frequency' : '自動備份頻率';
  String get autoBackup => isEn ? 'Auto Backup' : '自動備份';
  String get autoBackupSubtitle => isEn ? 'Auto backup to Google Drive at set frequency' : '依所選頻率自動備份至 Google Drive';
  String get dataTools => isEn ? 'Data Tools' : '資料工具';
  String get excelExportImport => isEn ? 'Excel Export / Import' : 'Excel 匯出 / 匯入';
  String get excelSubtitle => isEn ? 'Export markers to .xlsx or import from file' : '將地標資料匯出為 .xlsx 或從檔案匯入';
  String get backupRestore => isEn ? 'Backup & Restore' : '備份與還原';
  String get backupRestoreSubtitle => isEn ? 'Backup to Google Drive or restore from backup' : '備份至 Google Drive 或從備份還原';
  String get about => isEn ? 'About' : '關於';
  String get versionLabel => isEn ? 'Version' : '版本';
  String get copyrightLabel => isEn ? 'Copyright' : '著作權';
  String get licenses => isEn ? 'Open Source Licenses' : '第三方套件聲明';
  String get freqOff => isEn ? 'Off' : '關閉';
  String get freqDaily => isEn ? 'Daily' : '每日';
  String get freqWeekly => isEn ? 'Weekly' : '每週';
  String get freqMonthly => isEn ? 'Monthly' : '每月';
  String get needGoogleSignIn => isEn ? 'Google Sign-In Required' : '需要 Google 登入';
  String get needGoogleSignInContent =>
      isEn ? 'Auto backup requires Google account authorization.\nSign in now?' : '自動備份需要 Google 帳號授權。\n是否立即登入？';

  // ── Backup page ───────────────────────────────────────────────────────────
  String get backupPageTitle => isEn ? 'Backup & Restore' : '備份與還原';
  String get googleDriveBackup => isEn ? 'Google Drive Backup' : 'Google Drive 備份';
  String get signInToUseBackupDesc =>
      isEn ? 'Sign in to Google to backup to Drive,\nrestoreable on any device.' : '登入 Google 帳號以將備份儲存至 Drive，\n可在任何裝置還原您的旅遊資料。';
  String get signInGoogle => isEn ? 'Sign in with Google' : '登入 Google 帳號';
  String get signInFirst => isEn ? 'Please sign in to Google to use backup features' : '請先登入 Google 帳號以使用備份功能';
  String get backupNow => isEn ? 'Backup Now' : '立即備份';
  String get backingUp => isEn ? 'Backing up...' : '備份中…';
  String get backupHistory => isEn ? 'Backup History' : '備份歷史';
  String get noBackupRecords => isEn ? 'No backup records' : '尚無備份紀錄';
  String get createFirstBackup => isEn ? 'Tap "Backup Now" to create your first backup' : '點擊「立即備份」建立第一份備份';
  String get deleteBackup => isEn ? 'Delete Backup' : '刪除備份';
  String deleteBackupConfirm(String name) =>
      isEn ? 'Delete "$name"? This cannot be undone.' : '確定刪除「$name」？此操作無法復原。';
  String get confirmRestore => isEn ? 'Confirm Restore' : '確認還原';
  String restoreConfirm(String name) =>
      isEn ? 'Overwrite all data with "$name".\nThis cannot be undone. Continue?' : '將以「$name」覆蓋目前所有資料。\n此操作無法復原，確定繼續嗎？';
  String get confirmRestoreBtn => isEn ? 'Restore' : '確認還原';
  String backupDone(String name) => isEn ? 'Backup complete: $name' : '備份完成：$name';
  String get deleteFailed => isEn ? 'Delete failed, please try again' : '刪除失敗，請重試';
  String get restoreSuccess => isEn ? 'Restore successful! All marker data updated' : '還原成功！所有地標資料已更新';
  String get signInCancelled => isEn ? 'Google sign-in cancelled or failed, please try again' : 'Google 登入取消或失敗，請重試';

  // ── Excel page ────────────────────────────────────────────────────────────
  String get excelPageTitle => isEn ? 'Excel Export / Import' : 'Excel 匯出 / 匯入';
  String get excelFormatInfo => isEn ? 'Excel Format Info' : 'Excel 格式說明';
  String get excelFormatContent => isEn
      ? 'Supported: .xlsx, .xls\n'
          'Export columns: ID, Title, Country, Date, Latitude, Longitude, Rating, Notes, Photo Count, Category\n'
          'Required for import: Title, Country, Latitude, Longitude, Rating (1–5)\n'
          'Date format: yyyy-MM-dd (e.g. 2024-04-15)\n'
          'Photo paths not exported; cross-device paths are invalid'
      : '支援格式：.xlsx、.xls\n'
          '匯出欄位：ID、標題、國家、建立日期、緯度、經度、評分、心得內容、照片數量、種類\n'
          '匯入必填：標題、國家、緯度、經度、評分（1–5）\n'
          '日期格式：yyyy-MM-dd（例：2024-04-15）\n'
          '照片路徑不匯出，跨裝置路徑無效';
  String get exportSection => isEn ? 'Export' : '匯出';
  String get exportButton => isEn ? 'Export to Excel (.xlsx)' : '匯出為 Excel（.xlsx）';
  String get importSection => isEn ? 'Import' : '匯入';
  String get importButton => isEn ? 'Select .xlsx / .xls file to import' : '選取 .xlsx / .xls 檔案並匯入';
  String get importComplete => isEn ? 'Import Complete' : '匯入完成';
  String get importSuccess => isEn ? 'Imported successfully' : '成功匯入';
  String get importSkipped => isEn ? 'Skipped (empty rows)' : '跳過（空白列）';
  String get importValidationFailed => isEn ? 'Validation failed' : '驗證失敗';
  String get noneLabel => isEn ? 'None' : '無';
  String importFailedCount(int n) => isEn ? 'Validation failed ($n)' : '驗證失敗（$n 筆）';
  String get cannotGetFilePath => isEn ? 'Cannot get file path, please try again' : '無法取得檔案路徑，請重試';
  String savedTo(String path) => isEn ? 'Saved to $path' : '已儲存至 $path';
  String unknownError(int row) => isEn ? 'Row $row: Unknown error' : '第 $row 列：未知錯誤';

  // ── Map page ──────────────────────────────────────────────────────────────
  String get mapPageTitle => isEn ? 'Map Overview' : '地圖總覽';
  String get locationPermission => isEn ? 'Location Permission Required' : '需要位置權限';
  String get locationPermissionContent =>
      isEn ? 'Location is disabled. Please go to system settings to enable location access.' : '定位功能已被關閉，請前往系統設定開啟位置存取權限。';
  String get goToSettings => isEn ? 'Go to Settings' : '前往設定';
  String get mapFilterTooltip => isEn ? 'Filter markers' : '篩選顯示標記';
  String get mapFilterTitle => isEn ? 'Filter Options' : '篩選顯示條件';
  String get mapCountryMultiSelect => isEn ? 'Country (multi-select)' : '國家（可多選）';
  String mapCountriesCount(int n) => isEn ? '$n countries' : '$n 個國家';
  String mapFilterActive(String s) => isEn ? 'Filtered: $s' : '篩選中：$s';
  String get resetFilter => isEn ? 'Reset' : '重置';
  String get applyFilter => isEn ? 'Apply Filter' : '套用篩選';

  // ── Rating labels ─────────────────────────────────────────────────────────
  List<String> get ratingLabels => isEn
      ? ['Poor', 'Fair', 'Good', 'Recommend', 'Must Visit!']
      : ['很差', '普通', '不錯', '推薦', '必去！'];
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
