import SwiftUI
import AVFAudio

struct GazePatternView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remainingTime: TimeInterval = 180
    @State private var currentPattern = 0
    @State private var dotPosition = CGPoint.zero
    
    let synthesizer = AVSpeechSynthesizer()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let patterns = [
        ("Clockwise Circle", [(1, 0), (0.7, -0.7), (0, -1), (-0.7, -0.7), (-1, 0), (-0.7, 0.7), (0, 1), (0.7, 0.7)]),
        ("Figure Eight", [(1, 0), (0.5, 0.5), (0, 0), (-0.5, -0.5), (-1, 0), (-0.5, 0.5), (0, 0), (0.5, -0.5)]),
        ("Square", [(1, 1), (1, -1), (-1, -1), (-1, 1)])
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Timer
                    TimerView(remainingTime: remainingTime, totalTime: 180)
                        .padding(.top, 40)
                    
                    // Pattern Area
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                            .position(x: geometry.size.width / 2 + dotPosition.x * 100,
                                    y: geometry.size.height / 2 + dotPosition.y * 100)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                    
                    Text(patterns[currentPattern % patterns.count].0)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: { stopExercise() }) {
                        Label("End Exercise", systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            startExercise()
        }
        .onReceive(timer) { _ in
            updateExercise()
        }
        .navigationTitle("Gaze Pattern")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func startExercise() {
        let utterance = AVSpeechUtterance(string: "Follow the blue dot with your eyes only. Keep your head still.")
        utterance.rate = 0.5
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
    
    private func updateExercise() {
        if remainingTime > 0 {
            remainingTime -= 1
            
            // Update dot position every 2 seconds
            if Int(remainingTime) % 2 == 0 {
                let patternPoints = patterns[currentPattern % patterns.count].1
                let pointIndex = (Int((180 - remainingTime) / 2) % patternPoints.count)
                dotPosition = CGPoint(x: patternPoints[pointIndex].0, y: patternPoints[pointIndex].1)
            }
            
            // Change pattern every 30 seconds
            if Int(remainingTime) % 30 == 0 {
                currentPattern += 1
                let utterance = AVSpeechUtterance(string: "Changing to \(patterns[currentPattern % patterns.count].0)")
                utterance.rate = 0.5
                utterance.volume = 0.8
                synthesizer.speak(utterance)
            }
        } else {
            stopExercise()
        }
    }
    
    private func stopExercise() {
        synthesizer.stopSpeaking(at: .immediate)
        dismiss()
    }
}

// Add TimerView component for reuse across exercise views
struct TimerView: View {
    let remainingTime: TimeInterval
    let totalTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 8) {
            Text(timeString(from: remainingTime))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
            
            Text("Remaining Time")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

