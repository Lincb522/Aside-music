import CryptoKit
import Foundation
@preconcurrency import Combine

enum MonoAudioAgentBuiltInSkill: String, CaseIterable, Identifiable, Sendable {
    case measurementEvidence
    case deviceCoordination
    case headroomGuard
    case phaseGuard
    case outputValidation
    case artistReference
    case vocalReference

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .measurementEvidence: return "audio_agent_skill_measurement"
        case .deviceCoordination: return "audio_agent_skill_device"
        case .headroomGuard: return "audio_agent_skill_headroom"
        case .phaseGuard: return "audio_agent_skill_phase"
        case .outputValidation: return "audio_agent_skill_validation"
        case .artistReference: return "audio_agent_skill_artist"
        case .vocalReference: return "audio_agent_skill_vocal"
        }
    }

    var detailKey: String {
        switch self {
        case .measurementEvidence: return "audio_agent_skill_measurement_detail"
        case .deviceCoordination: return "audio_agent_skill_device_detail"
        case .headroomGuard: return "audio_agent_skill_headroom_detail"
        case .phaseGuard: return "audio_agent_skill_phase_detail"
        case .outputValidation: return "audio_agent_skill_validation_detail"
        case .artistReference: return "audio_agent_skill_artist_detail"
        case .vocalReference: return "audio_agent_skill_vocal_detail"
        }
    }

    var isRequired: Bool {
        switch self {
        case .measurementEvidence, .deviceCoordination, .headroomGuard, .phaseGuard, .outputValidation:
            return true
        case .artistReference, .vocalReference:
            return false
        }
    }
}

struct MonoAudioCustomSkill: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var instruction: String
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        instruction: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum MonoAudioAgentSkillConfigurationSource: String, Sendable {
    case bundled
    case cached
    case server
}

enum MonoAudioResolvedSkillSource: String, Codable, Sendable {
    case server
    case device
}

struct MonoAudioResolvedCustomSkill: Identifiable, Equatable, Sendable {
    let id: String
    let remoteID: String?
    let localID: UUID?
    let name: String
    let instruction: String
    let source: MonoAudioResolvedSkillSource
    let configuredEnabled: Bool
    let isEnabled: Bool

    var isLimited: Bool { configuredEnabled && !isEnabled }
}

struct MonoAudioAgentRuntimeSkillConfiguration: Equatable, Sendable {
    let modelContext: String
    let fingerprint: String
    let revision: String
    let toolPolicy: AppAgentToolPolicyConfiguration?
    let enabledSkillIDs: [String]
    let requiredSkillIDs: [String]
    let customSkills: [MonoAudioResolvedCustomSkill]
}

struct MonoAudioAgentSkillCloudSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let revision: Int
    let updatedAt: Date
    /// `nil` means the user has not overridden the server-managed default on
    /// this device. Keeping that distinction prevents a cloud restore from
    /// freezing a formerly remote default into a permanent local preference.
    let artistReferenceEnabled: Bool?
    let vocalReferenceEnabled: Bool?
    let customSkills: [MonoAudioCustomSkill]
}

@MainActor
final class MonoAudioAgentSkillStore: ObservableObject {
    static let shared = MonoAudioAgentSkillStore()

    static let maximumCustomSkillCount = 12
    static let maximumRemoteCustomSkillCount = 12
    static let maximumEnabledCustomSkillCount = 4
    static let maximumRemoteCustomSkillIDLength = 80
    static let maximumNameLength = 20
    static let maximumInstructionLength = 120

