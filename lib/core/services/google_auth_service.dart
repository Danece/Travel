import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

// ── GoogleAuthService ─────────────────────────────────────────────────────────
//
// 封裝 GoogleSignIn，提供：
//   - signIn / signOut / signInSilently
//   - isSignedIn / currentUser
//   - getAuthenticatedClient()：回傳帶有 OAuth 標頭的 HTTP Client，
//     供 googleapis DriveApi 使用
//
// 使用前置設定：
//   Android：android/app/google-services.json（Google Cloud Console 下載）
//   iOS    ：ios/Runner/GoogleService-Info.plist + Info.plist URL Scheme

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const _driveFileScope =
      'https://www.googleapis.com/auth/drive.file';

  final _googleSignIn = GoogleSignIn(scopes: [_driveFileScope]);

  // ── 帳號狀態 ───────────────────────────────────────────────────────────────

  /// 目前登入的 Google 帳號（未登入則為 null）
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// 帳號變更事件流（登入 / 登出 / Token 刷新）
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  // ── 登入 / 登出 ────────────────────────────────────────────────────────────

  /// 互動式登入；使用者取消時回傳 null
  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  /// 靜默恢復上次登入，適合 App 啟動時呼叫
  Future<GoogleSignInAccount?> signInSilently() =>
      _googleSignIn.signInSilently();

  /// 登出目前帳號
  Future<void> signOut() => _googleSignIn.signOut();

  // ── HTTP Client ────────────────────────────────────────────────────────────

  /// 回傳已注入 OAuth Bearer 標頭的 HTTP Client。
  /// 未登入時回傳 null；呼叫前請確認 [isSignedIn]。
  Future<http.Client?> getAuthenticatedClient() async {
    final account =
        _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) return null;

    final headers = await account.authHeaders;
    return _AuthClient(headers);
  }
}

// ── 私有 OAuth HTTP Client ─────────────────────────────────────────────────────
//
// googleapis 套件要求傳入 http.Client；此實作在每個 Request
// 加上 Google OAuth Authorization 標頭。

class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
