import SwiftUI
@preconcurrency import ARKit
@preconcurrency import AVFoundation

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = EyeTrackingViewModel()
    @State private var selectedDuration: TimeInterval = 30
    
    var body: some View {
        ZStack {
            if viewModel.isExerciseActive {
                ExerciseView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
            
            TabView {
                TrackingView(selectedDuration: $selectedDuration, viewModel: viewModel)
                    .tabItem {
                        Label("Track", systemImage: "eye")
                    }
                    .opacity(viewModel.isExerciseActive ? 0 : 1)
                
                RelaxationView()
                    .tabItem {
                        Label("Relax", systemImage: "heart")
                    }
                    .opacity(viewModel.isExerciseActive ? 0 : 1)
                
                EducationView()
                    .tabItem {
                        Label("Learn", systemImage: "book")
                    }
                    .opacity(viewModel.isExerciseActive ? 0 : 1)
            }
            .tint(.blue)
        }
    }
}

