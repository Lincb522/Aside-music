import Foundation
import SwiftUI
import Combine

/// QQ音乐双线风控管理器
/// 负责在后台静默检查“自家Token后端”的全局开关以及“企鹅家”针对接口的黑盒可用性
@MainActor
final class RiskControlManager: ObservableObject {
    static let shared = RiskControlManager()
    
    /// 全局的高保真/高级音质封禁锁 (默认锁定, 直到双重校验通过)
    @AppStorage("qqPremiumBlocked") var isPremiumBlocked: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    private var hasCheckedThisSession = false
    
    private init() {}
    
    /// 在 App 各大生命周期或首页执行一次风控检查
    func performRiskCheck() {
        guard !hasCheckedThisSession else { return }
        hasCheckedThisSession = true
        
        Task {
            // 获取服务器下发的风控开关状态
            // 返回 true 说明“防风控探针开启”，需要去探路
            // 返回 false 说明“不需要探针，直接放行”
            let shouldProbe = await checkAdminServerToggle()
            
            if !shouldProbe {
                // 服务端表示没有风控，直接放行所有高保真音质！
                self.isPremiumBlocked = false
                AppLogger.success("[RiskControl] 服务端未开启风控，直接放行高级音质！")
                return
            }
            
            // 服务端要求风控，则开启黑盒探针
            let passedQQProbe = await probeQQMusicBackend()
            if passedQQProbe {
                self.isPremiumBlocked = false
                AppLogger.success("[RiskControl] 企鹅侧探测通过！高级音质已解锁！")
            } else {
                self.isPremiumBlocked = true
                AppLogger.warning("[RiskControl] 企鹅侧探测未通过，强制降级并锁死。")
            }
        }
    }
    
    /// 第一道锁：询问我们的后端是否全局放行
    private func checkAdminServerToggle() async -> Bool {
        guard let baseURL = URL(string: SecureConfig.apiBaseURL) else {
            return false // 解析失败当禁止
        }
        let url = baseURL.appendingPathComponent("/api/public/qq-risk-control")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.httpMethod = "GET"
        
        if let apiToken = SecureConfig.apiToken {
            request.setValue(apiToken, forHTTPHeaderField: "X-API-Token")
            request.setValue(apiToken, forHTTPHeaderField: "x-admin-token") // just in case
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                return true // 网络异常时，安全起见默认走探针
            }
            if httpResp.statusCode != 200 {
                return true // 接口错误时，同样默认走探针进行安全排查
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 取出 qqRiskControlEnabled
                if let isRiskControlEnabled = json["qqRiskControlEnabled"] as? Bool {
                    // 如果为 true 说明开启了风控模式，必须探针。
                    // 如果为 false 说明风控关闭了，可以直接无脑放行。
                    return isRiskControlEnabled
                }
            }
        } catch {
            AppLogger.debug("[RiskControl] 查询自身后端开关流产: \(error.localizedDescription)")
            return true // 断网或解析失败默认走探针
        }
        return true // 默认走探针，最安全
    }
    
    /// 第二道锁：利用企鹅的网络尝试拉取真正的至臻音源链接
    private func probeQQMusicBackend() async -> Bool {
        // 利用通用热歌 (周杰伦 - 七里香 Mid) 尝试抓取 FLAC 无损音源
        // 获取失败即证明当前接口环境正被降级制裁（私服本身自带VIP凭证，不需要检查本地Cookie）
        let testMid = "0039MnYb0qxYhV" 
        
        do {
            // 直接尝试触碰加密最高音质之一，验证通道死活
            let client = APIService.shared.qqClient
            let result = try await client.encryptedSongURL(mid: testMid, fileType: .flac)
            if let url = result?.url, !url.isEmpty {
                return true
            }
        } catch {
            return false
        }
        
        return false
    }
}
