//import SwiftUI
//import AVFAudio
//
//struct RhombusTrackingView: View {
//    @Environment(\.dismiss) private var dismiss
//    @State private var remainingTime: TimeInterval = 180
//    @State private var currentPoint = 0
//    @State private var dotPosition = CGPoint.zero
//    
//    let synthesizer = AVSpeechSynthesizer()
//    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
//    
//    // Rhombus pattern points (normalized coordinates)
//    let points = [
//        CGPoint(x: 0.5, y: 0),    // Top
//        CGPoint(x: 1, y: 0.5),     // Right
//        CGPoint(x: 0.5, y: 1),     // Bottom
//        CGPoint(x: 0, y: 0.5)      // Left
//    ]
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                Color.white.edgesIgnoringSafeArea(.all)
//                
//                VStack(spacing: 30) {
//                    // Timer View
//                    TimerView(remainingTime: remainingTime, totalTime: 180)
//                        .padding(.top, 40)
//                    
//                    // Tracking Area
//                    ZStack {
//                        // Rhombus outline
//                        Path { path in
//                            path.move(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.2))
//                            path.addLine(to: CGPoint(x: geometry.size.width * 0.8, y: geometry.size.height * 0.4))
//                            path.addLine(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.6))
//                            path.addLine(to: CGPoint(x: geometry.size.width * 0.2, y: geometry.size.height * 0.4))
//                            path.closeSubpath()
//                        }
//                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
//                        
//                        // Moving dot
//                        Circle()
//                            .fill(Color.blue)
//                            .frame(width: 20, height: 20)
//                            .position(x: dotPosition.x * geometry.size.width,
//                                    y: dotPosition.y * geometry.size.height)
//                    }
//                    .frame(height: 300)
//                    .background(Color.blue.opacity(0.1))
//                    .cornerRadius(20)
//                    .padding(.horizontal)
//                    
//                    Text("Follow the blue dot with your eyes only")
//                        .font(.title3)
//                        .bold()
//                        .foregroundColor(.blue)
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal)
//                    
//                    Spacer()
//                    
//                    // Stop Button
//                    Button(action: { stopExercise() }) {
//                        Label("End Exercise", systemImage: "xmark.circle.fill")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 16)
//                            .background(Color.red)
//                            .cornerRadius(15)
//                    }
//                    .padding(.horizontal)
//                    .padding(.bottom, 30)
//                }
//            }
//        }
//        .onAppear {
//            startExercise()
//        }
//        .onReceive(timer) { _ in
//            updateExercise()
//        }
//        .navigationTitle("Rhombus Tracking")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//    
//    private func startExercise() {
//        dotPosition = points[0]
//        let utterance = AVSpeechUtterance(string: "Rhombus tracking exercise. Follow the blue dot with your eyes only.")
//        utterance.rate = 0.5
//        utterance.volume = 0.8
//        synthesizer.speak(utterance)
//    }
//    
//    private func updateExercise() {
//        if remainingTime > 0 {
//            remainingTime -= 1
//            
//            // Move dot every 3 seconds
//            if remainingTime.truncatingRemainder(dividingBy: 3) == 0 {
//                withAnimation(.easeInOut(duration: 1.0)) {
//                    currentPoint = (currentPoint + 1) % points.count
//                    dotPosition = points[currentPoint]
//                }
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
