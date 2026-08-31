// FFmpegRuntimeInspector.swift
// FFmpegSwiftSDK

import Foundation
import CFFmpeg

/// FFmpeg 动态库在当前运行环境中实际注册的能力快照。
public struct FFmpegRuntimeSnapshot: Sendable {
    public let version: String
    public let buildConfiguration: String
    public let license: String
    public let libraryVersions: [FFmpegLibraryVersion]
    public let audioDecoders: [String]
    public let audioEncoders: [String]
    public let demuxers: [String]
    public let muxers: [String]
    public let filters: [String]
    public let inputProtocols: [String]
    public let outputProtocols: [String]
}

public struct FFmpegLibraryVersion: Identifiable, Sendable {
    public let name: String
    public let version: String

    public var id: String { name }
}

/// 查询运行时注册表，不依赖 SDK 中的静态能力说明。
public enum FFmpegRuntimeInspector {
    /// Mono 播放链会实际请求的 avfilter 名称。
    public static let monoPlaybackFilterNames: [String] = [
        "abuffer", "abuffersink", "acompressor", "acrusher", "adeclick", "adeclip",
        "adelay", "aecho", "aexciter", "afade", "afftdn", "aformat", "agate",
        "alimiter", "asetrate", "asoftclip", "asubboost", "atempo", "bandpass",
        "bandreject", "bass", "bs2b", "chorus", "compand", "dialoguenhance",
        "dynaudnorm", "flanger", "haas", "loudnorm", "lowpass", "pan",
        "speechnorm", "stereotools", "treble", "tremolo", "vibrato",
        "virtualbass", "volume"
    ]

    public static func inspect() -> FFmpegRuntimeSnapshot {
        var audioDecoders = Set<String>()
        var audioEncoders = Set<String>()
        var codecOpaque: UnsafeMutableRawPointer?

        while let codec = av_codec_iterate(&codecOpaque) {
            let name = String(cString: codec.pointee.name)
            switch codec.pointee.type {
            case AVMEDIA_TYPE_AUDIO:
                if av_codec_is_decoder(codec) != 0 { audioDecoders.insert(name) }
                if av_codec_is_encoder(codec) != 0 { audioEncoders.insert(name) }
            default:
                break
            }
        }

        var demuxers = Set<String>()
        var demuxerOpaque: UnsafeMutableRawPointer?
        while let format = av_demuxer_iterate(&demuxerOpaque) {
            insertAliases(from: format.pointee.name, into: &demuxers)
        }

        var muxers = Set<String>()
        var muxerOpaque: UnsafeMutableRawPointer?
        while let format = av_muxer_iterate(&muxerOpaque) {
            insertAliases(from: format.pointee.name, into: &muxers)
        }

        var filters = Set<String>()
        var filterOpaque: UnsafeMutableRawPointer?
        while let filter = av_filter_iterate(&filterOpaque) {
            if isAudioOnlyFilter(filter) {
                filters.insert(String(cString: filter.pointee.name))
            }
        }

        var inputProtocols = Set<String>()
        var inputOpaque: UnsafeMutableRawPointer?
        while let name = avio_enum_protocols(&inputOpaque, 0) {
            inputProtocols.insert(String(cString: name))
        }

        var outputProtocols = Set<String>()
        var outputOpaque: UnsafeMutableRawPointer?
        while let name = avio_enum_protocols(&outputOpaque, 1) {
            outputProtocols.insert(String(cString: name))
        }

        return FFmpegRuntimeSnapshot(
            version: av_version_info().map(String.init(cString:)) ?? "unknown",
            buildConfiguration: avcodec_configuration().map(String.init(cString:)) ?? "",
            license: avcodec_license().map(String.init(cString:)) ?? "",
            libraryVersions: [
                FFmpegLibraryVersion(name: "libavcodec", version: unpackedVersion(avcodec_version())),
                FFmpegLibraryVersion(name: "libavformat", version: unpackedVersion(avformat_version())),
                FFmpegLibraryVersion(name: "libavfilter", version: unpackedVersion(avfilter_version())),
                FFmpegLibraryVersion(name: "libavutil", version: unpackedVersion(avutil_version())),
                FFmpegLibraryVersion(name: "libswresample", version: unpackedVersion(swresample_version()))
            ],
            audioDecoders: audioDecoders.sorted(),
            audioEncoders: audioEncoders.sorted(),
            demuxers: demuxers.sorted(),
            muxers: muxers.sorted(),
            filters: filters.sorted(),
            inputProtocols: inputProtocols.sorted(),
            outputProtocols: outputProtocols.sorted()
        )
    }

    public static func hasAudioDecoder(named name: String) -> Bool {
        name.withCString { namePointer in
            guard let codec = avcodec_find_decoder_by_name(namePointer) else {
                return false
            }
            return codec.pointee.type == AVMEDIA_TYPE_AUDIO
        }
    }

    private static func insertAliases(
        from pointer: UnsafePointer<CChar>?,
        into names: inout Set<String>
    ) {
        guard let pointer else { return }
        String(cString: pointer)
            .split(separator: ",")
            .map(String.init)
            .forEach { names.insert($0) }
    }

    private static func unpackedVersion(_ value: UInt32) -> String {
        let major = value >> 16
        let minor = (value >> 8) & 0xFF
        let patch = value & 0xFF
        return "\(major).\(minor).\(patch)"
    }

    private static func isAudioOnlyFilter(_ filter: UnsafePointer<AVFilter>) -> Bool {
        var hasAudioPad = false
        var hasNonAudioPad = false

        for isOutput in [false, true] {
            let pads = isOutput ? filter.pointee.outputs : filter.pointee.inputs
            let count = Int(avfilter_filter_pad_count(filter, isOutput ? 1 : 0))
            guard let pads else { continue }

            for index in 0..<count {
                let mediaType = avfilter_pad_get_type(pads, Int32(index))
                if mediaType == AVMEDIA_TYPE_AUDIO {
                    hasAudioPad = true
                } else if mediaType != AVMEDIA_TYPE_UNKNOWN {
                    hasNonAudioPad = true
                }
            }
        }

        return hasAudioPad && !hasNonAudioPad
    }
}
