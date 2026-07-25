// VideoDecoder.swift
// FFmpegSwiftSDK
//
// 解码压缩视频包为 VideoFrame（包含 CVPixelBuffer）。
// 优先使用 VideoToolbox 硬件加速解码（零拷贝 CVPixelBuffer），
// 如果硬解不可用则回退到 FFmpeg 软解码。

import Foundation
import CFFmpeg
import CoreVideo
import VideoToolbox

// MARK: - VideoDecoder

/// 视频解码器：优先 VideoToolbox 硬解，回退 FFmpeg 软解。
///
/// 硬解模式下，解码后的 AVFrame 直接包含 CVPixelBuffer（零拷贝），
/// 无需手动 YUV→NV12 转换，性能大幅提升。
final class VideoDecoder: Decoder {
    typealias Output = VideoFrame

    // MARK: - 属性

    private let codecContext: FFmpegCodecContext
    private let timeBase: AVRational

    /// 是否成功启用了硬件加速
    private(set) var isHardwareAccelerated: Bool = false

    /// 硬件设备上下文引用（需要保持强引用防止释放）
    private var hwDeviceCtx: UnsafeMutablePointer<AVBufferRef>?

    /// CVPixelBuffer 缓冲池（软解模式复用）
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolWidth: Int = 0
    private var poolHeight: Int = 0

    // MARK: - 初始化

    init(
        codecParameters: UnsafePointer<AVCodecParameters>,
        codecID: AVCodecID,
        timeBase: AVRational = AVRational(num: 1, den: 90000)
    ) throws {
        try validateCodecSupported(codecID, in: supportedVideoCodecIDs)

        guard let decoder = avcodec_find_decoder(codecID) else {
            let codecName = String(cString: avcodec_get_name(codecID))
            throw FFmpegError.unsupportedFormat(codecName: codecName)
        }

        codecContext = try FFmpegCodecContext(codec: decoder)
        try codecContext.setParameters(from: codecParameters)
        self.timeBase = timeBase

        // 尝试启用 VideoToolbox 硬件加速
        if let ctx = codecContext.rawPointer {
            isHardwareAccelerated = Self.enableVideoToolbox(ctx)
        }

        try codecContext.open(codec: decoder)

        if isHardwareAccelerated {
            print("[VideoDecoder] ✅ VideoToolbox 硬件加速已启用")
        } else {
            print("[VideoDecoder] ⚠️ 回退到 FFmpeg 软解码")
        }
    }

    deinit {
        if let hwCtx = hwDeviceCtx {
            var ctx: UnsafeMutablePointer<AVBufferRef>? = hwCtx
            av_buffer_unref(&ctx)
        }
    }

    // MARK: - VideoToolbox 配置

    /// 为 codec context 启用 VideoToolbox 硬件加速
    private static func enableVideoToolbox(_ ctx: UnsafeMutablePointer<AVCodecContext>) -> Bool {
        var hwDeviceCtx: UnsafeMutablePointer<AVBufferRef>?

        // 创建 VideoToolbox 硬件设备上下文
        let ret = av_hwdevice_ctx_create(
            &hwDeviceCtx,
            AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
            nil, nil, 0
        )

        guard ret >= 0, let deviceCtx = hwDeviceCtx else {
            return false
        }

        ctx.pointee.hw_device_ctx = av_buffer_ref(deviceCtx)
        av_buffer_unref(&hwDeviceCtx)

        return ctx.pointee.hw_device_ctx != nil
    }

    // MARK: - 解码

    func decode(packet: UnsafeMutablePointer<AVPacket>) throws -> VideoFrame {
        guard let ctx = codecContext.rawPointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVCodecContext (nil)")
        }

        let sendRet = avcodec_send_packet(ctx, packet)
        guard sendRet >= 0 else {
            throw FFmpegError.decodingFailed(code: sendRet, message: "avcodec_send_packet failed")
        }

