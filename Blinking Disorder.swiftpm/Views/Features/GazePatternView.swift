//import SwiftUI
//import AVFAudio
//
//struct GazePatternView: View {
//    @Environment(\.dismiss) private var dismiss
//    @State private var remainingTime: TimeInterval = 180
//    @State private var currentPattern = 0
//    @State private var dotPosition = CGPoint.zero
//    @State private var isShowingGuide = true
//    
//    let synthesizer = AVSpeechSynthesizer()
//    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
//    
//    let patterns = [
//        GazePattern(
//            name: "Clockwise Circle",
//            systemImage: "circle",
//            color: .blue,
//            points: [(1, 0), (0.7, -0.7), (0, -1), (-0.7, -0.7), (-1, 0), (-0.7, 0.7), (0, 1), (0.7, 0.7)]
//        ),
//        GazePattern(
//            name: "Figure Eight",
//            systemImage: "infinity",
//            color: .purple,
//            points: [(1, 0), (0.5, 0.5), (0, 0), (-0.5, -0.5), (-1, 0), (-0.5, 0.5), (0, 0), (0.5, -0.5)]
//        ),
//        GazePattern(
//            name: "Square",
//            systemImage: "square",
//            color: .green,
//            points: [(1, 1), (1, -1), (-1, -1), (-1, 1)]
//        )
//    ]
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // Background gradient
//                LinearGradient(colors: [.white, Color(.systemGray6)],
//                             startPoint: .top,
//                             endPoint: .bottom)
//                    .ignoresSafeArea()
//                
//                VStack(spacing: 24) {
//                    // Timer and Pattern Info
//                    VStack(spacing: 16) {
//                        TimerView(remainingTime: remainingTime, totalTime: 180)
//                        
//                        // Current Pattern Card
//                        CurrentPatternCard(pattern: patterns[currentPattern % patterns.count])
//                    }
//                    .padding(.top)
//                    
//                    // Exercise Area
//                    ZStack {
//                        // Pattern Guide
//                        if isShowingGuide {
//                            PatternGuideView(points: patterns[currentPattern % patterns.count].points)
//                                .stroke(patterns[currentPattern % patterns.count].color.opacity(0.2), lineWidth: 2)
//                                .frame(width: min(geometry.size.width - 80, 300),
//                                       height: min(geometry.size.width - 80, 300))
//                        }
//                        
//                        // Animated Dot
//                        MovingDotView(position: dotPosition,
//                                    color: patterns[currentPattern % patterns.count].color)
//                            .frame(width: 20, height: 20)
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.5)
//                    .background(
//                        RoundedRectangle(cornerRadius: 24)
//                            .fill(Color.white)
//                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
//                    )
//                    .padding(.horizontal)
//                    
//                    // Controls
//                    VStack(spacing: 16) {
//                        // Pattern Guide Toggle
//                        Toggle("Show Pattern Guide", isOn: $isShowingGuide)
//                            .padding(.horizontal)
//                        
//                        // Stop Button
//                        Button(action: { stopExercise() }) {
//                            Label("End Exercise", systemImage: "xmark.circle.fill")
//                                .font(.headline)
//                                .foregroundColor(.white)
//                                .frame(maxWidth: .infinity)
//                                .padding(.vertical, 16)
//                                .background(Color.red)
//                                .clipShape(RoundedRectangle(cornerRadius: 16))
//                        }
//                        .padding(.horizontal)
//                    }
//                    
//                    Spacer()
//                }
//            }
//        }
//        .onAppear {
//            startExercise()
//        }
//        .onReceive(timer) { _ in
//            updateExercise()
//        }
//        .navigationTitle("Gaze Pattern")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//    
//    private func startExercise() {
//        let utterance = AVSpeechUtterance(string: "Follow the blue dot with your eyes only. Keep your head still.")
//        utterance.rate = 0.5
//        utterance.volume = 0.8
//        synthesizer.speak(utterance)
//    }
//    
//    private func updateExercise() {
//        if remainingTime > 0 {
//            remainingTime -= 1
//            
//            // Update dot position every 2 seconds
//            if Int(remainingTime) % 2 == 0 {
//                let patternPoints = patterns[currentPattern % patterns.count].points
//                let pointIndex = (Int((180 - remainingTime) / 2) % patternPoints.count)
//                dotPosition = CGPoint(x: patternPoints[pointIndex].0, y: patternPoints[pointIndex].1)
//            }
//            
//            // Change pattern every 30 seconds
//            if Int(remainingTime) % 30 == 0 {
//                currentPattern += 1
//                let utterance = AVSpeechUtterance(string: "Changing to \(patterns[currentPattern % patterns.count].name)")
//                utterance.rate = 0.5
//                utterance.volume = 0.8
//                synthesizer.speak(utterance)
//            }
//        } else {
//            stopExercise()
//        }
//    }
//    
//    private func stopExercise() {
//        synthesizer.stopSpeaking(at: .immediate)
//        dismiss()
//    }
//}
//
//// Supporting Views
//struct GazePattern {
//    let name: String
//    let systemImage: String
//    let color: Color
//    let points: [(Double, Double)]
//}
//
//struct CurrentPatternCard: View {
//    let pattern: GazePattern
//    
//    var body: some View {
//        HStack(spacing: 16) {
//            Image(systemName: pattern.systemImage)
//                .font(.title)
//                .foregroundColor(pattern.color)
//                .frame(width: 44, height: 44)
//                .background(pattern.color.opacity(0.1))
//                .clipShape(Circle())
//            
//            VStack(alignment: .leading, spacing: 4) {
//                Text("Current Pattern")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//                Text(pattern.name)
//                    .font(.title3.bold())
//            }
//            
//            Spacer()
//        }
//        .padding()
//        .background(Color.white)
//        .clipShape(RoundedRectangle(cornerRadius: 16))
//        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
//        .padding(.horizontal)
//    }
//}
//
//struct MovingDotView: View {
//    let position: CGPoint
//    let color: Color
//    
//    var body: some View {
//        ZStack {
//            // Outer glow
//            ForEach(0..<3) { i in
//                Circle()
//                    .fill(color.opacity(0.3 - Double(i) * 0.1))
//                    .frame(width: 20 + CGFloat(i * 10),
//                           height: 20 + CGFloat(i * 10))
//                    .blur(radius: CGFloat(i * 2))
//            }
//            
//            // Core dot
//            Circle()
//                .fill(color.gradient)
//                .frame(width: 20, height: 20)
//                .shadow(color: color.opacity(0.5), radius: 5)
//        }
//        .position(x: position.x, y: position.y)
//        .animation(.easeInOut(duration: 1), value: position)
//    }
//}
//
//struct PatternGuideView: Shape {
//    let points: [(Double, Double)]
//    
//    func path(in rect: CGRect) -> Path {
//        var path = Path()
//        let center = CGPoint(x: rect.midX, y: rect.midY)
//        let scale = min(rect.width, rect.height) / 2
//        
//        guard let firstPoint = points.first else { return path }
//        
//        let startPoint = CGPoint(
//            x: center.x + CGFloat(firstPoint.0) * scale,
//            y: center.y + CGFloat(firstPoint.1) * scale
//        )
//        path.move(to: startPoint)
//        
//        for point in points.dropFirst() {
//            let scaledPoint = CGPoint(
//                x: center.x + CGFloat(point.0) * scale,
//                y: center.y + CGFloat(point.1) * scale
//            )
//            path.addLine(to: scaledPoint)
//        }
//        
//        path.closeSubpath()
//        return path
//    }
//}
//
//// Add TimerView component for reuse across exercise views
//struct TimerView: View {
//    let remainingTime: TimeInterval
//    let totalTime: TimeInterval
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            Text(timeString(from: remainingTime))
//                .font(.system(size: 44, weight: .bold, design: .rounded))
//                .monospacedDigit()
//            
//            Text("Remaining Time")
//                .font(.title3)
//                .foregroundStyle(.secondary)
//        }
//    }
//    
//    private func timeString(from timeInterval: TimeInterval) -> String {
//        let minutes = Int(timeInterval) / 60
//        let seconds = Int(timeInterval) % 60
//        return String(format: "%02d:%02d", minutes, seconds)
//    }
//}
//