    @Published var artistReferenceEnabled: Bool {
        didSet {
            guard !isApplyingState else { return }
            defaults.set(artistReferenceEnabled, forKey: Self.artistReferenceKey)
            recordLocalMutation()
        }
    }
    @Published var vocalReferenceEnabled: Bool {
        didSet {
            guard !isApplyingState else { return }
            defaults.set(vocalReferenceEnabled, forKey: Self.vocalReferenceKey)
            recordLocalMutation()
        }
    }
    @Published private(set) var customSkills: [MonoAudioCustomSkill]
    @Published private(set) var resolvedCustomSkills: [MonoAudioResolvedCustomSkill] = []
    @Published private(set) var configurationSource: MonoAudioAgentSkillConfigurationSource = .bundled
    @Published private(set) var skillRevision = "bundled-v1.local0"
    @Published private(set) var skillFingerprint = ""
    @Published private(set) var lastServerSyncAt: Date?
    @Published private(set) var remoteSkillCount = 0

    private static let artistReferenceKey = "audio.agent.skill.artist-reference"
    private static let vocalReferenceKey = "audio.agent.skill.vocal-reference"
    private static let customSkillsKey = "audio.agent.custom-skills.v1"
    private static let localRevisionKey = "audio.agent.skills.local-revision.v1"
    private static let localUpdatedAtKey = "audio.agent.skills.local-updated-at.v1"

    private let defaults: UserDefaults
    private var isApplyingState = false
    private var remoteSkillConfiguration: AppAgentSkillConfiguration?
    private var remoteToolPolicy: AppAgentToolPolicyConfiguration?
    private var localRevision: Int
    private var localUpdatedAt: Date

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let cachedAgent = SongContentConfigurationStore.cachedAgentConfiguration(.equalizer)
        let cachedSkills = cachedAgent?.resolvedSkillConfiguration
        remoteSkillConfiguration = cachedSkills
        remoteToolPolicy = cachedAgent?.toolPolicy
        configurationSource = (cachedSkills == nil && cachedAgent?.toolPolicy == nil) ? .bundled : .cached

