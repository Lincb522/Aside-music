import Combine
import Foundation
import NeteaseCloudMusicAPI

// MARK: - 冥想 / 助眠解压接口

extension APIService {
    func fetchSatiTags() -> AnyPublisher<[SatiTag], Error> {
        ncm.fetch([SatiTag].self, keyPath: "data") { [ncm] in
            try await ncm.satiTagList()
        }
    }

    func fetchSatiResources(tag: String) -> AnyPublisher<[SatiResource], Error> {
        ncm.fetch([SatiResource].self, keyPath: "data") { [ncm] in
            try await ncm.satiResourceList(tag: tag)
        }
    }

    func fetchSatiTimesceneResources() -> AnyPublisher<SatiTimesceneData, Error> {
        ncm.fetch(SatiTimesceneData.self, keyPath: "data") { [ncm] in
            try await ncm.satiTimesceneResourcesGet()
        }
    }
}
