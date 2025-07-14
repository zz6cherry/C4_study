//
//  ContentView.swift
//  C4_study
//
//  Created by 서연 on 7/15/25.
//

import MusicKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🎵 Apple Music 아티스트 검색")
                    .font(.title2)
                    .padding(.top)

                Button("🔍 OCR 텍스트 분석 & 검색") {
                    Task {
                        await viewModel.requestMusicAccess()
                        await viewModel.handleOCRSearch(from: sampleText2)
                    }
                }

                if viewModel.isLoading {
                    ProgressView("검색 중...")
                        .padding()
                } else if !viewModel.artistWithSongs.isEmpty {
                    List(viewModel.artistWithSongs) { item in
                        Section(header: Text(item.artist.name)) {
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

//    let sampleText = """
//       K-POP DREAM FESTIVAL 2025
//       JULY 27-29
//       SEOUL OLYMPIC STADIUM
//
//       MAIN STAGE
//
//       BTS
//       BLACKPINK
//
//       G-DRAGON      NEWJEANS
//       IVE
//
//       EXO    STRAY KIDS
//       TWICE
//
//       Line-up Confirmed by Live Nation
//
//       SEVENTEEN
//       PARK HYE JIN
//       ZICO
//
//       THE BOYZ   Ateez
//
//       DAY6
//       STAYC    IU
//       TOKYO STATION
//       ENHYPEN
//
//       SUNMI
//       LE SSERAFIM     TAEYANG 
//
//       MARINE ARENA
//       J BALVIN
//
//       LISA     JAY PARK
//       YOASOBI
//       """
    
    let sampleText2 = """
    GLOBAL SOUND WAVE 2025
    AUG 15-17
    INCHEON INTERNATIONAL ARENA

    FRONTLINE STAGE

    Red Velvet
    TXT    aespa
    NCT 127
    HYUNA    Crush

    JESSI
    BIGBANG

    Confirmed Artists by K-Music Alliance

    ZEROBASEONE    ILLIT
    Taemin     Hwa Sa

    SHINee     BIBI
    (G)I-DLE     DPR LIVE

    MAMAMOO
    Zion.T   AKMU

    INTERNATIONAL ZONE
    THE CHAINSMOKERS
    Post Malone

    Dua Lipa     Charlie Puth
    Imagine Dragons

    """

}


#Preview {
    ContentView()
}
