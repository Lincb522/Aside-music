import CarPlay

@MainActor
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    static private(set) var isConnected = false
    
    private var interfaceController: CPInterfaceController?
    private var contentManager: CarPlayContentManager?
    
    // MARK: - Scene Lifecycle
    
    nonisolated func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        Task { @MainActor in
            Self.isConnected = true
            self.interfaceController = interfaceController
            let manager = CarPlayContentManager(interfaceController: interfaceController)
            self.contentManager = manager
            manager.setup()
        }
    }
    
    nonisolated func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        Task { @MainActor in
            Self.isConnected = false
            self.contentManager?.teardown()
            self.contentManager = nil
            self.interfaceController = nil
        }
    }
}
