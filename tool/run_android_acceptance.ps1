$ErrorActionPreference = 'Stop'

$Device = if ($env:SOUNDTRACK_ANDROID_DEVICE) {
  $env:SOUNDTRACK_ANDROID_DEVICE
} else {
  'emulator-5554'
}

flutter analyze
flutter test
flutter test integration_test/event_authoring_flow_test.dart -d $Device
flutter test integration_test/audio_engine_flow_test.dart -d $Device
flutter test integration_test/live_event_flow_test.dart -d $Device
git diff --check
