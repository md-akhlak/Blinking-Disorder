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



// Add this new view to handle the exercise content
struct ExerciseContentView: View {
    @ObservedObject var viewModel: EyeTrackingViewModel
    @Binding var targetPosition: CGPoint
    @Binding var isAnimating: Bool
    let synthesizer: AVSpeechSynthesizer
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ExerciseTimerView(viewModel: viewModel)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    )
                
                ExerciseControlView(
                    viewModel: viewModel,
                    geometry: geometry,
                    targetPosition: $targetPosition,
                    isAnimating: $isAnimating
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                startOrbMovement(in: geometry)
                
                // Initial voice guidance
                let utterance = AVSpeechUtterance(string: "Eye tracking exercise. Follow the glowing orb with your eyes only.")
                utterance.rate = 0.5
                utterance.pitchMultiplier = 1.0
                utterance.volume = 0.8
                synthesizer.speak(utterance)
            }
            .onChange(of: viewModel.remainingTime) { newValue in
                // Provide periodic voice updates
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
    }
    
    private func startOrbMovement(in geometry: GeometryProxy) {
        let maxX = geometry.size.width * 0.3
        let maxY = geometry.size.height * 0.15
        
        weak var weakViewModel = viewModel
        
        Task { @MainActor in
            while true {
                guard let viewModel = weakViewModel, viewModel.isExerciseActive else {
                    break
                }
                
                let randomX = CGFloat.random(in: -maxX...maxX)
                let randomY = CGFloat.random(in: -maxY...maxY)
                
                withAnimation(.easeInOut(duration: 2)) {
                    targetPosition = CGPoint(x: randomX, y: randomY)
                }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}



// Add these supporting views
struct ExerciseTimerView: View {
    @ObservedObject var viewModel: EyeTrackingViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 15)
                    .frame(width: 150)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.remainingTime / viewModel.exerciseDuration))
                    .stroke(
                        LinearGradient(colors: [.blue, .blue.opacity(0.7)],
                                     startPoint: .top,
                                     endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 150)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text(timeString(from: viewModel.remainingTime))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    
                    Text("Remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                StatSquare(title: "Blinks", value: "\(viewModel.blinkCount)", icon: "eye.fill")
                StatSquare(title: "Twitches", value: "\(viewModel.eyebrowTwitchCount)", icon: "eye.trianglebadge.exclamationmark.fill")
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ExerciseControlView: View {
    @ObservedObject var viewModel: EyeTrackingViewModel
    let geometry: GeometryProxy
    @Binding var targetPosition: CGPoint
    @Binding var isAnimating: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Follow the glowing orb with your eyes only")
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 30)
            
            ZStack {
                OrbView(targetPosition: targetPosition)
                    .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.4)
            }
            
            Spacer()
            
            Button(action: { viewModel.stopExercise() }) {
                Label("Stop Exercise", systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.red, .red.opacity(0.8)],
                                     startPoint: .leading,
                                     endPoint: .trailing)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    )
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [.blue.opacity(0.7), .blue],
                         startPoint: .top,
                         endPoint: .bottom)
        )
    }
}

struct OrbView: View {
    let targetPosition: CGPoint
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.3 - Double(i) * 0.1))
                    .frame(width: 50 + CGFloat(i * 10), height: 50 + CGFloat(i * 10))
                    .blur(radius: CGFloat(i * 2))
            }
            
            Circle()
                .fill(
                    LinearGradient(colors: [.white, .blue.opacity(0.7)],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing)
                )
                .frame(width: 40, height: 40)
                .shadow(color: .white.opacity(0.5), radius: 10)
        }
        .offset(x: targetPosition.x, y: targetPosition.y)
        .animation(.easeInOut(duration: 2), value: targetPosition)
    }
}

