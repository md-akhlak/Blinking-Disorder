import SwiftUI
import AVFAudio

struct EyeMassageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remainingTime: TimeInterval = 300
    @State private var currentStep = 0
    @State private var handPosition = CGPoint(x: 0, y: 0)
    @State private var handRotation = 0.0
    @State private var isAnimating = false
    
    let synthesizer = AVSpeechSynthesizer()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let massageSteps = [
        ("Massage temples gently", CGPoint(x: -60, y: 0), 15.0),
        ("Massage above eyebrows", CGPoint(x: 0, y: -20), -15.0),
        ("Massage under eyes", CGPoint(x: 0, y: 20), 15.0),
        ("Massage bridge of nose", CGPoint(x: 0, y: 0), 0.0)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // Timer Display
                    VStack(spacing: 8) {
                        Text(timeString(from: remainingTime))
                            .font(.system(size: 60, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.blue)
                        
                        Text("Remaining Time")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Animation Area
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 300)
                        
                        // Face with Eyes
                        ZStack {
                            // Face outline
                            Circle()
                                .fill(Color.white)
                                .frame(width: 180, height: 180)
                                .shadow(radius: 5)
                            
                            // Eyes
                            HStack(spacing: 40) {
                                // Left Eye
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 2)
                                    
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 20, height: 20)
                                }
                                
                                // Right Eye
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 2)
                                    
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            
                            // Animated Hand
                            Image(systemName: "hand.point.up.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                                .offset(x: handPosition.x, y: handPosition.y)
                                .rotationEffect(.degrees(handRotation))
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                                         value: handPosition)
                        }
                        
                        Text(massageSteps[currentStep].0)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.blue)
                            .padding(.top, 200)
                    }
                    .padding(.horizontal)
                    
                    // Progress indicators
                    HStack(spacing: 8) {
                        ForEach(0..<massageSteps.count) { index in
                            Circle()
                                .fill(currentStep == index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
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
            }
        }
        .onAppear {
            startExercise()
        }
        .onReceive(timer) { _ in
            updateExercise()
        }
        .navigationTitle("Eye Massage")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func startExercise() {
        isAnimating = true
        updateHandPosition()
        
        let utterance = AVSpeechUtterance(string: "Eye massage exercise. Follow the hand movement and apply gentle pressure.")
        utterance.rate = 0.5
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
    
    private func updateExercise() {
        if remainingTime > 0 {
            remainingTime -= 1
            
            // Change massage step every 15 seconds
            if remainingTime.truncatingRemainder(dividingBy: 15) == 0 {
                currentStep = (currentStep + 1) % massageSteps.count
                updateHandPosition()
                
                let utterance = AVSpeechUtterance(string: massageSteps[currentStep].0)
                utterance.rate = 0.5
                utterance.volume = 0.8
                synthesizer.speak(utterance)
            }
        } else {
            stopExercise()
        }
    }
    
    private func updateHandPosition() {
        handPosition = massageSteps[currentStep].1
        handRotation = massageSteps[currentStep].2
    }
    
    private func stopExercise() {
        synthesizer.stopSpeaking(at: .immediate)
        dismiss()
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
