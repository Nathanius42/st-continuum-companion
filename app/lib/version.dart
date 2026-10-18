/// The app's version (#528), kept equal to `version:` in pubspec.yaml (a test
/// checks), because reading it at run time would need a plugin. The build
/// number after the + is Android's versionCode and the last part of the
/// Windows file version; raise it for every release.
const appVersion = '1.0.0';
const appBuild = 1;
