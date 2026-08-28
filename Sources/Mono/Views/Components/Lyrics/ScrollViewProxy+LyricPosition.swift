import SwiftUI
import Combine

// MARK: - 歌词初始定位

extension ScrollViewProxy {
    /// 歌词页挂载时把当前行定位到锚点。
    ///
    /// 单次 `scrollTo` 在播放器主题切换的 spring 过渡期间经常因为内容尚未完成布局而被吞掉，
    /// 表现为「切完主题歌词要等到下一句才滚出来 / 一片空白」。
    /// 这里在挂载后分三拍补位（立即 / 下一帧 / 过渡动画结束后），全部关闭动画，
    /// 保证歌词一挂载就停在当前行。
    @MainActor
    func monoRestoreLyricPosition(
        anchor: UnitPoint = .center,
        isCancelled: (@MainActor () -> Bool)? = nil,
        index: @escaping @MainActor () -> Int
    ) {
        let jump = { @MainActor in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.scrollTo(index(), anchor: anchor)
            }
        }
        jump()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            if isCancelled?() == true { return }
            jump()
            try? await Task.sleep(nanoseconds: 440_000_000)
            if isCancelled?() == true { return }
            jump()
        }
    }
}
