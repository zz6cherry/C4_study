//
//  OCRProcessingService.swift
//  C4_study
//
//  Created by 서연 on 7/15/25.
//

import Foundation
import MusicKit

struct OCRProcessingService {
    
    static func processOCRText(_ text: String) async -> [Artist] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !shouldSkipLine($0) }

        var finalArtists: [Artist] = []
        var seenArtistKeys: Set<String> = []

        for line in lines {
            let words = line.components(separatedBy: .whitespaces)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var usedIndices: Set<Int> = []
            var i = 0

            while i < words.count {
                if usedIndices.contains(i) {
                    i += 1
                    continue
                }

                var matched = false
                for len in (1...min(3, words.count - i)).reversed() {
                    let range = i..<i+len
                    if range.contains(where: { usedIndices.contains($0) }) { continue }

                    let chunk = words[range].joined(separator: " ")
                    print("🔍 검색 시도: \(chunk)")
                    let key = chunk.lowercased().replacingOccurrences(of: " ", with: "")
                    if seenArtistKeys.contains(key) { continue }

                    if let artist = await MusicSearchService.searchArtist(name: chunk) {
                        let canonical = artist.name.lowercased().replacingOccurrences(of: " ", with: "")
                        if !seenArtistKeys.contains(canonical) {
                            seenArtistKeys.insert(canonical)
                            finalArtists.append(artist)
                            usedIndices.formUnion(range)
                            print("✅ 찾음: \(artist.name)")
                            matched = true
                            break
                        }
                    }
                }

                if !matched {
                    i += 1
                }
            }
        }

        return finalArtists
    }

    static func shouldSkipLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        let skipPhrases = [
            "tokyo marine stadium", "summer sonic", "main stage",
            "line up", "festival", "live nation", "olympic stadium",
            "tokyo station", "marine arena", "confirmed", "2025", "july", "august", "september"
        ]

        return skipPhrases.contains(where: { lower.contains($0) }) ||
               lower.range(of: #"\d{4}|\d{1,2}[-./ ]\d{1,2}"#, options: .regularExpression) != nil
    }
}
