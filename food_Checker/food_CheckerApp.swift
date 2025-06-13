//
//  food_CheckerApp.swift
//  food_Checker
//
//  Created by Jonas Kilian on 07.05.25.
//

import SwiftUI
import AVKit
import AVFoundation


@main
struct food_CheckerApp: App {
    var body: some Scene {
        WindowGroup {
            VideoSlideshowView()
        }
    }
}

struct VideoSlideshowView: View {
    let videoNames = ["video1", "video2", "video3"]
    @State private var currentIndex = 0
    @State private var nextIndex = 1
    @State private var player = AVPlayer()
    @State private var playerItems: [AVPlayerItem] = []
    @State private var isAnimating = false
    @State private var showCurrent = true
    @State private var dragOffset: CGFloat = 0
    @State private var navigateToDetail = false
    @State private var selectedIndexForNavigation: Int? = nil
    @State private var screenWidth = UIScreen.main.bounds.width

    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

      var body: some View {
          NavigationStack {
              ZStack {
                  FullscreenAVPlayerView(player: player)
                      .offset(x: dragOffset)
                      .gesture(
                          DragGesture()
                              .onChanged { value in
                                  dragOffset = value.translation.width
                              }
                              .onEnded { value in
                                  let threshold: CGFloat = 100
                                  if value.translation.width < -threshold {
                                      swipeToNext()
                                  } else if value.translation.width > threshold {
                                      swipeToPrevious()
                                  }
                                  dragOffset = 0
                              }
                      )
                      .animation(.easeInOut, value: dragOffset)
                      .ignoresSafeArea()

                  VStack {
                      HStack {
                          Menu {
                              NavigationLink("Food Checker", destination: FirstView())
                              NavigationLink("Bewerten", destination: SecondView())
                              NavigationLink("Einkaufsliste", destination: ThirdView())
                              NavigationLink("Work in Progress", destination: DetailView4())
                          } label: {
                              Image(systemName: "line.3.horizontal")
                                  .font(.title2)
                                  .padding(10)
                                  .background(Color.black.opacity(0.6))
                                  .foregroundColor(.white)
                                  .clipShape(Circle())
                          }
                          .padding(.top, 50)
                          .padding(.leading, 20)
                          Spacer()
                      }
                      Spacer()
                  }

                  VStack {
                                     Spacer()
                                     Button(action: {
                                         selectedIndexForNavigation = currentIndex
                                         navigateToDetail = true
                                     }) {
                                         Text(textForIndex(currentIndex))
                                             .font(.subheadline)
                                             .foregroundColor(.white)
                                             .frame(maxWidth: .infinity, minHeight: 30)
                                             .multilineTextAlignment(.center)
                                             .background(colorForIndex(currentIndex))
                                     }
                                 }
                             }

                             .navigationDestination(isPresented: $navigateToDetail) {
                                 detailViewForIndex(selectedIndexForNavigation ?? 0)
                             }
                             .onAppear {
                                 preloadVideos()
                                 if !playerItems.isEmpty {
                                     player.replaceCurrentItem(with: playerItems[currentIndex])
                                     player.play()
                                 }
                             }
                             .onReceive(timer) { _ in
                                 swipeToNext()
                             }
                         }
                     }

      // MARK: - Swipe-Funktionen

      private func swipeToNext() {
          let next = (currentIndex + 1) % videoNames.count
          switchToVideo(at: next)
      }

      private func swipeToPrevious() {
          let prev = (currentIndex - 1 + videoNames.count) % videoNames.count
          switchToVideo(at: prev)
      }

      private func switchToVideo(at index: Int) {
          guard index < playerItems.count else { return }
          currentIndex = index
          player.replaceCurrentItem(with: playerItems[index])
          player.seek(to: .zero)
          player.play()
      }

      private func preloadVideos() {
          playerItems = videoNames.compactMap { name in
              guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else {
                  print("❌ Video \(name) nicht gefunden.")
                  return nil
              }
              let asset = AVURLAsset(url: url)
              return AVPlayerItem(asset: asset)
          }
      }

      private func textForIndex(_ index: Int) -> String {
          switch index {
          case 0: return "Food-Checker"
          case 1: return "Dein Ranking"
          case 2: return "Einkaufsliste"
          default: return "Unbekanntes Video"
          }
      }

      private func colorForIndex(_ index: Int) -> Color {
          switch index {
          case 0: return .blue
          case 1: return .green
          case 2: return .orange
          default: return .gray
          }
      }

      @ViewBuilder
      private func detailViewForIndex(_ index: Int) -> some View {
          switch index {
          case 0: FirstView()
          case 1: SecondView()
          case 2: ThirdView()
          case 3: DetailView4()
          default: Text("Keine Detailansicht verfügbar")
          }
      }
  }

struct FullscreenAVPlayerView: UIViewRepresentable {
    let player: AVPlayer

    class PlayerView: UIView {
        private var playerLayer: AVPlayerLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }

        func setPlayer(_ player: AVPlayer) {
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            layer.frame = bounds
            self.layer.sublayers?.removeAll()
            self.layer.addSublayer(layer)
            self.playerLayer = layer
        }
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.setPlayer(player)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.setPlayer(player)
    }
}


struct DetailView4: View {
    var body: some View {
        Text("Details zu Video 4").font(.largeTitle).navigationTitle("Video 4")
    }
}

struct AndereView: View {
    let name: String
    
    var body: some View {
        VStack {
            Text("Du bist auf der \(name)-Seite")
                .font(.title)
                .padding()
            Spacer()
        }
        .navigationTitle(name)
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage? {
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if aspectRatio > 1 {
            // Querformat: Breite = maxDimension
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Hochformat oder quadratisch: Höhe = maxDimension
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

struct VideoSlideshowView_Previews: PreviewProvider {
    static var previews: some View {
        VideoSlideshowView()
    }
}
