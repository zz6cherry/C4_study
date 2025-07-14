//
//  ArtistWithSongs.swift
//  C4_study
//
//  Created by 서연 on 7/15/25.
//

import Foundation
import MusicKit

struct ArtistWithSongs: Identifiable {
    var id: MusicItemID { artist.id }  // Apple Music의 ID를 고유 ID로 사용
    let artist: Artist
    let songs: [Song]
}
