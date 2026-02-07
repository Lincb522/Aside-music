import Foundation

extension Bundle {
    /// 安全获取 AsideMusic 资源 Bundle
    /// SPM 构建时使用 Bundle.module，Xcode 项目构建时使用 Bundle.main
    static var asideResources: Bundle? {
        // 尝试 SPM 的 resource bundle
        let bundleName = "AsideMusic_AsideMusic"
        if let url = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        // 回退到 main bundle
        return Bundle.main
    }
}
