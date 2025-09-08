import 'dart:io';

/// Resolves a base URL from .env to the correct one for the current platform.
///
/// - Android emulator cannot access 127.0.0.1 of the host; it must use 10.0.2.2
/// - Desktop (Windows/macOS/Linux) should use 127.0.0.1 or localhost
/// - If the .env already points to a remote host, it stays as is
String resolveBaseUrlForPlatform(String rawBaseUrl) {
  Uri uri = Uri.parse(rawBaseUrl);

  // If host is empty or parsing failed, just return what we got
  if (uri.host.isEmpty) return rawBaseUrl;

  // Map localhost/127.0.0.1 for Android emulator
  if (Platform.isAndroid && (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
    uri = uri.replace(host: '10.0.2.2');
    // Ensure trailing slash after path
    if (!(uri.path).endsWith('/')) {
      uri = uri.replace(path: uri.path + '/');
    }
    return uri.toString();
  }

  // If running on desktop and env was set for Android emulator, map back
  if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) && uri.host == '10.0.2.2') {
    uri = uri.replace(host: '127.0.0.1');
    if (!(uri.path).endsWith('/')) {
      uri = uri.replace(path: uri.path + '/');
    }
    return uri.toString();
  }

  // For any other case, ensure a trailing slash on the path
  if (!(uri.path).endsWith('/')) {
    uri = uri.replace(path: uri.path + '/');
    return uri.toString();
  }
  return rawBaseUrl;
}


