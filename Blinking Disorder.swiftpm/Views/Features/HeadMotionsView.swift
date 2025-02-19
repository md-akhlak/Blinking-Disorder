import SwiftUI
import AVFAudio

struct HeadMotionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remainingTime: TimeInterval = 240
    @State private var currentMotion = 0
    @State private var isAnimating = false
    
    let synthesizer = AVSpeechSynthesizer()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let motions = [
        ("Tilt head left", "arrow.left.circle.fill"),
        ("Tilt head right", "arrow.right.circle.fill"),
        ("Look up", "arrow.up.circle.fill"),
        ("Look down", "arrow.down.circle.fill"),
        ("Rotate left", "arrow.counterclockwise.circle.fill"),
        ("Rotate right", "arrow.clockwise.circle.fill")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // Timer View
                    TimerView(remainingTime: remainingTime, totalTime: 240)
                        .padding(.top, 40)
                    
                    // Motion Instruction Area
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 300)
                        
                        VStack(spacing: 20) {
                            Image(systemName: motions[currentMotion].1)
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                .animation(
                                    .easeInOut(duration: 2)
                                    .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                            
                            Text(motions[currentMotion].0)
                                .font(.title2)
                                .bold()
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Progress indicators
                    HStack(spacing: 8) {
                        ForEach(0..<motions.count) { index in
                            Circle()
                                .fill(currentMotion == index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Spacer()
                    
                    // Stop Button
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
            }
        }
        .onAppear {
            startExercise()
        }
        .onReceive(timer) { _ in
            updateExercise()
        }
        .navigationTitle("Head Motions")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func startExercise() {
        isAnimating = true
        let utterance = AVSpeechUtterance(string: "Head motions exercise. Follow the instructions and move your head gently.")
        utterance.rate = 0.5
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
    
    private func updateExercise() {
        if remainingTime > 0 {
            remainingTime -= 1
            
            // Change motion every 20 seconds
            if remainingTime.truncatingRemainder(dividingBy: 20) == 0 {
                currentMotion = (currentMotion + 1) % motions.count
                
                let utterance = AVSpeechUtterance(string: motions[currentMotion].0)
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

