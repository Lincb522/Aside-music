// CodecCapabilities.swift
// FFmpegSwiftSDK
//
// 公开 API：查询 SDK 支持的编解码器、容器格式、协议等能力。

import Foundation

/// SDK 编解码能力查询。
///
/// 提供静态方法查询当前 FFmpeg 编译支持的音频/视频解码器、
/// 容器格式（解复用器）和流协议。
///
/// ```swift
/// let codecs = CodecCapabilities.supportedAudioCodecs
/// let formats = CodecCapabilities.supportedContainerFormats
/// let protocols = CodecCapabilities.supportedProtocols
/// ```
public enum CodecCapabilities {

    // MARK: - 音频解码器

    /// 支持的音频解码器列表。
    public static let supportedAudioCodecs: [AudioCodecInfo] = [
        // 有损
        AudioCodecInfo(name: "aac", displayName: "AAC", isLossless: false, description: "高级音频编码，流媒体标准格式"),
        AudioCodecInfo(name: "mp3", displayName: "MP3", isLossless: false, description: "MPEG Audio Layer 3"),
        AudioCodecInfo(name: "vorbis", displayName: "Vorbis", isLossless: false, description: "开源有损编码，常用于 Ogg 容器和播客"),
        AudioCodecInfo(name: "opus", displayName: "Opus", isLossless: false, description: "低延迟高质量编码，播客和语音通话常用"),
        AudioCodecInfo(name: "ac3", displayName: "AC-3", isLossless: false, description: "杜比数字音频"),
        AudioCodecInfo(name: "eac3", displayName: "E-AC-3", isLossless: false, description: "增强型杜比数字音频"),
        AudioCodecInfo(name: "dts", displayName: "DTS", isLossless: false, description: "DTS 数字环绕声"),
        AudioCodecInfo(name: "cook", displayName: "Cook", isLossless: false, description: "RealAudio 编码"),
        // 无损
        AudioCodecInfo(name: "flac", displayName: "FLAC", isLossless: true, description: "免费无损音频编码，酷狗 SQ 音源"),
        AudioCodecInfo(name: "alac", displayName: "ALAC", isLossless: true, description: "Apple Lossless，Apple 生态无损格式"),
        AudioCodecInfo(name: "wavpack", displayName: "WavPack", isLossless: true, description: "WavPack 无损/混合编码"),
        AudioCodecInfo(name: "ape", displayName: "APE", isLossless: true, description: "Monkey's Audio 无损编码"),
        AudioCodecInfo(name: "tak", displayName: "TAK", isLossless: true, description: "Tom's 无损音频压缩"),
        AudioCodecInfo(name: "tta", displayName: "TTA", isLossless: true, description: "True Audio 无损编码"),
        // Hi-Res PCM
        AudioCodecInfo(name: "pcm_s16le", displayName: "PCM 16bit", isLossless: true, description: "CD 质量 16bit PCM"),
        AudioCodecInfo(name: "pcm_s24le", displayName: "PCM 24bit", isLossless: true, description: "Hi-Res 24bit PCM"),
        AudioCodecInfo(name: "pcm_s32le", displayName: "PCM 32bit", isLossless: true, description: "Hi-Res 32bit PCM"),
        AudioCodecInfo(name: "pcm_f32le", displayName: "PCM Float32", isLossless: true, description: "32bit 浮点 PCM"),
        AudioCodecInfo(name: "pcm_f64le", displayName: "PCM Float64", isLossless: true, description: "64bit 浮点 PCM"),
    ]

    // MARK: - 视频解码器

    /// 支持的视频解码器列表。
    public static let supportedVideoCodecs: [VideoCodecInfo] = [
        VideoCodecInfo(name: "h264", displayName: "H.264/AVC", hwAccelerated: true, description: "最广泛使用的视频编码，支持 VideoToolbox 硬解"),
        VideoCodecInfo(name: "hevc", displayName: "H.265/HEVC", hwAccelerated: true, description: "高效视频编码，支持 VideoToolbox 硬解"),
    ]

    // MARK: - 容器格式（解复用器）

