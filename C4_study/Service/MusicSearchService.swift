//
//  MusicSearchService.swift
//  C4_study
//
//  Created by 서연 on 7/15/25.
//

import Foundation
import MusicKit

struct MusicSearchService {
    
    static func searchArtist(name: String) async -> Artist? {
        let cleaned = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200B}", with: "")
        
        print("📡 Apple Music에 보낸 검색어: '\(cleaned)'")
        
        var request = MusicCatalogSearchRequest(term: cleaned, types: [Artist.self])
        request.limit = 5
        
        do {
            let response = try await request.response()
            let matches = response.artists
            print("📥 Apple Music 검색 결과: \(matches.map { $0.name })")
            
            return matches.first(where: {
                let resultName = $0.name.lowercased().replacingOccurrences(of: " ", with: "")
                let inputName = cleaned.lowercased().replacingOccurrences(of: " ", with: "")
                return resultName == inputName || inputName.contains(resultName) || resultName.contains(inputName)
            })
        } catch {
            print("❌ 검색 실패: '\(cleaned)', 에러: \(error.localizedDescription)")
            return nil
        }
    }
    
    
    static func fetchTopSongs(for artist: Artist) async -> [Song] {
        do {
            var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: artist.id)
            request.properties = [.topSongs]  // 이놈이진짜 중요한 거임 꼭 필요함
            let response = try await request.response()
            
            guard let fullArtist = response.items.first else {
                print("❌ 아티스트 정보 없음: \(artist.name)")
                return []
            }

            if let top = fullArtist.topSongs, !top.isEmpty {
                print("🎶 \(artist.name)의 인기곡: \(top.map { $0.title })")
                return Array(top.prefix(3))
            }

            print("⚠️ fallback: \(artist.name)의 곡 직접 검색 중…")
            var songRequest = MusicCatalogSearchRequest(term: artist.name, types: [Song.self])
            songRequest.limit = 10
            let songResponse = try await songRequest.response()
            let songs = songResponse.songs
            
            let filtered = songs.filter {
                $0.artistName.lowercased().contains(artist.name.lowercased())
            }
            
            print("🔍 \(artist.name) 검색 fallback 결과: \(filtered.map { $0.title })")
            return Array(filtered.prefix(3))
            
        } catch {
            print("❌ 인기곡 가져오기 실패: \(artist.name) - \(error.localizedDescription)")
            return []
        }
    }
}
