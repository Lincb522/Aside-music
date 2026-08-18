import Foundation

/// 听歌统计的唯一判定口径。
///
/// 页面、报告、云同步和播放记录器都必须通过这里判断一次播放会话，
/// 避免“开始加载就加次数”“结束回调等于完播”等不同口径并存。
enum ListeningPlaybackPolicy {
    static let qualificationVersion = 1
    static let completionRatio = 0.90
    static let unknownDurationEffectiveSeconds: TimeInterval = 30

    /// 有效播放阈值：
    /// - 10 秒及以下的极短音频：实际听满 80%；
    /// - 其余歌曲：实际听满「半首、至少 10 秒、最多 30 秒」。
    static func effectivePlaybackThreshold(
        trackDuration: TimeInterval
    ) -> TimeInterval {
        guard trackDuration.isFinite, trackDuration > 0 else {
            return unknownDurationEffectiveSeconds
        }
        if trackDuration <= 10 {
            return max(1, trackDuration * 0.80)
        }
        return min(30, max(10, trackDuration * 0.50))
    }

    static func isEffective(
        actualPlayback: TimeInterval,
        trackDuration: TimeInterval
    ) -> Bool {
        actualPlayback >= effectivePlaybackThreshold(trackDuration: trackDuration)
    }

    /// 完整播放只看实际送出的可听时长，不依赖结束事件和当前进度。
    static func isCompleted(
        actualPlayback: TimeInterval,
        trackDuration: TimeInterval
    ) -> Bool {
        guard trackDuration.isFinite, trackDuration > 0 else { return false }
        return actualPlayback >= trackDuration * completionRatio
    }

    /// 新记录直接使用落盘结论；旧记录沿用历史版本的口径。
    ///
    /// 旧版本只记录 `playDuration`，没有可靠的歌曲总时长与有效播放结论。
    /// 如果强行按新阈值重算，会把升级前已经展示过的短时收听记录隐藏掉。
    /// 因此旧记录只要确实累计过播放时间就继续保留；严格阈值仅用于升级后
    /// 由当前记录器写入、带有 qualificationVersion 的新会话。
    static func isEffective(_ record: PlayHistory) -> Bool {
        if record.qualificationVersion == qualificationVersion {
            return record.effectivePlay
        }
        return record.playDuration > 0
    }

    static func isEffective(_ record: CloudPlayHistoryRecord) -> Bool {
        if record.qualificationVersion == qualificationVersion {
            return record.effectivePlay == true
        }
        return record.playDuration > 0
    }

    static func identityKey(for record: PlayHistory) -> String {
        if let appleMusicID = record.appleMusicID, !appleMusicID.isEmpty {
            return "appleMusic:\(appleMusicID)"
        }
        if let qqMid = record.qqMid, !qqMid.isEmpty {
            return "qq:\(qqMid)"
        }
        if let qishuiTrackId = record.qishuiTrackId {
            return "qishui:\(qishuiTrackId)"
        }
        return "\(record.sourceRaw ?? "unknown"):\(record.songId)"
    }
}