    /// 支持的容器格式列表。
    public static let supportedContainerFormats: [ContainerFormatInfo] = [
        ContainerFormatInfo(name: "mov,mp4,m4a", displayName: "MP4/M4A/MOV", description: "Apple/ISO 标准容器，MV 和音乐主要格式"),
        ContainerFormatInfo(name: "mpegts", displayName: "MPEG-TS", description: "传输流，HLS 分片格式"),
        ContainerFormatInfo(name: "flv", displayName: "FLV", description: "Flash Video，RTMP 流媒体格式"),
        ContainerFormatInfo(name: "hls", displayName: "HLS", description: "HTTP Live Streaming"),
        ContainerFormatInfo(name: "matroska,webm", displayName: "MKV/WebM", description: "Matroska 容器，MKV/WebM 格式的 MV 源"),
        ContainerFormatInfo(name: "ogg", displayName: "Ogg", description: "Ogg 容器，Vorbis/Opus 播客常用"),
        ContainerFormatInfo(name: "flac", displayName: "FLAC", description: "FLAC 原生容器"),
        ContainerFormatInfo(name: "wav", displayName: "WAV", description: "WAV 无压缩音频容器"),
        ContainerFormatInfo(name: "mp3", displayName: "MP3", description: "MP3 原生格式"),
        ContainerFormatInfo(name: "aac", displayName: "AAC", description: "AAC 原生 ADTS 格式"),
    ]

    // MARK: - 流协议

    /// 支持的流协议列表。
    public static let supportedProtocols: [ProtocolInfo] = [
        ProtocolInfo(name: "http", displayName: "HTTP", description: "HTTP 流媒体"),
        ProtocolInfo(name: "https", displayName: "HTTPS", description: "HTTPS 加密流媒体"),
        ProtocolInfo(name: "hls", displayName: "HLS", description: "HTTP Live Streaming 协议"),
        ProtocolInfo(name: "rtmp", displayName: "RTMP", description: "实时消息协议"),
        ProtocolInfo(name: "tcp", displayName: "TCP", description: "TCP 传输"),
        ProtocolInfo(name: "udp", displayName: "UDP", description: "UDP 传输"),
        ProtocolInfo(name: "file", displayName: "File", description: "本地文件协议"),
        ProtocolInfo(name: "concat", displayName: "Concat", description: "拼接播放协议，支持多文件顺序播放"),
        ProtocolInfo(name: "data", displayName: "Data URI", description: "data: URI 协议，支持内嵌数据"),
    ]

    // MARK: - 音频滤镜

    /// 支持的音频滤镜列表。
    public static let supportedAudioFilters: [AudioFilterInfo] = [
        AudioFilterInfo(name: "equalizer", displayName: "参数均衡器", description: "频段增益调节"),
        AudioFilterInfo(name: "volume", displayName: "音量控制", description: "音量增益/衰减（dB）"),
        AudioFilterInfo(name: "loudnorm", displayName: "响度标准化", description: "EBU R128 响度标准化，解决不同歌曲音量差异"),
        AudioFilterInfo(name: "atempo", displayName: "变速不变调", description: "播放速度调节（0.5x ~ 4.0x），不改变音调"),
        AudioFilterInfo(name: "aformat", displayName: "格式转换", description: "采样格式/采样率/声道布局转换"),
        AudioFilterInfo(name: "aresample", displayName: "重采样", description: "高质量音频重采样"),
    ]
}

// MARK: - 信息模型

/// 音频编解码器信息。
public struct AudioCodecInfo {
    public let name: String
    public let displayName: String
    public let isLossless: Bool
    public let description: String
}

/// 视频编解码器信息。
public struct VideoCodecInfo {
    public let name: String
    public let displayName: String
    public let hwAccelerated: Bool
    public let description: String
}

/// 容器格式信息。
public struct ContainerFormatInfo {
    public let name: String
    public let displayName: String
    public let description: String
}

/// 流协议信息。
public struct ProtocolInfo {
    public let name: String
    public let displayName: String
    public let description: String
}

/// 音频滤镜信息。
public struct AudioFilterInfo {
    public let name: String
    public let displayName: String
    public let description: String
}
