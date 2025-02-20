import SwiftUI
import AVFAudio

struct HeadMotionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remainingTime: TimeInterval = 240
    @State private var currentMotion = 0
    @State private var isAnimating = false
    @State private var showInstructions = true
    @State private var animationProgress: CGFloat = 0
    
    let synthesizer = AVSpeechSynthesizer()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let motions = [
        HeadMotion(
            name: "Tilt Left",
            systemImage: "arrow.left.circle.fill",
            instruction: "Gently tilt your head to the left",
            animationDegrees: -20,
            color: .blue,
            axis: .roll
        ),
        HeadMotion(
            name: "Tilt Right",
            systemImage: "arrow.right.circle.fill",
            instruction: "Gently tilt your head to the right",
            animationDegrees: 20,
            color: .blue,
            axis: .roll
        ),
        HeadMotion(
            name: "Look Up",
            systemImage: "arrow.up.circle.fill",
            instruction: "Slowly look up",
            animationDegrees: -15,
            color: .green,
            axis: .pitch
        ),
        HeadMotion(
            name: "Look Down",
            systemImage: "arrow.down.circle.fill",
            instruction: "Slowly look down",
            animationDegrees: 15,
            color: .green,
            axis: .pitch
        ),
        HeadMotion(
            name: "Turn Left",
            systemImage: "arrow.counterclockwise.circle.fill",
            instruction: "Gently turn your head left",
            animationDegrees: -30,
            color: .purple,
            axis: .yaw
        ),
        HeadMotion(
            name: "Turn Right",
            systemImage: "arrow.clockwise.circle.fill",
            instruction: "Gently turn your head right",
            animationDegrees: 30,
            color: .purple,
            axis: .yaw
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        motions[currentMotion].color.opacity(0.1),
                        .white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header with Timer
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Head Exercise")
                                .font(.title2.bold())
                            Text("\(Int(remainingTime))s remaining")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        CircularProgressView(
                            progress: remainingTime / 240,
                            color: motions[currentMotion].color
                        )
                        .frame(width: 60, height: 60)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    // Main Exercise Area
                    ZStack {
                        // Background
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 10)
                        
                        VStack(spacing: 20) {
                            // Current Motion Indicator
                            HStack {
                                Image(systemName: motions[currentMotion].systemImage)
                                    .font(.title)
                                    .foregroundStyle(motions[currentMotion].color)
                                Text(motions[currentMotion].name)
                                    .font(.title3.bold())
                            }
                            .padding()
                            .background(motions[currentMotion].color.opacity(0.1))
                            .clipShape(Capsule())
                            
                            // 3D Face Animation
                            AnimatedHeadView(
                                motion: motions[currentMotion],
                                isAnimating: isAnimating,
                                progress: animationProgress
                            )
                            .frame(height: geometry.size.height * 0.4)
                            
                            // Motion Progress
                            MotionProgressView(
                                currentMotion: currentMotion,
                                totalMotions: motions.count,
                                color: motions[currentMotion].color
                            )
                            
                            // Instruction
                            Text(motions[currentMotion].instruction)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Controls
                    VStack(spacing: 16) {
                        Button(action: { stopExercise() }) {
                            Label("End Exercise", systemImage: "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
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
        speakInstruction("Head motions exercise. Follow the animated guide and move your head gently.")
    }
    
    private func updateExercise() {
        if remainingTime > 0 {
            remainingTime -= 1
            
            // Change motion every 20 seconds
            if remainingTime.truncatingRemainder(dividingBy: 20) == 0 {
                withAnimation {
                    currentMotion = (currentMotion + 1) % motions.count
                }
                speakInstruction(motions[currentMotion].instruction)
            }
        } else {
            stopExercise()
        }
    }
    
    private func speakInstruction(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
    
    private func stopExercise() {
        synthesizer.stopSpeaking(at: .immediate)
        dismiss()
    }
}

// Supporting Types and Views
enum MotionAxis {
    case roll, pitch, yaw
}

struct HeadMotion {
    let name: String
    let systemImage: String
    let instruction: String
    let animationDegrees: Double
    let color: Color
    let axis: MotionAxis
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)
        }
    }
}

struct AnimatedHeadView: View {
    let motion: HeadMotion
    let isAnimating: Bool
    let progress: CGFloat
    
    var body: some View {
        Image("head-3d") // You'll need to add this 3D head asset
            .resizable()
            .aspectRatio(contentMode: .fit)
            .rotation3DEffect(
                .degrees(isAnimating ? motion.animationDegrees : 0),
                axis: motion.axis == .roll ? (0, 0, 1) :
                      motion.axis == .pitch ? (1, 0, 0) : (0, 1, 0)
            )
            .animation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
    }
}

struct MotionProgressView: View {
    let currentMotion: Int
    let totalMotions: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalMotions, id: \.self) { index in
                Capsule()
                    .fill(index == currentMotion ? color : Color.gray.opacity(0.3))
                    .frame(width: index == currentMotion ? 20 : 8, height: 8)
                    .animation(.spring, value: currentMotion)
            }
        }
    }
}

