//
//  File.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import Foundation
import UIKit
import SwiftUI
@preconcurrency import ARKit
@preconcurrency import AVFoundation

class EyeTrackingViewModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var exerciseSessions: [ExerciseSession] = []
    @Published var blinkCount = 0
    @Published var eyebrowTwitchCount = 0
    @Published var eyeStrainDetected = false
    @Published var isTracking = false
    @Published var exerciseDuration: TimeInterval = 30
    @Published var remainingTime: TimeInterval = 0
    @Published var isExerciseActive = false
    @Published var stressLevel: Int = 0
    @Published var screenTime: TimeInterval = 0
    
    // New logs properties
    @Published var blinkLogs: [SymptomLog] = []
    @Published var twitchLogs: [SymptomLog] = []
    
    private var arSession: ARSession?
    private var timer: Timer?
    
    override init() {
        super.init()
        setupARSession()
    }
    
    private func setupARSession() {
        arSession = ARSession()
        arSession?.delegate = self
    }
    
    func startExercise() {
        
        blinkCount = 0
        eyebrowTwitchCount = 0
        eyeStrainDetected = false
        
        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking is not supported on this device.")
            return
        }
        
        print("Starting Exercise - Before Configuration")
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        print("Starting Exercise - Session Running")
        
        isTracking = true
        isExerciseActive = true
        remainingTime = exerciseDuration
        
        print("Starting Exercise - State: isExerciseActive = \(isExerciseActive)")
        
        // Start the timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                self.stopExercise()
            }
        }
    }
    
    func stopExercise() {
        timer?.invalidate()
        timer = nil
        arSession?.pause()
        isTracking = false
        isExerciseActive = false
        
        // Save the session
        let newSession = ExerciseSession(
            timestamp: Date(),
            duration: exerciseDuration,
            blinkCount: blinkCount,
            twitchCount: eyebrowTwitchCount
        )
        exerciseSessions.insert(newSession, at: 0) // Add new session at the beginning
        
        // Analyze results
        analyzeResults()
    }
    
    private func analyzeResults() {
        if blinkCount > 10 {
            print("Excessive Blinking Detected")
        }
        if eyebrowTwitchCount > 5 {
            print("Eyebrow Twitching Detected")
        }
        if eyeStrainDetected {
            print("Eye Strain Detected")
        }
    }
    
    // Symptom Logging Method
    func logSymptom(type: String, intensity: Int, trigger: String? = nil) {
        let log = SymptomLog(
            date: Date(),
            symptomType: type,
            intensity: intensity,
            notes: "",
            trigger: trigger
        )
        
        if type == "Blink" {
            blinkLogs.insert(log, at: 0)
        } else if type == "Twitch" {
            twitchLogs.insert(log, at: 0)
        }
        
        // Limit logs to last 10 entries
        blinkLogs = Array(blinkLogs.prefix(10))
        twitchLogs = Array(twitchLogs.prefix(10))
    }
    
    // ARSessionDelegate Methods
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let faceAnchor = anchor as? ARFaceAnchor {
                processFaceAnchor(faceAnchor)
            }
        }
    }
    
    private func processFaceAnchor(_ faceAnchor: ARFaceAnchor) {
        let blendShapes = faceAnchor.blendShapes
        
        // Improved blink detection
        if let leftEyeBlink = blendShapes[.eyeBlinkLeft]?.floatValue,
           let rightEyeBlink = blendShapes[.eyeBlinkRight]?.floatValue {
            let blinkThreshold: Float = 0.4  // Lowered threshold for better sensitivity
            
            // Check if both eyes are blinking together
            if leftEyeBlink > blinkThreshold && rightEyeBlink > blinkThreshold {
                // Only count as a blink if we haven't logged one very recently
                if let lastBlink = blinkLogs.first {
                    let timeSinceLastBlink = Date().timeIntervalSince(lastBlink.date)
                    if timeSinceLastBlink > 0.3 { // Minimum time between blinks (300ms)
                        blinkCount += 1
                        logSymptom(type: "Blink", intensity: Int((leftEyeBlink + rightEyeBlink) * 50))
                    }
                } else {
                    blinkCount += 1
                    logSymptom(type: "Blink", intensity: Int((leftEyeBlink + rightEyeBlink) * 50))
                }
            }
        }
        
        // Improved twitch detection
        if let browInnerUp = blendShapes[.browInnerUp]?.floatValue,
           let browOuterUpLeft = blendShapes[.browOuterUpLeft]?.floatValue,
           let browOuterUpRight = blendShapes[.browOuterUpRight]?.floatValue {
            
            let twitchThreshold: Float = 0.3  // Lowered threshold for better sensitivity
            let combinedBrowMovement = (browInnerUp + browOuterUpLeft + browOuterUpRight) / 3.0
            
            if combinedBrowMovement > twitchThreshold {
                // Only count as a twitch if we haven't logged one very recently
                if let lastTwitch = twitchLogs.first {
                    let timeSinceLastTwitch = Date().timeIntervalSince(lastTwitch.date)
                    if timeSinceLastTwitch > 0.5 { // Minimum time between twitches (500ms)
                        eyebrowTwitchCount += 1
                        logSymptom(type: "Twitch", intensity: Int(combinedBrowMovement * 100))
                    }
                } else {
                    eyebrowTwitchCount += 1
                    logSymptom(type: "Twitch", intensity: Int(combinedBrowMovement * 100))
                }
            }
        }
        
        // Improved eye strain detection
        if let eyeBlinkLeft = blendShapes[.eyeBlinkLeft]?.floatValue,
           let eyeBlinkRight = blendShapes[.eyeBlinkRight]?.floatValue,
           let eyeSqueezeLeft = blendShapes[.eyeSquintLeft]?.floatValue,
           let eyeSqueezeRight = blendShapes[.eyeSquintRight]?.floatValue {
            
            let combinedEyeStrain = (eyeBlinkLeft + eyeBlinkRight + eyeSqueezeLeft + eyeSqueezeRight) / 4.0
            
            if combinedEyeStrain > 0.6 { // Adjusted threshold for eye strain
                eyeStrainDetected = true
            }
        }
    }
    
}

