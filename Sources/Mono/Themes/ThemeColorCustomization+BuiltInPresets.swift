import Foundation
import SwiftUI
import UIKit

extension ThemeColorCustomization {

    static func builtInPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        switch theme {
        case .minimalWhite:
            return []
        case .signal:
            return []
        case .clarity:
            return [
                ThemeColorPreset(id: "clarity-air", name: "Air", accentStartHex: "2478D8", accentEndHex: "2478D8", backgroundStartHex: "F8F8F7", backgroundEndHex: "EDF1F2", backgroundHexes: ["F8F8F7", "EDF1F2", "F1EAF7", "E7F5F5"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "clarity-pearl", name: "Pearl", accentStartHex: "57636D", accentEndHex: "57636D", backgroundStartHex: "FBFBF9", backgroundEndHex: "EFF1F1", backgroundHexes: ["FBFBF9", "EFF1F1", "F4F0EC", "EDF3F4"], gradientStyle: .linear),
                ThemeColorPreset(id: "clarity-aurora", name: "Aurora", accentStartHex: "238F91", accentEndHex: "238F91", backgroundStartHex: "F4FBFA", backgroundEndHex: "EAF3F7", backgroundHexes: ["F4FBFA", "EAF3F7", "EAEAF8", "E5F6F0"], gradientStyle: .mesh),
                ThemeColorPreset(id: "clarity-lavender", name: "Lavender", accentStartHex: "7066A6", accentEndHex: "7066A6", backgroundStartHex: "F8F6FC", backgroundEndHex: "ECEFF7", backgroundHexes: ["F8F6FC", "ECEFF7", "F2EAF8", "E8F4F5"], gradientStyle: .radial),
                ThemeColorPreset(id: "clarity-peach-ice", name: "Peach Ice", accentStartHex: "B76E61", accentEndHex: "B76E61", backgroundStartHex: "FFF8F5", backgroundEndHex: "EDF3F5", backgroundHexes: ["FFF8F5", "EDF3F5", "FBE9E5", "EAF5F2"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "clarity-sage", name: "Sage Mist", accentStartHex: "5D8274", accentEndHex: "5D8274", backgroundStartHex: "F5F9F6", backgroundEndHex: "EBF1EF", backgroundHexes: ["F5F9F6", "EBF1EF", "EEF2E8", "E7F4F3"], gradientStyle: .mesh),
                ThemeColorPreset(id: "clarity-sky", name: "Clear Sky", accentStartHex: "347CAD", accentEndHex: "347CAD", backgroundStartHex: "F5FAFD", backgroundEndHex: "E8F1F7", backgroundHexes: ["F5FAFD", "E8F1F7", "EDF4FB", "E7F8F7"], gradientStyle: .linear),
                ThemeColorPreset(id: "clarity-rose", name: "Rose Quartz", accentStartHex: "A96378", accentEndHex: "A96378", backgroundStartHex: "FFF7FA", backgroundEndHex: "EEF1F6", backgroundHexes: ["FFF7FA", "EEF1F6", "F8E9EF", "ECF5F3"], gradientStyle: .radial),
                ThemeColorPreset(id: "clarity-champagne", name: "Champagne", accentStartHex: "9A763F", accentEndHex: "9A763F", backgroundStartHex: "FCF9F2", backgroundEndHex: "EEF1F2", backgroundHexes: ["FCF9F2", "EEF1F2", "F7EEDC", "ECF4F0"], gradientStyle: .conic),
                ThemeColorPreset(id: "clarity-glacier", name: "Glacier", accentStartHex: "397F8E", accentEndHex: "397F8E", backgroundStartHex: "F4FBFC", backgroundEndHex: "E8F0F4", backgroundHexes: ["F4FBFC", "E8F0F4", "E7F5F7", "EDF0FA"], gradientStyle: .mesh),
                ThemeColorPreset(id: "clarity-silver", name: "Silver", accentStartHex: "606B76", accentEndHex: "606B76", backgroundStartHex: "F7F8F9", backgroundEndHex: "E9EDF0", backgroundHexes: ["F7F8F9", "E9EDF0", "F0F1F5", "EAF1F1"], gradientStyle: .linear),
                ThemeColorPreset(id: "clarity-moon-milk", name: "Moon Milk", accentStartHex: "826C8D", accentEndHex: "826C8D", backgroundStartHex: "FAF8FA", backgroundEndHex: "EEF0F2", backgroundHexes: ["FAF8FA", "EEF0F2", "F3EBF1", "EDF5F2"], gradientStyle: .diffuse),
            ]
        case .muji:
            return [
                ThemeColorPreset(id: "muji-linen", name: "Linen", accentStartHex: "B56B4B", accentEndHex: "B56B4B", backgroundStartHex: "F7F1E8", backgroundEndHex: "F7F1E8"),
                ThemeColorPreset(id: "muji-tea", name: "Tea", accentStartHex: "78846B", accentEndHex: "78846B", backgroundStartHex: "F3EEE3", backgroundEndHex: "F3EEE3"),
                ThemeColorPreset(id: "muji-clay", name: "Clay", accentStartHex: "B96D55", accentEndHex: "B96D55", backgroundStartHex: "F4E8DC", backgroundEndHex: "F4E8DC"),
                ThemeColorPreset(id: "muji-rice", name: "Rice", accentStartHex: "9C7A53", accentEndHex: "9C7A53", backgroundStartHex: "FAF4E8", backgroundEndHex: "FAF4E8"),
                ThemeColorPreset(id: "muji-olive", name: "Olive", accentStartHex: "6F8064", accentEndHex: "6F8064", backgroundStartHex: "F1EFE4", backgroundEndHex: "F1EFE4"),
                ThemeColorPreset(id: "muji-indigo", name: "Indigo", accentStartHex: "56677A", accentEndHex: "56677A", backgroundStartHex: "F1F0EA", backgroundEndHex: "F1F0EA"),
                ThemeColorPreset(id: "muji-ash", name: "Ash", accentStartHex: "7B776C", accentEndHex: "7B776C", backgroundStartHex: "F2F0EA", backgroundEndHex: "F2F0EA"),
                ThemeColorPreset(id: "muji-oat", name: "Oat", accentStartHex: "A9855F", accentEndHex: "A9855F", backgroundStartHex: "F8EFE2", backgroundEndHex: "F8EFE2"),
                ThemeColorPreset(id: "muji-moss", name: "Moss", accentStartHex: "69795F", accentEndHex: "69795F", backgroundStartHex: "EFF1E8", backgroundEndHex: "EFF1E8"),
                ThemeColorPreset(id: "muji-sumi", name: "Sumi", accentStartHex: "5F6561", accentEndHex: "5F6561", backgroundStartHex: "F1EEE6", backgroundEndHex: "F1EEE6"),
                ThemeColorPreset(id: "muji-ume", name: "Ume", accentStartHex: "A65D62", accentEndHex: "A65D62", backgroundStartHex: "F8ECE8", backgroundEndHex: "F8ECE8"),
                ThemeColorPreset(id: "muji-wheat", name: "Wheat", accentStartHex: "B48A52", accentEndHex: "B48A52", backgroundStartHex: "F7F0DD", backgroundEndHex: "F7F0DD"),
            ]
        case .neumorphic:
            return [
                ThemeColorPreset(id: "neu-mint", name: "Soft Mint", accentStartHex: "4F8E86", accentEndHex: "7D9475", backgroundStartHex: "E9EDF0", backgroundEndHex: "F2EEE8", backgroundHexes: ["E9EDF0", "F2EEE8", "E4ECE7", "EEF0F5"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "neu-dawn", name: "Dawn", accentStartHex: "C59A66", accentEndHex: "C65A58", backgroundStartHex: "EEE8E1", backgroundEndHex: "E7EDF0", backgroundHexes: ["EEE8E1", "E7EDF0", "F1E4D8", "E9EEF2"], gradientStyle: .linear),
                ThemeColorPreset(id: "neu-blue", name: "Quiet Blue", accentStartHex: "5E7FA4", accentEndHex: "7AB9B0", backgroundStartHex: "E8EDF4", backgroundEndHex: "F0F2F4", backgroundHexes: ["E8EDF4", "F0F2F4", "E3F0EF", "EEF4F7"], gradientStyle: .radial),
                ThemeColorPreset(id: "neu-sage", name: "Sage", accentStartHex: "6E8B70", accentEndHex: "96A874", backgroundStartHex: "E8EDE7", backgroundEndHex: "F4F0E8", backgroundHexes: ["E8EDE7", "F4F0E8", "EAF3E3", "F0ECE2"], gradientStyle: .mesh),
                ThemeColorPreset(id: "neu-apricot", name: "Apricot", accentStartHex: "C27B5E", accentEndHex: "C8A361", backgroundStartHex: "F0E8DF", backgroundEndHex: "EDF1EC", backgroundHexes: ["F0E8DF", "EDF1EC", "F4E3D8", "E8EEF1"], gradientStyle: .linear),
                ThemeColorPreset(id: "neu-lake", name: "Lake", accentStartHex: "4E8196", accentEndHex: "72A69B", backgroundStartHex: "E6EEF2", backgroundEndHex: "F2F0EA", backgroundHexes: ["E6EEF2", "F2F0EA", "DFECEB", "ECF3F5"], gradientStyle: .conic),
                ThemeColorPreset(id: "neu-milk", name: "Milk", accentStartHex: "8C7A65", accentEndHex: "8C7A65", backgroundStartHex: "F1EEE9", backgroundEndHex: "E8EDF1", backgroundHexes: ["F1EEE9", "E8EDF1", "F5F0E7", "E6ECEA"], gradientStyle: .mesh),
                ThemeColorPreset(id: "neu-rose", name: "Rose", accentStartHex: "A86E77", accentEndHex: "A86E77", backgroundStartHex: "F2E7E8", backgroundEndHex: "ECEFF3", backgroundHexes: ["F2E7E8", "ECEFF3", "F4DFE6", "E8EEF2"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "neu-celadon", name: "Celadon", accentStartHex: "5F8F78", accentEndHex: "5F8F78", backgroundStartHex: "E5EFEA", backgroundEndHex: "F2F0E7", backgroundHexes: ["E5EFEA", "F2F0E7", "DDEBE4", "EDF3F0"], gradientStyle: .radial),
                ThemeColorPreset(id: "neu-lilac", name: "Lilac", accentStartHex: "7B79A8", accentEndHex: "7B79A8", backgroundStartHex: "ECEAF4", backgroundEndHex: "E8EFF2", backgroundHexes: ["ECEAF4", "E8EFF2", "F3E8F1", "E4EEF4"], gradientStyle: .conic),
            ]
        case .capsule:
            return [
                ThemeColorPreset(id: "capsule-system", name: "System Blue", accentStartHex: "3867FF", accentEndHex: "3867FF", backgroundStartHex: "F6F8FF", backgroundEndHex: "EAF1FF", backgroundHexes: ["F6F8FF", "EAF1FF", "F8F2FF", "EDF9FF"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "capsule-mint", name: "Mint Dock", accentStartHex: "1AAE9F", accentEndHex: "1AAE9F", backgroundStartHex: "F3FBF8", backgroundEndHex: "EAF5FF", backgroundHexes: ["F3FBF8", "EAF5FF", "F7F3FF", "E9FAF4"], gradientStyle: .mesh),
                ThemeColorPreset(id: "capsule-coral", name: "Coral Pulse", accentStartHex: "EF6B73", accentEndHex: "EF6B73", backgroundStartHex: "FFF5F5", backgroundEndHex: "EEF5FF", backgroundHexes: ["FFF5F5", "EEF5FF", "FFF1E8", "F3F6FF"], gradientStyle: .radial),
                ThemeColorPreset(id: "capsule-lilac", name: "Lilac OS", accentStartHex: "7D6DFF", accentEndHex: "7D6DFF", backgroundStartHex: "F7F4FF", backgroundEndHex: "EAF6FF", backgroundHexes: ["F7F4FF", "EAF6FF", "FFF1FA", "EFFAF6"], gradientStyle: .conic),
                ThemeColorPreset(id: "capsule-sun", name: "Soft Sun", accentStartHex: "D89B2C", accentEndHex: "D89B2C", backgroundStartHex: "FFF8EA", backgroundEndHex: "EAF3FF", backgroundHexes: ["FFF8EA", "EAF3FF", "F7F0FF", "EDF9F2"], gradientStyle: .linear),
                ThemeColorPreset(id: "capsule-sky", name: "Sky Rail", accentStartHex: "2F8FE8", accentEndHex: "2F8FE8", backgroundStartHex: "F2F9FF", backgroundEndHex: "EEF3FF", backgroundHexes: ["F2F9FF", "EEF3FF", "E7FBFF", "F6F2FF"], gradientStyle: .mesh),
                ThemeColorPreset(id: "capsule-rose", name: "Rose Link", accentStartHex: "D75B8A", accentEndHex: "D75B8A", backgroundStartHex: "FFF3F8", backgroundEndHex: "EDF4FF", backgroundHexes: ["FFF3F8", "EDF4FF", "FFF0E6", "EFFAF5"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "capsule-sage", name: "Sage Grid", accentStartHex: "5C8B73", accentEndHex: "5C8B73", backgroundStartHex: "F4FAF4", backgroundEndHex: "EAF2FF", backgroundHexes: ["F4FAF4", "EAF2FF", "F6F1E8", "EDF7F1"], gradientStyle: .radial),
            ]
        case .petWhite:
            return [
                ThemeColorPreset(id: "petwhite-puppy", name: "Puppy", accentStartHex: "F6A93B", accentEndHex: "F6A93B", backgroundStartHex: "FFFFFF", backgroundEndHex: "F7F8FA", backgroundHexes: ["FFFFFF", "F7F8FA", "FFF5E1", "DDF5EE"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "petwhite-cat", name: "Cat", accentStartHex: "111111", accentEndHex: "111111", backgroundStartHex: "FFFFFF", backgroundEndHex: "F4F6F8", backgroundHexes: ["FFFFFF", "F4F6F8", "F0ECFF", "EEF4FF"], gradientStyle: .linear),
                ThemeColorPreset(id: "petwhite-mint", name: "Mint", accentStartHex: "30A98B", accentEndHex: "30A98B", backgroundStartHex: "FFFFFF", backgroundEndHex: "F5FAF8", backgroundHexes: ["FFFFFF", "F5FAF8", "F7F0FF", "FFF0E6"], gradientStyle: .radial),
                ThemeColorPreset(id: "petwhite-butter", name: "Butter", accentStartHex: "E39F23", accentEndHex: "E39F23", backgroundStartHex: "FFFFFF", backgroundEndHex: "FFF9EA", backgroundHexes: ["FFFFFF", "FFF9EA", "F7F5EE", "DDF5EE"], gradientStyle: .conic),
                ThemeColorPreset(id: "petwhite-sky", name: "Sky", accentStartHex: "3B82F6", accentEndHex: "3B82F6", backgroundStartHex: "FFFFFF", backgroundEndHex: "EEF4FF", backgroundHexes: ["FFFFFF", "EEF4FF", "F6F8FA", "F0ECFF"], gradientStyle: .mesh),
            ]
        case .manga:
            return [
                ThemeColorPreset(id: "manga-pop", name: "Pop", accentStartHex: "FF4F84", accentEndHex: "FF4F84", backgroundStartHex: "FFF3D7", backgroundEndHex: "E8F1FF", backgroundHexes: ["FFF3D7", "E8F1FF", "FFEAF4", "F8F6DE"], gradientStyle: .diffuse, mangaBlockAHex: "FFE067", mangaBlockBHex: "58B9FF", mangaBlockCHex: "8DE4B8", mangaStrokeHex: "3B3145", mangaSettingsIconHex: "17151F"),
                ThemeColorPreset(id: "manga-berry", name: "Berry", accentStartHex: "E65E8E", accentEndHex: "E65E8E", backgroundStartHex: "FFEAF0", backgroundEndHex: "F6F0FF", backgroundHexes: ["FFEAF0", "F6F0FF", "FFF0D9", "EAF7FF"], gradientStyle: .radial, mangaBlockAHex: "FFB4D2", mangaBlockBHex: "B391FF", mangaBlockCHex: "FFE7A3", mangaStrokeHex: "4B3A55", mangaSettingsIconHex: "2B2030"),
                ThemeColorPreset(id: "manga-soda", name: "Soda", accentStartHex: "4FA9FF", accentEndHex: "4FA9FF", backgroundStartHex: "EEF7FF", backgroundEndHex: "FFF1D8", backgroundHexes: ["EEF7FF", "FFF1D8", "E8FFF8", "FFECEF"], gradientStyle: .diffuse, mangaBlockAHex: "70D7FF", mangaBlockBHex: "FFE36D", mangaBlockCHex: "FF9C7E", mangaStrokeHex: "344B5E", mangaSettingsIconHex: "172C3A"),
                ThemeColorPreset(id: "manga-peach", name: "Peach", accentStartHex: "FF7A6E", accentEndHex: "FF7A6E", backgroundStartHex: "FFF0DF", backgroundEndHex: "FFE9F1", backgroundHexes: ["FFF0DF", "FFE9F1", "F0F7FF", "FFF7D8"], gradientStyle: .linear, mangaBlockAHex: "FFBC8D", mangaBlockBHex: "C7A7FF", mangaBlockCHex: "93D9B4", mangaStrokeHex: "5C4052", mangaSettingsIconHex: "2F222A"),
                ThemeColorPreset(id: "manga-lime", name: "Lime", accentStartHex: "7FBF5B", accentEndHex: "7FBF5B", backgroundStartHex: "F7F6D9", backgroundEndHex: "EAF7EC", backgroundHexes: ["F7F6D9", "EAF7EC", "FFF3CF", "E5F4FF"], gradientStyle: .mesh, mangaBlockAHex: "B8E76F", mangaBlockBHex: "FFE890", mangaBlockCHex: "5ECFA6", mangaStrokeHex: "465F4D", mangaSettingsIconHex: "203428"),
                ThemeColorPreset(id: "manga-candy", name: "Candy", accentStartHex: "F06DA6", accentEndHex: "F06DA6", backgroundStartHex: "FFF0FA", backgroundEndHex: "EAF6FF", backgroundHexes: ["FFF0FA", "EAF6FF", "FFF8D7", "F1EDFF"], gradientStyle: .radial, mangaBlockAHex: "FFA6D9", mangaBlockBHex: "8FE7E1", mangaBlockCHex: "C9A8FF", mangaStrokeHex: "694E67", mangaSettingsIconHex: "302039"),
                ThemeColorPreset(id: "manga-hero", name: "Hero", accentStartHex: "E94D5F", accentEndHex: "E94D5F", backgroundStartHex: "FFF2D8", backgroundEndHex: "E9F2FF", backgroundHexes: ["FFF2D8", "E9F2FF", "FFE5E7", "EAF9E6"], gradientStyle: .conic, mangaBlockAHex: "FFDB56", mangaBlockBHex: "6BCBFF", mangaBlockCHex: "FF7A7A", mangaStrokeHex: "423647", mangaSettingsIconHex: "201B25"),
                ThemeColorPreset(id: "manga-nightpop", name: "Night Pop", accentStartHex: "8C6CFF", accentEndHex: "8C6CFF", backgroundStartHex: "F4F0FF", backgroundEndHex: "EAF7FF", backgroundHexes: ["F4F0FF", "EAF7FF", "FFEFF9", "FFF7D9"], gradientStyle: .mesh, mangaBlockAHex: "B79AFF", mangaBlockBHex: "69D7FF", mangaBlockCHex: "FFDA69", mangaStrokeHex: "3F3862", mangaSettingsIconHex: "1F1B34"),
                ThemeColorPreset(id: "manga-melon", name: "Melon", accentStartHex: "55B77B", accentEndHex: "55B77B", backgroundStartHex: "F1F9DD", backgroundEndHex: "EAF7F0", backgroundHexes: ["F1F9DD", "EAF7F0", "FFF0D3", "EAF4FF"], gradientStyle: .diffuse, mangaBlockAHex: "C7EB65", mangaBlockBHex: "82D8B2", mangaBlockCHex: "FFBD79", mangaStrokeHex: "3D5845", mangaSettingsIconHex: "1F3327"),
                ThemeColorPreset(id: "manga-bubblegum", name: "Bubble", accentStartHex: "FF6FAF", accentEndHex: "FF6FAF", backgroundStartHex: "FFF0FB", backgroundEndHex: "F0F6FF", backgroundHexes: ["FFF0FB", "F0F6FF", "FFEADB", "EFFFF8"], gradientStyle: .conic, mangaBlockAHex: "FFA6D6", mangaBlockBHex: "9DE7FF", mangaBlockCHex: "FFE46E", mangaStrokeHex: "62435E", mangaSettingsIconHex: "302033"),
            ]
        case .default:
            return [
                ThemeColorPreset(id: "default-mist", name: "Mist", accentStartHex: "4D6F95", accentEndHex: "4D6F95", backgroundStartHex: "F8FAFC", backgroundEndHex: "E6EDF6", backgroundHexes: ["F8FAFC", "E6EDF6", "EEF4EE", "F6F1EA"], gradientStyle: .diffuse),
                ThemeColorPreset(id: defaultCatPawPresetId, name: "Cat Paw", accentStartHex: "FF9B83", accentEndHex: "FF9B83", backgroundStartHex: "FFF7EC", backgroundEndHex: "FFE7D8", backgroundHexes: ["FFF7EC", "FFE7D8", "F2F8EF", "EAF4FF"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "default-dawn", name: "Dawn", accentStartHex: "B66E57", accentEndHex: "B66E57", backgroundStartHex: "FFF6EB", backgroundEndHex: "EAF0FA", backgroundHexes: ["FFF6EB", "EAF0FA", "FFEAE2", "EEF8F5"], gradientStyle: .linear),
                ThemeColorPreset(id: "default-lake", name: "Lake", accentStartHex: "4D8196", accentEndHex: "4D8196", backgroundStartHex: "EEF6FA", backgroundEndHex: "E9F2EC", backgroundHexes: ["EEF6FA", "E9F2EC", "F7F5EC", "E6F1F8"], gradientStyle: .radial),
                ThemeColorPreset(id: "default-sage", name: "Sage", accentStartHex: "6A8368", accentEndHex: "6A8368", backgroundStartHex: "F5F7EF", backgroundEndHex: "E8EFE7", backgroundHexes: ["F5F7EF", "E8EFE7", "F7F1E7", "EEF4F0"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "default-iris", name: "Iris", accentStartHex: "6E72A7", accentEndHex: "6E72A7", backgroundStartHex: "F6F4FB", backgroundEndHex: "E9EEF8", backgroundHexes: ["F6F4FB", "E9EEF8", "F4ECF8", "EEF7FA"], gradientStyle: .mesh),
                ThemeColorPreset(id: "default-clay", name: "Clay", accentStartHex: "9F7559", accentEndHex: "9F7559", backgroundStartHex: "F8F1EA", backgroundEndHex: "EAF0F3", backgroundHexes: ["F8F1EA", "EAF0F3", "F4E8DD", "EEF5EF"], gradientStyle: .conic),
                ThemeColorPreset(id: "default-sky", name: "Sky", accentStartHex: "497FAF", accentEndHex: "497FAF", backgroundStartHex: "F1F7FD", backgroundEndHex: "E9F1F7", backgroundHexes: ["F1F7FD", "E9F1F7", "F7F6EE", "EAF8F4"], gradientStyle: .linear),
                ThemeColorPreset(id: "default-plum", name: "Plum", accentStartHex: "8E668A", accentEndHex: "8E668A", backgroundStartHex: "F8F2F8", backgroundEndHex: "EAF0F6", backgroundHexes: ["F8F2F8", "EAF0F6", "F6EAEF", "EEF7F5"], gradientStyle: .radial),
                ThemeColorPreset(id: "default-cedar", name: "Cedar", accentStartHex: "547760", accentEndHex: "547760", backgroundStartHex: "F3F6EF", backgroundEndHex: "E7EFEA", backgroundHexes: ["F3F6EF", "E7EFEA", "F7F1E5", "ECF3F5"], gradientStyle: .mesh),
                ThemeColorPreset(id: "default-amber", name: "Amber", accentStartHex: "A9793E", accentEndHex: "A9793E", backgroundStartHex: "FFF7E8", backgroundEndHex: "EAF1F4", backgroundHexes: ["FFF7E8", "EAF1F4", "F6EBD8", "EEF8F4"], gradientStyle: .diffuse),
            ]
        }
    }

}
