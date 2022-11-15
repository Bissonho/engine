// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(yjbanov): rename this file to web_only_api.dart.
//                https://github.com/flutter/flutter/issues/100394
//                Rather than extending this file with new APIs, we
//                should instead use js interop.

// This file contains extra web-only API that non-web engines do not have.
//
// Why have web-only API?
//
// Because all Dart code is compiled (and tree shaken) as a single compilation
// unit it only has one entry-point - the `main()` function of the Flutter
// app. The top-level `main()` is generated by Flutter tool and it needs to
// ask the engine to initialize itself before calling the handwritten `main()`
// function of the app itself. To do that, it needs something to call. The
// mobile engine doesn't provide a function like that because the application
// starts from the Java (Android) or Objective-C (iOS). Any initial
// configuration can be done in Java and the engine's C++ code prior to
// calling Dart's `main()`.

part of ui;

/// Performs one-time initialization of the web environment that supports the
/// Flutter framework.
///
/// This is only available on the Web, as native Flutter configures the
/// environment in the native embedder.
Future<void> webOnlyInitializePlatform() async {
  await engine.initializeEngine();
}

/// Initializes essential bits of the engine before it fully initializes.
/// When [didCreateEngineInitializer] is set, it delegates engine initialization
/// and app startup to the programmer.
/// Else, it immediately triggers the full engine + app bootstrap.
///
/// This method is called by the flutter_tools package, from the entrypoint that
/// it generates around the main method provided by the programmer. See:
/// * https://github.com/flutter/flutter/blob/2bd3e0d914854aa8c12e933f25c5fd8532ae5571/packages/flutter_tools/lib/src/build_system/targets/web.dart#L135-L163
/// * https://github.com/flutter/flutter/blob/61fb2de52c7bdac19b7f2f74eaf3f11237e1e91d/packages/flutter_tools/lib/src/isolated/resident_web_runner.dart#L460-L485
///
/// This function first calls [engine.initializeEngineServices] so the engine
/// can prepare the js-interop layer that is used by web apps (instead of the
/// old `ui.webOnlyFoo` methods/getters).
///
/// It then creates a JsObject that is passed to the [didCreateEngineInitializer]
/// JS callback, to delegate bootstrapping the app to the programmer.
///
/// If said callback is not defined, this assumes that the Flutter Web app is
/// initializing "automatically", as was normal before this feature was
/// introduced. This will immediately run the initEngine and runApp methods
/// (via [engine.AppBootstrap.now]).
///
/// This is the only bit of `dart:ui` that should be directly called by Flutter
/// web apps. Everything else should go through the JS-interop layer created in
/// `engine.warmup`.
///
/// This method should NOT trigger the download of any additional resources
/// (except when the app is in "autoStart" mode).
Future<void> webOnlyWarmupEngine({
  Function? registerPlugins,
  Function? runApp,
}) async {
  // Create the object that knows how to bootstrap an app from JS and Dart.
  final engine.AppBootstrap bootstrap = engine.AppBootstrap(
    initEngine: () async {
      await engine.initializeEngineServices();
    },
    runApp: () async {
      if (registerPlugins != null) {
        registerPlugins();
      }
      await engine.initializeEngineUi();
      if (runApp != null) {
        runApp();
      }
    },
  );

  // Should the app "autoStart"?
  bool autoStart = true;
  if (engine.flutter != null && engine.loader != null) {
    autoStart = engine.didCreateEngineInitializer == null;
  }
  if (autoStart) {
    // The user does not want control of the app, bootstrap immediately.
    print('Flutter Web Bootstrap: Auto');
    await bootstrap.autoStart();
  } else {
    // Yield control of the bootstrap procedure to the user.
    print('Flutter Web Bootstrap: Programmatic');
    engine.didCreateEngineInitializer!(bootstrap.prepareEngineInitializer());
  }
}

/// Emulates the `flutter test` environment.
///
/// When set to true, the engine will emulate a specific screen size, and always
/// use the "Ahem" font to reduce test flakiness and dependence on the test
/// environment.
bool get debugEmulateFlutterTesterEnvironment =>
    _debugEmulateFlutterTesterEnvironment;
set debugEmulateFlutterTesterEnvironment(bool value) {
  _debugEmulateFlutterTesterEnvironment = value;
  if (_debugEmulateFlutterTesterEnvironment) {
    const Size logicalSize = Size(800.0, 600.0);
    engine.window.webOnlyDebugPhysicalSizeOverride =
        logicalSize * window.devicePixelRatio;
  }
  engine.debugDisableFontFallbacks = value;
}

bool _debugEmulateFlutterTesterEnvironment = false;

/// Provides the asset manager.
// TODO(yjbanov): this function should not return a private type. Instead, we
//                should create a public interface for the returned value that's
//                implemented by the engine.
//                https://github.com/flutter/flutter/issues/100394
//engine.AssetManager get webOnlyAssetManager => engine.assetManager;

/// Sets the handler that forwards platform messages to web plugins.
///
/// This function exists because unlike mobile, on the web plugins are also
/// implemented using Dart code, and that code needs a way to receive messages.
void webOnlySetPluginHandler(
    Future<void> Function(String, ByteData?, PlatformMessageResponseCallback?)
        handler) {
  engine.pluginMessageCallHandler = handler;
}

/// A registry for factories that create platform views.
class PlatformViewRegistry {
  /// Register [viewTypeId] as being creating by the given [viewFactory].
  /// [viewFactory] can be any function that takes an integer and returns an
  /// `HTMLElement` DOM object.
  bool registerViewFactory(
      String viewTypeId, Object Function(int viewId) viewFactory,
      {bool isVisible = true}) {
    // TODO(web): Deprecate this once there's another way of calling `registerFactory` (js interop?)
    return engine.platformViewManager
        .registerFactory(viewTypeId, viewFactory, isVisible: isVisible);
  }
}

/// The platform view registry for this app.
final PlatformViewRegistry platformViewRegistry = PlatformViewRegistry();