enum GazePattern {
    case horizontal
    case vertical
    case diagonal
    case circular
    case infinity
    
    var points: [CGPoint] {
        switch self {
        case .horizontal:
            return [
                CGPoint(x: -0.8, y: 0),
                CGPoint(x: 0.8, y: 0),
                CGPoint(x: -0.8, y: 0)
            ]
        case .vertical:
            return [
                CGPoint(x: 0, y: -0.8),
                CGPoint(x: 0, y: 0.8),
                CGPoint(x: 0, y: -0.8)
            ]
        case .diagonal:
            return [
                CGPoint(x: -0.8, y: -0.8),
                CGPoint(x: 0.8, y: 0.8),
                CGPoint(x: -0.8, y: 0.8),
                CGPoint(x: 0.8, y: -0.8),
                CGPoint(x: -0.8, y: -0.8)
            ]
        case .circular:
            var points: [CGPoint] = []
            let radius: CGFloat = 0.8
            for i in 0...360 {
                let angle = Double(i) * .pi / 180
                let x = radius * cos(angle)
                let y = radius * sin(angle)
                points.append(CGPoint(x: x, y: y))
            }
            return points
        case .infinity:
            var points: [CGPoint] = []
            for i in 0...360 {
                let angle = Double(i) * .pi / 180
                let x = 0.8 * cos(angle)
                let y = 0.8 * sin(2 * angle) / 2
                points.append(CGPoint(x: x, y: y))
            }
            return points
        }
    }
    
    var name: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .diagonal: return "Diagonal"
        case .circular: return "Circular"
        case .infinity: return "Figure 8"
        }
    }
    
    var systemImage: String {
        switch self {
        case .horizontal: return "arrow.left.and.right"
        case .vertical: return "arrow.up.and.down"
        case .diagonal: return "arrow.up.right.and.arrow.down.left"
        case .circular: return "circle"
        case .infinity: return "infinity"
        }
    }
}

struct OrbView: View {
    let targetPosition: CGPoint
    let pattern: GazePattern
    @State private var currentPatternIndex: Int = 0
    @State private var isAnimating: Bool = false
    
    var body: some View {
        ZStack {
            // Pattern Guide
            PatternGuideView(pattern: pattern)
                .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                .frame(width: 200, height: 200)
            
            // Animated Orb
            ZStack {
                // Outer glow
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.blue.opacity(0.2 - Double(i) * 0.05))
                        .frame(width: 60 + CGFloat(i * 15),
                               height: 60 + CGFloat(i * 15))
                        .blur(radius: CGFloat(i * 3))
                }
                
                // Core orb
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: .blue.opacity(0.5), radius: 10)
            }
            .offset(x: targetPosition.x * 100, y: targetPosition.y * 100)
        }
    }
}

struct PatternGuideView: Shape {
    let pattern: GazePattern
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = pattern.points
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let scale = min(rect.width, rect.height) / 2
        
        guard !points.isEmpty else { return path }
        
        let startPoint = CGPoint(
            x: center.x + points[0].x * scale,
            y: center.y + points[0].y * scale
        )
        path.move(to: startPoint)
        
