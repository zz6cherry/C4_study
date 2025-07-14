import SwiftUI
import MusicKit

struct ContentView: View {
    @State private var artists: [Artist] = []
    @State private var loading = false
    @State private var status: MusicAuthorization.Status = .notDetermined

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🎵 Apple Music 아티스트 검색")
                    .font(.title2)
                    .padding(.top)

                Button("🔍 OCR 텍스트 분석 & 검색") {
                    Task {
                        loading = true
                        await requestMusicAccess()
                        artists = await processOCRText(sampleText)
                        loading = false
                    }
                }

                if loading {
                    ProgressView("검색 중...")
                        .padding()
                } else if !artists.isEmpty {
                    List(artists, id: \.id) { artist in
                        VStack(alignment: .leading) {
                            Text(artist.name)
                                .font(.headline)
                            if let url = artist.url {
                                Text(url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } else {
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Festival Prep")
        }
    }

    let sampleText = """
    K-POP DREAM FESTIVAL 2025
    JULY 27-29
    SEOUL OLYMPIC STADIUM

    MAIN STAGE

    BTS
    BLACKPINK

    G-DRAGON      NEWJEANS
    IVE

    EXO    STRAY KIDS
    TWICE

    Line-up Confirmed by Live Nation

    SEVENTEEN
    PARK HYE JIN
    ZICO

    THE BOYZ   Ateez

    DAY6
    STAYC    IU
    TOKYO STATION
    ENHYPEN

    SUNMI
    LE SSERAFIM     TAEYANG 

    MARINE ARENA
    J BALVIN

    LISA     JAY PARK
    YOASOBI
    """

    // MARK: - Apple Music 권한 요청
    func requestMusicAccess() async {
        let current = await MusicAuthorization.currentStatus
        status = current == .authorized ? current : await MusicAuthorization.request()
    }


    // MARK: - 전체 처리 흐름
    func processOCRText(_ text: String) async -> [Artist] {
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

                    if let artist = await searchArtist(name: chunk) {
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


    // MARK: - 줄 전체가 스킵 대상인지
    func shouldSkipLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        let skipPhrases = [
            "tokyo marine stadium", "summer sonic", "main stage",
            "line up", "festival", "live nation", "olympic stadium",
            "tokyo station", "marine arena", "confirmed", "2025", "july", "august", "september"
        ]

        return skipPhrases.contains(where: { lower.contains($0) }) ||
               lower.range(of: #"\d{4}|\d{1,2}[-./ ]\d{1,2}"#, options: .regularExpression) != nil
    }

    // MARK: - 단어 조합 생성 (1~3단어짜리 조합)
    func generateNameCandidates(from line: String) -> [String] {
        let words = line.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var results: Set<String> = []

        for i in 0..<words.count {
            for len in (1...3).reversed() {
                if i + len <= words.count {
                    let phrase = words[i..<i+len].joined(separator: " ")
                    results.insert(phrase)
                }
            }
        }

        return Array(results)
    }

    // MARK: - Apple Music 검색
    func searchArtist(name: String) async -> Artist? {
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
            
            // 정확히 일치하거나 포함되면 인정
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

    // MARK: - 유효한 아티스트 필터링 + 중복 제거
    func filterValidArtists(from names: [String]) async -> [Artist] {
        var result: [Artist] = []
        var seen: Set<String> = []

        for name in names {
            let key = name.lowercased().replacingOccurrences(of: " ", with: "")
            if seen.contains(key) { continue }

            if let artist = await searchArtist(name: name) {
                let official = artist.name.lowercased().replacingOccurrences(of: " ", with: "")
                if !seen.contains(official) {
                    result.append(artist)
                    seen.insert(official)
                    print("✅ 찾음: \(artist.name)")
                }
            } else {
                print("❌ 못 찾음: \(name)")
            }
        }

        return result
    }
}

#Preview {
    ContentView()
}