        guard let frame = av_frame_alloc() else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFrame")
        }
        defer {
            var framePtr: UnsafeMutablePointer<AVFrame>? = frame
            av_frame_free(&framePtr)
        }

        let recvRet = avcodec_receive_frame(ctx, frame)
        guard recvRet >= 0 else {
            throw FFmpegError.decodingFailed(code: recvRet, message: "avcodec_receive_frame failed")
        }

        // 计算 PTS
        let pts: TimeInterval
        if frame.pointee.pts != Int64(bitPattern: UInt64(0x8000000000000000)) {
            pts = TimeInterval(frame.pointee.pts) * TimeInterval(timeBase.num) / TimeInterval(timeBase.den)
        } else {
            pts = 0
        }

        let duration: TimeInterval
        if frame.pointee.duration > 0 {
            duration = TimeInterval(frame.pointee.duration) * TimeInterval(timeBase.num) / TimeInterval(timeBase.den)
        } else {
            duration = 0
        }

        // 硬解：frame.format == AV_PIX_FMT_VIDEOTOOLBOX，data[3] 就是 CVPixelBuffer
        let pixelBuffer: CVPixelBuffer
        let width: Int
        let height: Int

        if frame.pointee.format == AV_PIX_FMT_VIDEOTOOLBOX.rawValue,
           let vtBuffer = frame.pointee.data.3 {
            // 硬解零拷贝路径
            let cvBuf = Unmanaged<CVPixelBuffer>.fromOpaque(vtBuffer).takeUnretainedValue()
            pixelBuffer = cvBuf
            width = CVPixelBufferGetWidth(cvBuf)
            height = CVPixelBufferGetHeight(cvBuf)
        } else {
            // 软解路径
            width = Int(frame.pointee.width)
            height = Int(frame.pointee.height)
            pixelBuffer = try createPixelBuffer(from: frame, width: width, height: height)
        }

        return VideoFrame(
            pixelBuffer: pixelBuffer,
            pts: pts,
            duration: duration,
            width: width,
            height: height
        )
    }

    // MARK: - 软解像素缓冲区（优化版）

    private func createPixelBuffer(
        from frame: UnsafeMutablePointer<AVFrame>,
        width: Int,
        height: Int
    ) throws -> CVPixelBuffer {
        let cvPixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

        // 复用 CVPixelBufferPool
        let buffer = try getPooledPixelBuffer(width: width, height: height, format: cvPixelFormat)

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let pixelFormat = frame.pointee.format
        if pixelFormat == AV_PIX_FMT_NV12.rawValue {
            copyNV12Data(from: frame, to: buffer, width: width, height: height)
        } else {
            copyYUV420PToNV12(from: frame, to: buffer, width: width, height: height)
        }

        return buffer
    }

    /// 从缓冲池获取 CVPixelBuffer（避免每帧重新分配）
    private func getPooledPixelBuffer(width: Int, height: Int, format: OSType) throws -> CVPixelBuffer {
        // 尺寸变化时重建池
        if pixelBufferPool == nil || poolWidth != width || poolHeight != height {
            pixelBufferPool = nil
            let poolAttrs: [String: Any] = [
                kCVPixelBufferPoolMinimumBufferCountKey as String: 3
            ]
            let bufferAttrs: [String: Any] = [
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferPixelFormatTypeKey as String: format,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
            ]
            var pool: CVPixelBufferPool?
            let status = CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                poolAttrs as CFDictionary,
                bufferAttrs as CFDictionary,
                &pool
            )
            guard status == kCVReturnSuccess, let createdPool = pool else {
                throw FFmpegError.resourceAllocationFailed(resource: "CVPixelBufferPool")
            }
            pixelBufferPool = createdPool
            poolWidth = width
            poolHeight = height
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool!, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw FFmpegError.resourceAllocationFailed(resource: "CVPixelBuffer from pool")
        }
        return buffer
    }

    // MARK: - NV12 直接拷贝

    private func copyNV12Data(
        from frame: UnsafeMutablePointer<AVFrame>,
        to buffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) {
        if let yDst = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
           let ySrc = frame.pointee.data.0 {
            let yDstStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            let ySrcStride = Int(frame.pointee.linesize.0)
            let yDstPtr = yDst.assumingMemoryBound(to: UInt8.self)
            for row in 0..<height {
                memcpy(yDstPtr + row * yDstStride, ySrc + row * ySrcStride, min(width, ySrcStride))
            }
        }

        if let uvDst = CVPixelBufferGetBaseAddressOfPlane(buffer, 1),
           let uvSrc = frame.pointee.data.1 {
            let uvDstStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            let uvSrcStride = Int(frame.pointee.linesize.1)
            let uvHeight = height / 2
            let uvDstPtr = uvDst.assumingMemoryBound(to: UInt8.self)
            for row in 0..<uvHeight {
                memcpy(uvDstPtr + row * uvDstStride, uvSrc + row * uvSrcStride, min(width, uvSrcStride))
            }
        }
    }

    // MARK: - YUV420P → NV12 转换（优化：按行批量交错）

    private func copyYUV420PToNV12(
        from frame: UnsafeMutablePointer<AVFrame>,
        to buffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) {
        // Y 平面直接 memcpy
        if let yDst = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
           let ySrc = frame.pointee.data.0 {
            let yDstStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            let ySrcStride = Int(frame.pointee.linesize.0)
            let yDstPtr = yDst.assumingMemoryBound(to: UInt8.self)
            for row in 0..<height {
                memcpy(yDstPtr + row * yDstStride, ySrc + row * ySrcStride, min(width, ySrcStride))
            }
        }

        // UV 交错：使用 UnsafeMutableBufferPointer 批量操作
        if let uvDst = CVPixelBufferGetBaseAddressOfPlane(buffer, 1),
           let uSrc = frame.pointee.data.1,
           let vSrc = frame.pointee.data.2 {
            let uvDstStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            let uSrcStride = Int(frame.pointee.linesize.1)
            let vSrcStride = Int(frame.pointee.linesize.2)
            let uvHeight = height / 2
            let uvWidth = width / 2
            let uvDstPtr = uvDst.assumingMemoryBound(to: UInt8.self)

            for row in 0..<uvHeight {
                let dstRow = uvDstPtr + row * uvDstStride
                let uRow = uSrc + row * uSrcStride
                let vRow = vSrc + row * vSrcStride
                // 每次处理 4 像素减少循环开销
                var col = 0
                let uvWidth4 = uvWidth & ~3
                while col < uvWidth4 {
                    dstRow[col * 2]     = uRow[col]
                    dstRow[col * 2 + 1] = vRow[col]
                    dstRow[col * 2 + 2] = uRow[col + 1]
                    dstRow[col * 2 + 3] = vRow[col + 1]
                    dstRow[col * 2 + 4] = uRow[col + 2]
                    dstRow[col * 2 + 5] = vRow[col + 2]
                    dstRow[col * 2 + 6] = uRow[col + 3]
                    dstRow[col * 2 + 7] = vRow[col + 3]
                    col += 4
                }
                // 处理剩余
                while col < uvWidth {
                    dstRow[col * 2] = uRow[col]
                    dstRow[col * 2 + 1] = vRow[col]
                    col += 1
                }
            }
        }
    }

    // MARK: - Flush

    func flush() {
        guard let ctx = codecContext.rawPointer else { return }
        avcodec_flush_buffers(ctx)
    }
}
