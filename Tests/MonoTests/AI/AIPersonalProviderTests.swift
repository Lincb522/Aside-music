import XCTest
@testable import Mono

final class AIPersonalProviderTests: XCTestCase {
    private func customSettings() -> AIPersonalProviderSettings {
        var settings = AIPersonalProviderSettings()
        settings.isEnabled = true
        settings.configuration.baseURL = "https://custom.example.invalid/v1"
        settings.configuration.model = "custom-model"
        settings.apiKey = "synthetic-custom-key"
        return settings
    }

    private func defaultContext() -> AIProviderRequestContext {
        var configuration = customSettings().configuration
        configuration.baseURL = "https://default.example.invalid/v1"
        configuration.model = "default-model"
        return AIProviderRequestContext(
            configuration: configuration,
            apiKey: "synthetic-default-key",
            usageLimits: AIUsageLimits(dailyRequestLimit: 1, hourlyRequestLimit: 1, minimumRequestInterval: 15),
            persistsDiscoveredModel: false
        )
    }

    func testCustomRequestsDoNotReadDefaultCredentialsOrConsumeDefaultQuota() throws {
        let context = try AIProviderRequestContext.resolve(personal: customSettings()) {
            XCTFail("An enabled custom provider must not resolve the default provider.")
            return self.defaultContext()
        }
        XCTAssertEqual(context.configuration.resolvedBaseURL, "https://custom.example.invalid/v1")
        XCTAssertEqual(context.apiKey, "synthetic-custom-key")
        XCTAssertNil(context.usageLimits)
        XCTAssertFalse(context.persistsDiscoveredModel)
    }

    func testDisablingCustomProviderRestoresDefaultServiceAndQuota() throws {
        var settings = customSettings()
        settings.isEnabled = false
        let context = try AIProviderRequestContext.resolve(personal: settings, defaultContext: defaultContext)
        XCTAssertEqual(context.configuration.resolvedModel, "default-model")
        XCTAssertEqual(context.apiKey, "synthetic-default-key")
        XCTAssertEqual(context.usageLimits?.dailyRequestLimit, 1)
    }

    func testInvalidEnabledConfigurationDoesNotFallBackToDefaultCredentials() {
        var settings = customSettings()
        settings.configuration.baseURL = "file:///tmp/model"
        XCTAssertThrowsError(try AIProviderRequestContext.resolve(personal: settings) {
            XCTFail("Invalid custom configuration must not silently select the default service.")
            return self.defaultContext()
        })
    }

    func testRequestKeepsItsCredentialsAfterSettingsChange() throws {
        var settings = customSettings()
        let context = try AIProviderRequestContext.resolve(personal: settings, defaultContext: defaultContext)
        settings.apiKey = "synthetic-replacement-key"
        settings.configuration.baseURL = "https://replacement.example.invalid/v1"
        XCTAssertEqual(context.apiKey, "synthetic-custom-key")
        XCTAssertEqual(context.configuration.baseURL, "https://custom.example.invalid/v1")
    }

    func testRejectsMissingModelMissingRequiredKeyAndEmbeddedCredentials() {
        var settings = customSettings()
        settings.configuration.model = "  "
        XCTAssertThrowsError(try settings.validated())
        settings = customSettings()
        settings.configuration.wireProtocol = .anthropicMessages
        settings.apiKey = "  "
        XCTAssertThrowsError(try settings.validated())
        settings = customSettings()
        settings.configuration.baseURL = "https://synthetic:credential@example.invalid/v1"
        XCTAssertThrowsError(try settings.validated())
    }

    func testNormalizesInputAndAllowsDisablingIncompleteConfiguration() throws {
        var settings = customSettings()
        settings.configuration.baseURL = "  https://custom.example.invalid/v1\n"
        settings.configuration.model = " custom-model "
        settings.apiKey = " synthetic-custom-key\n"
        XCTAssertEqual(try settings.validated(), customSettings())
        settings.configuration.baseURL = ""
        settings.configuration.model = ""
        settings.isEnabled = false
        XCTAssertFalse(try settings.validated().isEnabled)
    }

    @MainActor
    func testPersistsOneCompleteConfigurationAndReloadsIt() throws {
        var savedData: Data?
        let store = AIPersonalProviderStore(load: { nil }, persist: { savedData = $0; return true })
        let settings = customSettings()
        try store.save(settings)
        let restored = AIPersonalProviderStore(load: { savedData }, persist: { _ in false })
        XCTAssertEqual(restored.settings, settings)
        XCTAssertEqual(store.settings, restored.settings)
    }

    @MainActor
    func testFailedSaveKeepsTheActiveConfiguration() {
        let store = AIPersonalProviderStore(load: { nil }, persist: { _ in false })
        XCTAssertThrowsError(try store.save(customSettings()))
        XCTAssertFalse(store.settings.isEnabled)
        XCTAssertEqual(store.settings.apiKey, "")
    }
}
