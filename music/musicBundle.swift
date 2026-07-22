// musicBundle.swift
// Widget Extension 入口

import WidgetKit
import SwiftUI

@main
struct musicBundle: WidgetBundle {
    var body: some Widget {
        SelectableNowPlayingWidget()
        NowPlayingWidget(theme: .polaroid)
        NowPlayingWidget(theme: .vinyl)
        NowPlayingWidget(theme: .poster)
        NowPlayingWidget(theme: .manga)
        NowPlayingWidget(theme: .magazine)
        NowPlayingWidget(theme: .aperture)
        NowPlayingWidget(theme: .pager)
        NowPlayingWidget(theme: .pagerLight)
        NowPlayingWidget(theme: .radio)
        NowPlayingWidget(theme: .dashboard)
        NowPlayingWidget(theme: .soundwave)
        NowPlayingWidget(theme: .typewriter)
        NowPlayingWidget(theme: .lyrics)
        if #available(iOS 18, *) {
            PlayPauseControlWidget()
            NextTrackControlWidget()
            GameModeControlWidget()
        }
    }
}
