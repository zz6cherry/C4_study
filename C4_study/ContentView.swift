import SwiftUI
import MusicKit

struct ContentView: View {
    @State private var artists: [Artist] = []
    @State private var artistWithSongs: [ArtistWithSongs] = []
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
                        let rawArtists = await processOCRText(sampleText)

                        var tempResults: [ArtistWithSongs] = []
                        for artist in rawArtists {
                            let topSongs = await fetchTopSongs(for: artist)
                            tempResults.append(ArtistWithSongs(artist: artist, songs: topSongs))
                        }

                        self.artists = rawArtists
                        self.artistWithSongs = tempResults
                        loading = false
                    }
                }

                if loading {
                    ProgressView("검색 중...")
                        .padding()
                } else if !artistWithSongs.isEmpty {
                    List(artistWithSongs) { item in
                        Section(header: Text(item.artist.name).font(.headline)) {
                            ForEach(item.songs, id: \.id) { song in
                                Text(song.title)
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

    // ✅ 인기곡 가져오기
//    func fetchTopSongs(for artist: Artist) async -> [Song] {
//        // 1. 아티스트 ID 기반 상세 요청
//        var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: artist.id)
//        do {
//            let response = try await request.response()
//            guard let fullArtist = response.items.first else {
//                print("❌ 아티스트 정보 없음: \(artist.name)")
//                return []
//            }
//
//            // 2. topSongs가 있다면 사용
//            if let top = fullArtist.topSongs, !top.isEmpty {
//                return Array(top.prefix(3))
//            }
//
//            // 3. 없으면 대체로 artist 이름으로 song 검색
//            print("⚠️ fallback: \(artist.name)의 곡 직접 검색 중…")
//            var songRequest = MusicCatalogSearchRequest(term: artist.name, types: [Song.self])
//            songRequest.limit = 10
//            let songResponse = try await songRequest.response()
//            let songs = songResponse.songs
//
//            // 4. 아티스트 ID 기준 필터링
//            let filtered = songs.filter { $0.artistName.lowercased().contains(artist.name.lowercased()) }
//            return Array(filtered.prefix(3))
//        } catch {
//            print("❌ 인기곡 가져오기 실패: \(artist.name) - \(error.localizedDescription)")
//            return []
//        }
//    }

    func fetchTopSongs(for artist: Artist) async -> [Song] {
        do {
            // ✅ 1. 아티스트 상세 정보 요청 시 topSongs 속성 포함
            var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: artist.id)
            request.properties = [.topSongs]  // 이놈이진짜 중요한 거임 꼭 필요함
            let response = try await request.response()

            guard let fullArtist = response.items.first else {
                print("❌ 아티스트 정보 없음: \(artist.name)")
                return []
            }

            // ✅ 2. topSongs 있으면 사용
            if let top = fullArtist.topSongs, !top.isEmpty {
                print("🎶 \(artist.name)의 인기곡: \(top.map { $0.title })")
                return Array(top.prefix(3))
            }

            // ⚠️ 3. topSongs 없으면 fallback 검색
            print("⚠️ fallback: \(artist.name)의 곡 직접 검색 중…")
            var songRequest = MusicCatalogSearchRequest(term: artist.name, types: [Song.self])
            songRequest.limit = 10
            let songResponse = try await songRequest.response()
            let songs = songResponse.songs

            // 아티스트 이름 포함하는 곡만 필터링
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

// ✅ 새로운 데이터 구조
struct ArtistWithSongs: Identifiable {
    let id = UUID()
    let artist: Artist
    let songs: [Song]
}

#Preview {
    ContentView()
}
