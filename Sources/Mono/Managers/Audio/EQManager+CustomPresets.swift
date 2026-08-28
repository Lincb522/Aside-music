import Foundation
import Combine
import AVFoundation
import FFmpegSwiftSDK

extension EQManager {
    // MARK: - 自定义预设管理
    
    func saveCustomPreset(name: String, description: String = "") {
        let preset = EQPreset(
            id: "custom_\(UUID().uuidString.prefix(8))",
            name: name,
            category: .custom,
            description: description,
            gains: customGains,
            isCustom: true,
            presetType: graphicEQMode == .tenBand ? .standard10 : .graphic32,
            preampDB: customPresetPreampDB
        )
        customPresets.append(preset)
        saveState()
    }
    
    func deleteCustomPreset(_ preset: EQPreset) {
        customPresets.removeAll { $0.id == preset.id }
        if currentPreset?.id == preset.id {
            applyFlat()
        }
        saveState()
    }

    func makeCloudCustomPresets() -> [EQPreset]? {
        customPresets.isEmpty ? nil : customPresets
    }

    func restoreCloudCustomPresets(_ remotePresets: [EQPreset]) {
        let validRemote = remotePresets.filter { preset in
            preset.isCustom
                && preset.presetType.expectedGainCount == preset.gains.count
                && preset.gains.allSatisfy(\.isFinite)
        }
        guard !validRemote.isEmpty else { return }

        var merged = Dictionary(uniqueKeysWithValues: customPresets.map { ($0.id, $0) })
        for preset in validRemote {
            merged[preset.id] = preset
        }
        customPresets = merged.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        saveState()
    }
    
}
