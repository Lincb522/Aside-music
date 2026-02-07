import Foundation
import Combine

extension APIService {
    func searchSongs(keyword: String, offset: Int = 0) -> AnyPublisher<[Song], Error> {
        guard let encodedQuery = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return fetch("/cloudsearch?keywords=\(encodedQuery)&type=1&limit=30&offset=\(offset)")
            .flatMap { (response: SearchResponse) -> AnyPublisher<[Song], Error> in
                guard let songs = response.result?.songs, !songs.isEmpty else {
                    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                let ids = songs.map { $0.id }
                return self.fetchSongDetails(ids: ids)
            }
            .eraseToAnyPublisher()
    }
    
    func fetchSearchSuggestions(keyword: String) -> AnyPublisher<[String], Error> {
        guard let encodedQuery = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return fetch("/search/suggest?keywords=\(encodedQuery)&type=mobile")
            .map { (response: SearchSuggestResponse) -> [String] in
                return response.result?.allMatch?.map { $0.keyword } ?? []
            }
            .eraseToAnyPublisher()
    }
}

struct SearchResponse: Codable {
    let result: SearchResult?
}
struct SearchResult: Codable {
    let songs: [Song]?
    let privileges: [Privilege]?
}

struct SearchSuggestResponse: Codable {
    let result: SearchSuggestResult?
}
struct SearchSuggestResult: Codable {
    let allMatch: [SearchSuggestionItem]?
}
struct SearchSuggestionItem: Codable {
    let keyword: String
}

