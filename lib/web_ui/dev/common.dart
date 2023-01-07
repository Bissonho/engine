// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:path/path.dart' as path;

import 'browser.dart';
import 'browser_lock.dart';
import 'chrome.dart';

/// The port number for debugging.
const int kDevtoolsPort = 12345;
const int kMaxScreenshotWidth = 1024;
const int kMaxScreenshotHeight = 1024;

abstract class PlatformBinding {
  static PlatformBinding get instance {
    return _instance ??= _createInstance();
  }

  static PlatformBinding? _instance;

  static PlatformBinding _createInstance() {
    if (io.Platform.isWindows) {
      return WindowsPlatformBinding();
    }
    throw UnsupportedError('${io.Platform.operatingSystem} is not supported');
  }

  String getChromeBuild(ChromeLock chromeLock);
  String getChromeDownloadUrl(String version);
  String getChromeDriverDownloadUrl(String version);
  String getFirefoxDownloadUrl(String version);
  String getFirefoxDownloadFilename(String version);
  String getChromeExecutablePath(io.Directory versionDir);
  String getFirefoxExecutablePath(io.Directory versionDir);
  String getFirefoxLatestVersionUrl();
  String getMacApplicationLauncher();
  String getCommandToRunEdge();
}

const String _kBaseDownloadUrl =
    'https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o';

class WindowsPlatformBinding implements PlatformBinding {
  @override
  String getChromeBuild(ChromeLock chromeLock) {
    return chromeLock.windows;
  }

  @override
  String getChromeDownloadUrl(String version) =>
      'https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Win%2F$version%2Fchrome-win.zip?alt=media';

  @override
  String getChromeDriverDownloadUrl(String version) =>
      'https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Win%2F$version%2Fchromedriver_win32.zip?alt=media';

  @override
  String getChromeExecutablePath(io.Directory versionDir) =>
      path.join(versionDir.path, 'chrome.exe');

  @override
  String getFirefoxDownloadUrl(String version) =>
      'https://download-installer.cdn.mozilla.net/pub/firefox/releases/$version/win64/en-US/'
      '${getFirefoxDownloadFilename(version)}';

  @override
  String getFirefoxDownloadFilename(String version) => 'firefox-$version.exe';

  @override
  String getFirefoxExecutablePath(io.Directory versionDir) =>
      path.join(versionDir.path, 'firefox', 'firefox');

  @override
  String getFirefoxLatestVersionUrl() =>
      'https://download.mozilla.org/?product=firefox-latest&os=win&lang=en-US';

  @override
  String getMacApplicationLauncher() =>
      throw UnsupportedError('Safari is not supported on Windows');

  @override
  String getCommandToRunEdge() => 'MicrosoftEdgeLauncher';
}

class BrowserInstallation {
  const BrowserInstallation({
    required this.version,
    required this.executable,
  });

  /// Browser version.
  final String version;

  /// Path the browser executable.
  final String executable;
}

/// A string sink that swallows all input.
class DevNull implements StringSink {
  @override
  void write(Object? obj) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? obj = '']) {}
}

/// Whether the felt command is running on Cirrus CI.
bool get isCirrus => io.Platform.environment['CIRRUS_CI'] == 'true';

/// Whether the felt command is running on LUCI.
bool get isLuci => io.Platform.environment['LUCI_CONTEXT'] != null;

/// Whether the felt command is running on one of the Continuous Integration
/// environements.
bool get isCi => isCirrus || isLuci;

const String kChrome = 'chrome';
const String kEdge = 'edge';
const String kFirefox = 'firefox';
const String kSafari = 'safari';

const List<String> kAllBrowserNames = <String>[
  kChrome,
  kEdge,
  kFirefox,
  kSafari,
];

/// Creates an environment for a browser.
///
/// The [browserName] matches the browser name passed as the `--browser` option.
BrowserEnvironment getBrowserEnvironment(String browserName, { required bool enableWasmGC }) {
  switch (browserName) {
    case kChrome:
      return ChromeEnvironment(enableWasmGC);
    case kEdge:
      return EdgeEnvironment();
    case kFirefox:
      return FirefoxEnvironment();
    case kSafari:
      return SafariMacOsEnvironment();
  }
  throw UnsupportedError('Browser $browserName is not supported.');
}