        for point in points.dropFirst() {
            let scaledPoint = CGPoint(
                x: center.x + point.x * scale,
                y: center.y + point.y * scale
            )
            path.addLine(to: scaledPoint)
        }
        
        return path
    }
}

// Add this new view to handle the exercise content
struct ExerciseContentView: View {
    @ObservedObject var viewModel: EyeTrackingViewModel
    @Binding var targetPosition: CGPoint
    @Binding var isAnimating: Bool
    let synthesizer: AVSpeechSynthesizer
    @Environment(\.dismiss) private var dismiss
    @State private var currentPattern: GazePattern = .horizontal
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack {
                    // Background gradient
                    LinearGradient(colors: [.blue.opacity(0.1), .blue.opacity(0.2)],
                                 startPoint: .top,
                                 endPoint: .bottom)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        // Timer and Stats Section
                        VStack(spacing: 20) {
                            // Timer View
                            HStack {
                                Label("\(Int(viewModel.remainingTime))s", systemImage: "timer")
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                            
                            // Stats Cards
                            HStack(spacing: 16) {
                                StatisticCard(
                                    title: "Blinks",
                                    value: viewModel.blinkCount,
                                    icon: "eye.fill",
                                    color: .blue
                                )
                                
                                StatisticCard(
                                    title: "Twitches",
                                    value: viewModel.eyebrowTwitchCount,
                                    icon: "eye.trianglebadge.exclamationmark.fill",
                                    color: .orange
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Exercise Area with Stop Button
                        VStack(spacing: 16) {
                            // Pattern Selection
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach([GazePattern.horizontal, .vertical, .diagonal, .circular, .infinity], id: \.name) { pattern in
                                        Button(action: { currentPattern = pattern }) {
                                            VStack {
                                                Image(systemName: pattern.systemImage)
                                                    .font(.title2)
                                                Text(pattern.name)
                                                    .font(.caption)
                                            }
                                            .padding()
                                            .background(currentPattern == pattern ? Color.blue.opacity(0.2) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .foregroundColor(.primary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Exercise Area
                            ZStack {
                                // Exercise boundary indicator
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                
                                VStack {
                                    Text("Follow the orb pattern")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .padding(.top)
                                    
                                    Spacer()
                                    
                                    ZStack {
                                        OrbView(targetPosition: targetPosition, pattern: currentPattern)
                                            .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.4)
                                        
                                        // Eye Strain Warning Overlay
                                        if viewModel.eyeStrainDetected {
                                            EyeStrainWarningOverlay()
                                                .transition(.opacity)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: min(geometry.size.height * 0.5, 400))
                            
                            // Stop Exercise Button
                            Button(action: { viewModel.stopExercise() }) {
                                Label("Stop Exercise", systemImage: "xmark.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .scrollDisabled(true)
            .onAppear {
                startOrbMovement(in: geometry)
                provideInitialGuidance()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Eye Exercise")
                    .font(.headline)
            }
        }
        .onChange(of: viewModel.remainingTime) { newValue in
            handleTimeChange(newValue)
        }
        .ignoresSafeArea(.keyboard)
    }
    
    private func startOrbMovement(in geometry: GeometryProxy) {
        let points = currentPattern.points
        var currentIndex = 0
        
        Task { @MainActor in
            while true {
                guard viewModel.isExerciseActive else { break }
                
                let point = points[currentIndex]
                withAnimation(.easeInOut(duration: 2)) {
                    targetPosition = point
                }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                currentIndex = (currentIndex + 1) % points.count
            }
        }
    }
    
    private func provideInitialGuidance() {
        let utterance = AVSpeechUtterance(string: "Eye tracking exercise. Follow the glowing orb with your eyes only.")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
    
    private func handleTimeChange(_ newValue: TimeInterval) {
        if newValue.truncatingRemainder(dividingBy: 10) == 0 && newValue > 0 {
            let utterance = AVSpeechUtterance(string: "\(Int(newValue)) seconds remaining")
            utterance.rate = 0.5
            utterance.volume = 0.8
            synthesizer.speak(utterance)
        } else if newValue == 0 {
            let utterance = AVSpeechUtterance(string: "Exercise complete. Great job!")
            utterance.rate = 0.5
            utterance.volume = 0.8
            synthesizer.speak(utterance)
        }
    }
}

struct StatisticCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .foregroundStyle(color)
            
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct EyeStrainWarningOverlay: View {
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                
                Text("Eye Strain Detected")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("Take a short break and blink naturally")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
            )
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .animation(.easeInOut, value: true)
    }
}

