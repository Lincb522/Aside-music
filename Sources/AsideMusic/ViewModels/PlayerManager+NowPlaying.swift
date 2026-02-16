// PlayerManager+NowPlaying.swift
// AsideMusic
//
// 锁屏/控制中心 Now Playing 信息更新

import Foundation
import MediaPlayer
import UIKit

extension PlayerManager {
    
    // MARK: - Now Playing Info
    
    func updateNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentSong?.name ?? ""
        info[MPMediaItemPropertyArtist] = currentSong?.artistName ?? ""
        info[MPMediaItemPropertyAlbumTitle] = currentSong?.album?.name ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    func updateNowPlayingTime() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    func updateNowPlayingArtwork(for song: Song?) {
        guard let coverUrl = song?.coverUrl else { return }
        
        Task.detached {
            do {
                let (data, _) = try await URLSession.shared.data(from: coverUrl)
                guard let image = UIImage(data: data) else { return }
                
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                
                await MainActor.run {
                    guard self.currentSong?.id == song?.id else { return }
                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            } catch {
                AppLogger.warning("封面图下载失败: \(error)")
            }
        }
    }
}
