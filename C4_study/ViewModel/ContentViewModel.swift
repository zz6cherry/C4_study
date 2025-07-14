//
//  ContentViewModel.swift
//  C4_study
//
//  Created by 서연 on 7/15/25.
//

import Foundation
import MusicKit

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var artists: [Artist] = []
    @Published var artistWithSongs: [ArtistWithSongs] = []
    @Published var isLoading: Bool = false

    // MARK: - 공개 메서드

    func handleOCRSearch(from text: String) async {
        isLoading = true

        let rawArtists = await OCRProcessingService.processOCRText(text)

        var tempResults: [ArtistWithSongs] = []
        for artist in rawArtists {
            let topSongs = await MusicSearchService.fetchTopSongs(for: artist)
            tempResults.append(ArtistWithSongs(artist: artist, songs: topSongs))
        }

        self.artists = rawArtists
        self.artistWithSongs = tempResults
        isLoading = false
    }

    func requestMusicAccess() async {
        let current = await MusicAuthorization.currentStatus
        _ = current == .authorized ? current : await MusicAuthorization.request()
    }
}