        let artistDefault = cachedSkills?.builtIns?.artistReference ?? true
        let vocalDefault = cachedSkills?.builtIns?.vocalReference ?? true
        artistReferenceEnabled = defaults.object(forKey: Self.artistReferenceKey) == nil
            ? artistDefault
            : defaults.bool(forKey: Self.artistReferenceKey)
        vocalReferenceEnabled = defaults.object(forKey: Self.vocalReferenceKey) == nil
            ? vocalDefault
            : defaults.bool(forKey: Self.vocalReferenceKey)
        customSkills = Self.loadCustomSkills(from: defaults)
        localRevision = max(0, defaults.integer(forKey: Self.localRevisionKey))
        localUpdatedAt = defaults.object(forKey: Self.localUpdatedAtKey) as? Date ?? .distantPast
        rebuildResolvedState()
    }

    var enabledCustomSkillCount: Int {
        resolvedCustomSkills.lazy.filter(\.isEnabled).count
    }

    var hasRemoteSkills: Bool {
        remoteSkillConfiguration != nil || remoteToolPolicy != nil
    }

    func isEnabled(_ skill: MonoAudioAgentBuiltInSkill) -> Bool {
        switch skill {
        case .artistReference: return artistReferenceEnabled
        case .vocalReference: return vocalReferenceEnabled
        default: return true
        }
    }

    func source(for skill: MonoAudioAgentBuiltInSkill) -> MonoAudioResolvedSkillSource? {
        guard !skill.isRequired else { return remoteSkillConfiguration == nil ? nil : .server }
        let key = skill == .artistReference ? Self.artistReferenceKey : Self.vocalReferenceKey
        if defaults.object(forKey: key) != nil { return .device }
        return remoteSkillConfiguration == nil ? nil : .server
    }

    func setEnabled(_ enabled: Bool, for skill: MonoAudioAgentBuiltInSkill) {
        guard !skill.isRequired else { return }
        switch skill {
        case .artistReference:
            artistReferenceEnabled = enabled
        case .vocalReference:
            vocalReferenceEnabled = enabled
        default:
            break
        }
    }

    @discardableResult
    func saveCustomSkill(
        id: UUID?,
        name: String,
        instruction: String,
        isEnabled: Bool
    ) -> MonoAudioCustomSkill? {
        let normalizedName = normalize(name, maximumLength: Self.maximumNameLength)
        let normalizedInstruction = normalize(
            instruction,
            maximumLength: Self.maximumInstructionLength
        )
        guard !normalizedName.isEmpty,
              !normalizedInstruction.isEmpty,
              !hasDuplicateName(normalizedName, excluding: id) else { return nil }

        let now = Date()
        let saved: MonoAudioCustomSkill
        if let id, let index = customSkills.firstIndex(where: { $0.id == id }) {
            var updated = customSkills[index]
            updated.name = normalizedName
            updated.instruction = normalizedInstruction
            updated.isEnabled = normalizedEnabledState(isEnabled, excluding: id)
            updated.updatedAt = now
            customSkills[index] = updated
            saved = updated
        } else {
            guard customSkills.count < Self.maximumCustomSkillCount else { return nil }
            let created = MonoAudioCustomSkill(
                name: normalizedName,
                instruction: normalizedInstruction,
                isEnabled: normalizedEnabledState(isEnabled, excluding: nil),
                createdAt: now,
                updatedAt: now
            )
            customSkills.append(created)
            saved = created
        }
        persistCustomSkills()
        recordLocalMutation()
        return saved
    }

    func setCustomSkillEnabled(_ enabled: Bool, id: UUID) {
        guard let index = customSkills.firstIndex(where: { $0.id == id }) else { return }
        customSkills[index].isEnabled = normalizedEnabledState(enabled, excluding: id)
        customSkills[index].updatedAt = Date()
        persistCustomSkills()
        recordLocalMutation()
    }

    func deleteCustomSkill(id: UUID) {
        let previousCount = customSkills.count
        customSkills.removeAll { $0.id == id }
        guard customSkills.count != previousCount else { return }
        persistCustomSkills()
        recordLocalMutation()
    }

    func makeCloudSnapshot() -> MonoAudioAgentSkillCloudSnapshot {
        MonoAudioAgentSkillCloudSnapshot(
            schemaVersion: MonoAudioAgentSkillCloudSnapshot.currentSchemaVersion,
            revision: localRevision,
            updatedAt: localUpdatedAt,
            artistReferenceEnabled: defaults.object(forKey: Self.artistReferenceKey) == nil
                ? nil
                : artistReferenceEnabled,
            vocalReferenceEnabled: defaults.object(forKey: Self.vocalReferenceKey) == nil
                ? nil
                : vocalReferenceEnabled,
            customSkills: customSkills
        )
    }

    func mergeCloudSnapshot(_ snapshot: MonoAudioAgentSkillCloudSnapshot) {
        guard snapshot.schemaVersion <= MonoAudioAgentSkillCloudSnapshot.currentSchemaVersion,
              shouldAccept(snapshot) else { return }

        isApplyingState = true
        artistReferenceEnabled = snapshot.artistReferenceEnabled
            ?? remoteSkillConfiguration?.builtIns?.artistReference
            ?? true
        vocalReferenceEnabled = snapshot.vocalReferenceEnabled
            ?? remoteSkillConfiguration?.builtIns?.vocalReference
            ?? true
        customSkills = sanitizedCloudSkills(snapshot.customSkills)
        isApplyingState = false

        localRevision = max(localRevision, snapshot.revision)
        localUpdatedAt = snapshot.updatedAt
        persistAllLocalState(
            artistOverride: snapshot.artistReferenceEnabled,
            vocalOverride: snapshot.vocalReferenceEnabled
        )
        rebuildResolvedState()
    }

    /// Called by `SongContentConfigurationStore` before returning an Agent
    /// configuration. This makes the freshly fetched remote skills visible to
    /// both the UI and the same generation request without a notification race.
    func applyRemoteAgentConfiguration(
        _ configuration: AppAgentConfiguration?,
        source: MonoAudioAgentSkillConfigurationSource
    ) {
        let incomingSkills = configuration?.resolvedSkillConfiguration
        let incomingToolPolicy = configuration?.toolPolicy
        let preservesCurrentServerState = source == .cached
            && configurationSource == .server
            && incomingSkills == remoteSkillConfiguration
            && incomingToolPolicy == remoteToolPolicy
        remoteSkillConfiguration = incomingSkills
        remoteToolPolicy = incomingToolPolicy
        if remoteSkillConfiguration == nil && remoteToolPolicy == nil {
            configurationSource = .bundled
        } else if !preservesCurrentServerState {
            configurationSource = source
        }
        if source == .server, configurationSource == .server {
            lastServerSyncAt = Date()
        }

        isApplyingState = true
        if defaults.object(forKey: Self.artistReferenceKey) == nil {
            artistReferenceEnabled = remoteSkillConfiguration?.builtIns?.artistReference ?? true
        }
        if defaults.object(forKey: Self.vocalReferenceKey) == nil {
            vocalReferenceEnabled = remoteSkillConfiguration?.builtIns?.vocalReference ?? true
        }
        isApplyingState = false
        rebuildResolvedState()
    }

    func refreshRemoteConfiguration(forceRefresh: Bool = false) async {
        _ = await SongContentConfigurationStore.shared.configuration(forceRefresh: forceRefresh)
    }

    /// Stable runtime snapshot consumed by the generation chain. The explicit
    /// skill and tool-policy values bind this snapshot to one exact Agent payload
    /// while local preferences are read atomically.
    func runtimeConfiguration(
        adaptiveLearningEnabled: Bool,
        remoteConfiguration: AppAgentSkillConfiguration?,
        remoteToolPolicy: AppAgentToolPolicyConfiguration?
    ) -> MonoAudioAgentRuntimeSkillConfiguration {
        let skills = remoteConfiguration
        let requiredIDs = MonoAudioAgentBuiltInSkill.allCases
            .filter(\.isRequired)
            .map(\.rawValue)
        let artistEnabled = resolvedOptionalFlag(
            key: Self.artistReferenceKey,
            localValue: artistReferenceEnabled,
            remoteValue: skills?.builtIns?.artistReference
        )
        let vocalEnabled = resolvedOptionalFlag(
            key: Self.vocalReferenceKey,
            localValue: vocalReferenceEnabled,
            remoteValue: skills?.builtIns?.vocalReference
        )
        let custom = mergedCustomSkills(remoteConfiguration: skills)
        let enabledCustom = custom.filter(\.isEnabled)
        let safeToolPolicy = (remoteToolPolicy ?? .bundledSafeDefault).resolvedSafePolicy
        let remoteRevision = compactPromptValue(
            skills?.revision ?? "bundled-v1",
            maximumLength: 48
        )
        let revision = "\(remoteRevision.isEmpty ? "bundled-v1" : remoteRevision).local\(localRevision)"

        var enabledIDs = requiredIDs
        if artistEnabled { enabledIDs.append(MonoAudioAgentBuiltInSkill.artistReference.rawValue) }
        if vocalEnabled { enabledIDs.append(MonoAudioAgentBuiltInSkill.vocalReference.rawValue) }
        enabledIDs.append(contentsOf: enabledCustom.map { "custom.\($0.id)" })

        let customCanonical = enabledCustom.map {
            "\($0.id)=\(compactPromptValue($0.name, maximumLength: Self.maximumNameLength)):\(compactPromptValue($0.instruction, maximumLength: Self.maximumInstructionLength))"
        }.joined(separator: "|")
        let canonical = [
            "schema=mono-audio-agent-skills/v2",
            "revision=\(revision)",
            "required=\(requiredIDs.joined(separator: ","))",
            "artist=\(artistEnabled ? 1 : 0)",
            "vocal=\(vocalEnabled ? 1 : 0)",
            "learning=\(adaptiveLearningEnabled ? 1 : 0)",
            "custom=\(customCanonical.isEmpty ? "none" : customCanonical)",
            "tool=\(safeToolPolicy.requiredToolName ?? "mono_audio_tuning")",
            "toolRevision=\(safeToolPolicy.revision ?? "bundled-v1")",
            "mode=\(safeToolPolicy.invocationMode ?? "required")",
            "once=1",
            "localValidation=1",
            "promptFallback=\((safeToolPolicy.allowPromptFallback ?? false) ? 1 : 0)"
        ].joined(separator: ";")
        let fingerprint = Self.sha256(canonical)

        let customEnvelope = enabledCustom.map {
            let name = compactPromptValue($0.name, maximumLength: Self.maximumNameLength)
            let instruction = compactPromptValue(
                $0.instruction,
                maximumLength: Self.maximumInstructionLength
            )
            return "\(name):\(instruction)"
        }.joined(separator: " | ")
        let modelContext = "schema=mono-audio-agent-skills/v2; revision=\(revision); fingerprint=\(fingerprint); core=measurement,device,headroom,phase,validation; optional=artist=\(artistEnabled ? 1 : 0),vocal=\(vocalEnabled ? 1 : 0),learning=\(adaptiveLearningEnabled ? 1 : 0); custom=\(customEnvelope.isEmpty ? "none" : customEnvelope); tool=\(safeToolPolicy.requiredToolName ?? "mono_audio_tuning"),mode=\(safeToolPolicy.invocationMode ?? "required"),once=1,localValidation=1. Core rules override optional and custom skills."

        return MonoAudioAgentRuntimeSkillConfiguration(
            modelContext: modelContext,
            fingerprint: fingerprint,
            revision: revision,
            toolPolicy: safeToolPolicy,
            enabledSkillIDs: enabledIDs,
            requiredSkillIDs: requiredIDs,
            customSkills: custom
        )
    }

    /// Backward-compatible convenience used by existing generation code.
    func modelContextEnvelope(adaptiveLearningEnabled: Bool) -> String {
        runtimeConfiguration(
            adaptiveLearningEnabled: adaptiveLearningEnabled,
            remoteConfiguration: remoteSkillConfiguration,
            remoteToolPolicy: remoteToolPolicy
        ).modelContext
    }

    private func resolvedOptionalFlag(
        key: String,
        localValue: Bool,
        remoteValue: Bool?
    ) -> Bool {
        defaults.object(forKey: key) == nil ? (remoteValue ?? true) : localValue
    }

    private func normalizedEnabledState(_ requested: Bool, excluding id: UUID?) -> Bool {
        guard requested else { return false }
        let enabledOutsideCurrent = mergedCustomSkills(remoteConfiguration: remoteSkillConfiguration)
            .lazy
            .filter { $0.isEnabled && $0.localID != id }
            .count
        return enabledOutsideCurrent < Self.maximumEnabledCustomSkillCount
    }

    private func hasDuplicateName(_ name: String, excluding id: UUID?) -> Bool {
        let key = normalizedIdentity(name)
        guard !key.isEmpty else { return true }
        if normalizedRemoteSkills(remoteSkillConfiguration).contains(where: { normalizedIdentity($0.name) == key }) {
            return true
        }
        return customSkills.contains {
            $0.id != id && normalizedIdentity($0.name) == key
        }
    }

    private func mergedCustomSkills(
        remoteConfiguration: AppAgentSkillConfiguration?
    ) -> [MonoAudioResolvedCustomSkill] {
        let remote = normalizedRemoteSkills(remoteConfiguration)
        let sortedLocal = customSkills.sorted {
            let lhs = normalizedIdentity($0.name)
            let rhs = normalizedIdentity($1.name)
            return lhs == rhs ? $0.id.uuidString < $1.id.uuidString : lhs < rhs
        }

        var candidates = remote
        var seenIDs = Set(remote.compactMap { $0.remoteID?.lowercased() })
        var seenNames = Set(remote.map { normalizedIdentity($0.name) })
        for skill in sortedLocal {
            let idKey = skill.id.uuidString.lowercased()
            let nameKey = normalizedIdentity(skill.name)
            guard !seenIDs.contains(idKey), !seenNames.contains(nameKey) else { continue }
            seenIDs.insert(idKey)
            seenNames.insert(nameKey)
            candidates.append(
                MonoAudioResolvedCustomSkill(
                    id: "device:\(idKey)",
                    remoteID: nil,
                    localID: skill.id,
                    name: normalize(skill.name, maximumLength: Self.maximumNameLength),
                    instruction: normalize(
                        skill.instruction,
                        maximumLength: Self.maximumInstructionLength
                    ),
                    source: .device,
                    configuredEnabled: skill.isEnabled,
                    isEnabled: skill.isEnabled
                )
            )
        }

        var enabledSlots = Self.maximumEnabledCustomSkillCount
        return candidates.map { skill in
            let effectiveEnabled = skill.configuredEnabled && enabledSlots > 0
            if effectiveEnabled { enabledSlots -= 1 }
            return MonoAudioResolvedCustomSkill(
                id: skill.id,
                remoteID: skill.remoteID,
                localID: skill.localID,
                name: skill.name,
                instruction: skill.instruction,
                source: skill.source,
                configuredEnabled: skill.configuredEnabled,
                isEnabled: effectiveEnabled
            )
        }
    }

    private func normalizedRemoteSkills(
        _ configuration: AppAgentSkillConfiguration?
    ) -> [MonoAudioResolvedCustomSkill] {
        let values = Array((configuration?.custom ?? []).prefix(Self.maximumRemoteCustomSkillCount))
        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        var result: [MonoAudioResolvedCustomSkill] = []

        for value in values {
            let name = normalize(value.name ?? "", maximumLength: Self.maximumNameLength)
            let instruction = normalize(
                value.instruction ?? "",
                maximumLength: Self.maximumInstructionLength
            )
            guard !name.isEmpty, !instruction.isEmpty else { continue }
            let remoteID = normalize(
                value.id ?? "",
                maximumLength: Self.maximumRemoteCustomSkillIDLength
            )
            let idKey = remoteID.lowercased()
            let nameKey = normalizedIdentity(name)
            guard (idKey.isEmpty || !seenIDs.contains(idKey)), !seenNames.contains(nameKey) else { continue }
            if !idKey.isEmpty { seenIDs.insert(idKey) }
            seenNames.insert(nameKey)
            result.append(
                MonoAudioResolvedCustomSkill(
                    id: "server:\(idKey.isEmpty ? nameKey : idKey)",
                    remoteID: remoteID.isEmpty ? nil : remoteID,
                    localID: nil,
                    name: name,
                    instruction: instruction,
                    source: .server,
                    configuredEnabled: value.resolvedEnabled,
                    isEnabled: value.resolvedEnabled
                )
            )
        }

        return result.sorted {
            let lhs = normalizedIdentity($0.name)
            let rhs = normalizedIdentity($1.name)
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
    }

    private func rebuildResolvedState() {
        let runtime = runtimeConfiguration(
            adaptiveLearningEnabled: false,
            remoteConfiguration: remoteSkillConfiguration,
            remoteToolPolicy: remoteToolPolicy
        )
        resolvedCustomSkills = runtime.customSkills
        skillRevision = runtime.revision
        skillFingerprint = runtime.fingerprint
        remoteSkillCount = runtime.customSkills.lazy.filter { $0.source == .server }.count
    }

    private func recordLocalMutation() {
        localRevision = localRevision == Int.max ? 1 : localRevision + 1
        localUpdatedAt = Date()
        defaults.set(localRevision, forKey: Self.localRevisionKey)
        defaults.set(localUpdatedAt, forKey: Self.localUpdatedAtKey)
        rebuildResolvedState()
    }

    private func persistCustomSkills() {
        guard let data = try? JSONEncoder().encode(customSkills) else { return }
        defaults.set(data, forKey: Self.customSkillsKey)
    }

    private func persistAllLocalState(
        artistOverride: Bool?,
        vocalOverride: Bool?
    ) {
        if let artistOverride {
            defaults.set(artistOverride, forKey: Self.artistReferenceKey)
        } else {
            defaults.removeObject(forKey: Self.artistReferenceKey)
        }
        if let vocalOverride {
            defaults.set(vocalOverride, forKey: Self.vocalReferenceKey)
        } else {
            defaults.removeObject(forKey: Self.vocalReferenceKey)
        }
        defaults.set(localRevision, forKey: Self.localRevisionKey)
        defaults.set(localUpdatedAt, forKey: Self.localUpdatedAtKey)
        persistCustomSkills()
    }

    private func shouldAccept(_ snapshot: MonoAudioAgentSkillCloudSnapshot) -> Bool {
        if snapshot.updatedAt != localUpdatedAt { return snapshot.updatedAt > localUpdatedAt }
        if snapshot.revision != localRevision { return snapshot.revision > localRevision }
        let incoming = Self.cloudCanonical(snapshot)
        let current = Self.cloudCanonical(makeCloudSnapshot())
        return incoming > current
    }

    private func sanitizedCloudSkills(_ skills: [MonoAudioCustomSkill]) -> [MonoAudioCustomSkill] {
        var seenIDs = Set<UUID>()
        var seenNames = Set<String>()
        var result: [MonoAudioCustomSkill] = []
        for skill in skills.prefix(Self.maximumCustomSkillCount) {
            let name = normalize(skill.name, maximumLength: Self.maximumNameLength)
            let instruction = normalize(
                skill.instruction,
                maximumLength: Self.maximumInstructionLength
            )
            let nameKey = normalizedIdentity(name)
            guard !name.isEmpty,
                  !instruction.isEmpty,
                  !seenIDs.contains(skill.id),
                  !seenNames.contains(nameKey) else { continue }
            seenIDs.insert(skill.id)
            seenNames.insert(nameKey)
            result.append(
                MonoAudioCustomSkill(
                    id: skill.id,
                    name: name,
                    instruction: instruction,
                    isEnabled: skill.isEnabled,
                    createdAt: skill.createdAt,
                    updatedAt: skill.updatedAt
                )
            )
        }
        return result
    }

    private func normalize(_ value: String, maximumLength: Int) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(maximumLength))
    }

    private func normalizedIdentity(_ value: String) -> String {
        normalize(value, maximumLength: Self.maximumNameLength)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private func compactPromptValue(_ value: String, maximumLength: Int) -> String {
        normalize(value, maximumLength: maximumLength)
            .replacingOccurrences(of: "|", with: "/")
            .replacingOccurrences(of: ":", with: "：")
            .replacingOccurrences(of: ";", with: "，")
            .replacingOccurrences(of: "=", with: "-")
    }

    private static func loadCustomSkills(from defaults: UserDefaults) -> [MonoAudioCustomSkill] {
        guard let data = defaults.data(forKey: customSkillsKey),
              let decoded = try? JSONDecoder().decode([MonoAudioCustomSkill].self, from: data) else {
            return []
        }
        return Array(decoded.prefix(maximumCustomSkillCount))
    }

    private static func cloudCanonical(_ skills: [MonoAudioCustomSkill]) -> String {
        skills.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            "\($0.id.uuidString)|\($0.name)|\($0.instruction)|\($0.isEnabled ? 1 : 0)|\($0.updatedAt.timeIntervalSince1970)"
        }.joined(separator: ";")
    }

    private static func cloudCanonical(_ snapshot: MonoAudioAgentSkillCloudSnapshot) -> String {
        let artist = snapshot.artistReferenceEnabled.map { $0 ? "1" : "0" } ?? "inherit"
        let vocal = snapshot.vocalReferenceEnabled.map { $0 ? "1" : "0" } ?? "inherit"
        return "artist=\(artist);vocal=\(vocal);custom=\(cloudCanonical(snapshot.customSkills))"
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
