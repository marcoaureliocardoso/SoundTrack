import 'package:flutter/widgets.dart';

const nowPlayingPanelKey = Key('now-playing-panel');
const nowPlayingTrackKey = Key('now-playing-track');
const nowPlayingDetailsKey = Key('now-playing-details');
const liveDashboardScrollKey = Key('live-dashboard-scroll');
const momentsSectionTitleKey = Key('moments-section-title');
const liveAlertBannerKey = Key('live-alert-banner');
const liveAlertDetailsKey = Key('live-alert-details');
const liveDashboardCenterKey = Key('live-dashboard-center');
const playbackFooterKey = Key('playback-footer');
const volumesToggleKey = Key('volumes-toggle');
const emergencyVolumesCurtainKey = Key('emergency-volumes-curtain');
const emergencyVolumesKey = Key('emergency-volumes');
const pausePlaybackKey = Key('pause-playback');
const stopPlaybackKey = Key('stop-playback');
const narrationKey = Key('narration');
Key liveMomentKey(String id) => Key('live-moment-$id');
