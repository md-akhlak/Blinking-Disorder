//
//  File 2.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import Foundation
import SwiftUI
import AVFAudio

struct RelaxationView: View {
    let exercises = [
            RelaxationExercise(name: "Deep Breathing", description: "Take slow, deep breaths to reduce stress.", duration: 300),
            RelaxationExercise(name: "Eye Palming", description: "Rub your palms together and place them over your eyes.", duration: 180),
            RelaxationExercise(name: "20-20-20 Rule", description: "Every 20 minutes, look at something 20 feet away for 20 seconds.", duration: 20)
        ]
        
        var body: some View {
            NavigationStack {
                List(exercises) { exercise in
                    NavigationLink {
                        Group {
                            switch exercise.name {
                            case "Deep Breathing":
                                BreathingExerciseView()
                                    .toolbar(.hidden, for: .tabBar)
                            case "Eye Palming":
                                EyePalmingView()
                                    .toolbar(.hidden, for: .tabBar)
                            case "20-20-20 Rule":
                                TwentyRuleView()
                                    .toolbar(.hidden, for: .tabBar)
                            default:
                                EmptyView()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: getExerciseIcon(exercise.name))
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .fontWeight(.semibold)
                                Text(exercise.description)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Duration: \(Int(exercise.duration))s")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .navigationTitle("Relaxation")
                .navigationBarTitleDisplayMode(.large)
            }
        }
    
    private func getExerciseIcon(_ name: String) -> String {
        switch name {
        case "Deep Breathing":
            return "lungs.fill"
        case "Eye Palming":
            return "hand.raised.fill"
        case "20-20-20 Rule":
            return "eye.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}




@MainActor
class BreathingViewModel: ObservableObject {
    @Published var isBreathing = false
    @Published var breathingPhase = "Prepare"
    @Published var remainingTime: TimeInterval = 300
    @Published var progress: CGFloat = 1.0
    @Published var scale: CGFloat = 1.0
    
    private var breathingTimer: Timer?
    
    func startBreathing() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                breathingPhase = "Inhale"
                withAnimation(.easeInOut(duration: 4)) {
                    scale = 1.5
                }
                startBreathingCycle()
            }
        }
    }
    
    private func startBreathingCycle() {
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            Task { @MainActor in
                switch self.breathingPhase {
                case "Inhale":
                    self.breathingPhase = "Hold"
                    self.scale = 1.5
                case "Hold":
                    self.breathingPhase = "Exhale"
                    withAnimation(.easeInOut(duration: 4)) {
                        self.scale = 1.0
                    }
                case "Exhale":
                    self.breathingPhase = "Inhale"
                    withAnimation(.easeInOut(duration: 4)) {
                        self.scale = 1.5
                    }
                default:
                    break
                }
                
                if self.remainingTime <= 0 {
                    self.breathingTimer?.invalidate()
                    self.breathingTimer = nil
                }
            }
        }
    }
    
    func updateTimer() {
        if remainingTime > 0 {
            remainingTime -= 1
            progress = remainingTime / 300
        }
    }
    
    func stopBreathing() {
        breathingTimer?.invalidate()
        breathingTimer = nil
    }
}


struct BreathingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BreathingViewModel()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Add voice synthesizer
    let synthesizer = AVSpeechSynthesizer()
    
    private func stopExercise() {
        viewModel.stopBreathing()
        synthesizer.stopSpeaking(at: .immediate)
        dismiss()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [.blue.opacity(0.1), .white],
                             startPoint: .top,
                             endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    VStack(spacing: 8) {
                        Text(timeString(from: viewModel.remainingTime))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        
                        Text("Remaining Time")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    .padding(.top, 40)
                    
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.2), lineWidth: 15)
                            .frame(width: min(geometry.size.width * 0.7, 300))
                        
                        Circle()
                            .trim(from: 0, to: viewModel.progress)
                            .stroke(
                                LinearGradient(colors: [.blue, .blue.opacity(0.7)],
                                             startPoint: .top,
                                             endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                            )
                            .frame(width: min(geometry.size.width * 0.7, 300))
                            .rotationEffect(.degrees(-90))
                        
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: min(geometry.size.width * 0.5, 200))
                            .scaleEffect(viewModel.scale)
                            .animation(.easeInOut(duration: viewModel.breathingPhase == "Inhale" ? 4 : 4), value: viewModel.scale)
                        
                        Text(viewModel.breathingPhase)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    .frame(height: min(geometry.size.width * 0.8, 350))
                    
                    VStack(spacing: 12) {
                        Text(breathingInstructions)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                        stopExercise()
                    }) {
                        Label("End Exercise", systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.red, .red.opacity(0.8)],
                                             startPoint: .leading,
                                             endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            viewModel.startBreathing()
            
            // Initial voice guidance
            let utterance = AVSpeechUtterance(string: "Deep Breathing exercise. Let's begin by taking slow, deep breaths.")
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.8
            synthesizer.speak(utterance)
        }
        .onReceive(timer) { _ in
            if viewModel.remainingTime > 0 {
                viewModel.updateTimer()
                
                // Voice guidance for breathing phases
                if viewModel.breathingPhase != "Prepare" {
                    let phaseMessage: String
                    switch viewModel.breathingPhase {
                    case "Inhale":
                        phaseMessage = "Inhale slowly"
                    case "Hold":
                        phaseMessage = "Hold your breath"
                    case "Exhale":
                        phaseMessage = "Exhale slowly"
                    default:
                        phaseMessage = ""
                    }
                    
                    // Stop previous utterance before starting new one
                    synthesizer.stopSpeaking(at: .immediate)
                    let utterance = AVSpeechUtterance(string: phaseMessage)
                    utterance.rate = 0.5
                    utterance.volume = 0.8
                    synthesizer.speak(utterance)
                }
            } else {
                stopExercise()
            }
        }
        .navigationTitle("Deep Breathing")
        .navigationBarTitleDisplayMode(.inline)

    }
    
    private var breathingInstructions: String {
        switch viewModel.breathingPhase {
        case "Prepare":
            return "Get ready to start your breathing exercise"
        case "Inhale":
            return "Breathe in slowly through your nose"
        case "Hold":
            return "Hold your breath"
        case "Exhale":
            return "Breathe out slowly through your mouth"
        default:
            return ""
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct EyePalmingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remainingTime: TimeInterval = 180 // Changed to 3 minutes
    @State private var currentStep = 0
    @State private var isRubbing = false
    @State private var showWarmth = false
    @State private var showHandsOverEyes = false
    @State private var showEyesClosed = false
    @State private var showBreathing = false
    @State private var cycleCount = 0
    
    // Add voice synthesizer
    let synthesizer = AVSpeechSynthesizer()
    
    let steps = [
        (title: "Rub your palms together", duration: 10, icon: "hands.sparkles.fill", voicePrompt: "Gently rub your palms together to create warmth"),
        (title: "Feel the warmth in your palms", duration: 5, icon: "flame.fill", voicePrompt: "Feel the warmth building in your palms"),
        (title: "Cup your palms, place over eyes", duration: 10, icon: "hand.raised.fill", voicePrompt: "Now, cup your palms and place them gently over your closed eyes"),
        (title: "Keep eyes closed in darkness", duration: 10, icon: "eye.slash.fill", voicePrompt: "Keep your eyes closed and enjoy the darkness"),
        (title: "Breathe deeply and relax", duration: 10, icon: "lungs.fill", voicePrompt: "Take deep breaths and relax your mind")
    ]
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Timer Display
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.2), lineWidth: 12)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .trim(from: 0, to: remainingTime / 180)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 5) {
                            Text(timeString(from: remainingTime))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                    .padding(.top, 20)
                    
                    // Animation Area
                    ZStack {
                        // Step 1: Rubbing Hands
                        if currentStep == 0 {
                            HStack(spacing: 20) {
                                Image(systemName: "hand.raised.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80)
                                    .foregroundColor(.blue)
                                    .offset(x: isRubbing ? -10 : 10, y: 0)
                                    .rotationEffect(.degrees(isRubbing ? -15 : 15))
                                
                                Image(systemName: "hand.raised.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80)
                                    .foregroundColor(.blue)
                                    .offset(x: isRubbing ? 10 : -10, y: 0)
                                    .rotationEffect(.degrees(isRubbing ? 15 : -15))
                            }
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRubbing)
                        }
                        
                        // Step 2: Feel Warmth
                        if currentStep == 1 {
                            ZStack {
                                Image(systemName: "hand.raised.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80)
                                    .foregroundColor(.blue)
                                
                                if showWarmth {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .fill(Color.red.opacity(0.2))
                                            .frame(width: CGFloat(80 + index * 20))
                                            .scaleEffect(showWarmth ? 1.2 : 1.0)
                                            .animation(.easeInOut(duration: 1.0).repeatForever(), value: showWarmth)
                                    }
                                }
                            }
                        }
                        
                        // Step 3: Hands Over Eyes
                        if currentStep == 2 {
                            ZStack {
                                // Face
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 150, height: 150)
                                
                                // Eyes
                                HStack(spacing: 40) {
                                    Circle()
                                        .fill(Color.blue.opacity(0.7))
                                        .frame(width: 15, height: 15)
                                    
                                    Circle()
                                        .fill(Color.blue.opacity(0.7))
                                        .frame(width: 15, height: 15)
                                }
                                
                                // Hands
                                HStack(spacing: 20) {
                                    Image(systemName: "hand.raised.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80)
                                        .foregroundColor(.blue)
                                        .offset(y: showHandsOverEyes ? -50 : -30)
                                        .rotationEffect(.degrees(-15))
                                    
                                    Image(systemName: "hand.raised.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80)
                                        .foregroundColor(.blue)
                                        .offset(y: showHandsOverEyes ? -50 : -30)
                                        .rotationEffect(.degrees(15))
                                }
                                .animation(.easeInOut(duration: 0.5), value: showHandsOverEyes)
                            }
                        }
                        
                        // Step 4: Eyes Closed
                        if currentStep == 3 {
                            ZStack {
                                // Face
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 150, height: 150)
                                
                                // Closed Eyes
                                HStack(spacing: 40) {
                                    Capsule()
                                        .fill(Color.blue.opacity(0.7))
                                        .frame(width: 30, height: 5)
                                    
                                    Capsule()
                                        .fill(Color.blue.opacity(0.7))
                                        .frame(width: 30, height: 5)
                                }
                            }
                        }
                        
                        // Step 5: Breathing
                        if currentStep == 4 {
                            ZStack {
                                // Breathing Animation
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: showBreathing ? 200 : 150, height: showBreathing ? 200 : 150)
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: showBreathing)
                                
                                Image(systemName: "lungs.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(height: 200)
                    
                    // Current Instruction
                    VStack(spacing: 10) {
                        Image(systemName: steps[currentStep].icon)
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        Text(steps[currentStep].title)
                            .font(.title3)
                            .bold()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        
                        Text("\(Int(getStepRemainingTime()))s remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(15)
                    
                    // Progress Dots
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count) { index in
                            Circle()
                                .fill(currentStep == index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Spacer()
                    
                    // Stop Button
                    Button(action: { stopExercise() }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("End Exercise")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.red.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            startStepAnimation()
            
            // Initial voice guidance
            let utterance = AVSpeechUtterance(string: "Eye Palming exercise. Let's begin by rubbing your palms together.")
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.8
            synthesizer.speak(utterance)
        }
        .onReceive(timer) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
                updateStep()
            } else {
                dismiss()
            }
        }
        .navigationTitle("Eye Palming")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func stopExercise() {
        synthesizer.stopSpeaking(at: .immediate)
        dismiss()
    }
    
    private func startStepAnimation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            switch currentStep {
            case 0: // Rubbing palms
                isRubbing = true
                showWarmth = false
                showHandsOverEyes = false
                showEyesClosed = false
                showBreathing = false
            case 1: // Feel warmth
                isRubbing = false
                showWarmth = true
                showHandsOverEyes = false
                showEyesClosed = false
                showBreathing = false
            case 2: // Place over eyes
                showWarmth = false
                showHandsOverEyes = true
                showEyesClosed = false
                showBreathing = false
            case 3: // Keep closed
                showHandsOverEyes = false
                showEyesClosed = true
                showBreathing = false
            case 4: // Breathe deeply
                showEyesClosed = false
                showBreathing = true
            default:
                break
            }
        }
    }
    
    private func getStepRemainingTime() -> TimeInterval {
        let totalTimeForPreviousSteps = steps[0..<currentStep].reduce(0) { $0 + $1.duration }
        let stepStartTime = 180 - totalTimeForPreviousSteps
        return remainingTime - Double((stepStartTime - steps[currentStep].duration))
    }
    
    private func updateStep() {
        let cycleTime = steps.reduce(0) { $0 + $1.duration } // Total time for one cycle
        let currentTime = 180 - remainingTime // Time elapsed
        
        let newCycleCount = Int(currentTime / Double(cycleTime))
        if newCycleCount != cycleCount {
            cycleCount = newCycleCount
            // Wait for previous utterance to finish before starting new one
            synthesizer.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: "Starting cycle \(cycleCount + 1)")
            utterance.rate = 0.5
            utterance.volume = 0.8
            synthesizer.speak(utterance)
        }
        
        let timeInCurrentCycle = currentTime.truncatingRemainder(dividingBy: Double(cycleTime))
        var accumulatedTime: TimeInterval = 0
        
        for (index, step) in steps.enumerated() {
            if timeInCurrentCycle >= accumulatedTime && timeInCurrentCycle < accumulatedTime + Double(step.duration) {
                if currentStep != index {
                    currentStep = index
                    startStepAnimation()
                    
                    // Stop previous utterance before starting new one
                    synthesizer.stopSpeaking(at: .immediate)
                    let utterance = AVSpeechUtterance(string: step.voicePrompt)
                    utterance.rate = 0.5
                    utterance.pitchMultiplier = 1.0
                    utterance.volume = 0.8
                    synthesizer.speak(utterance)
                }
                break
            }
            accumulatedTime += Double(step.duration)
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}


struct TwentyRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remainingTime: TimeInterval = 20
    @State private var currentPhase = "Get ready to start"
    @State private var isTimerActive = false
    @State private var showExerciseGuide = false
    
    // Add voice synthesizer
    let synthesizer = AVSpeechSynthesizer()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let exercises = [
        "Look up",
        "Look down",
        "Look left",
        "Look right",
        "Look at something 20 feet away"
    ]
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Timer Card
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
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue.opacity(0.1))
                )
                .padding(.horizontal)
                
                VStack(spacing: 20) {
                    // Exercise animation area
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 300)
                        
                        if showExerciseGuide {
                            switch currentPhase {
                            case "Look up":
                                VStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                    Text("Look up")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            case "Look down":
                                VStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                    Text("Look down")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            case "Look left":
                                VStack {
                                    Image(systemName: "arrow.left.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                    Text("Look left")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            case "Look right":
                                VStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                    Text("Look right")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            case "Look at something 20 feet away":
                                VStack {
                                    Image(systemName: "eye.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                    Text("Look 20 feet away")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            default:
                                VStack {
                                    Image(systemName: "eye.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                    Text("Get ready")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        } else {
                            Button(action: {
                                startExercise()
                            }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 60))
                                    Text("Start Exercise")
                                        .font(.headline)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Text(currentPhase)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Button(action: {
                    stopExercise()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop Exercise")
                    }
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.red)
                    .cornerRadius(15)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 40)
        }
        .onReceive(timer) { _ in
            if isTimerActive && remainingTime > 0 {
                remainingTime -= 1
                if showExerciseGuide {
                    let newPhase = exercises[Int((20 - remainingTime) / 4) % exercises.count]
                    if newPhase != currentPhase {
                        currentPhase = newPhase
                        // Voice guidance for new phase
                        let utterance = AVSpeechUtterance(string: newPhase)
                        utterance.rate = 0.5
                        utterance.volume = 0.8
                        synthesizer.speak(utterance)
                    }
                }
            } else if remainingTime == 0 {
                stopExercise()
            }
        }
        .onAppear {
            // Initial voice guidance
            let utterance = AVSpeechUtterance(string: "twenty twenty twenty Rule exercise. Press start when you're ready.")
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.8
            synthesizer.speak(utterance)
        }
        .navigationTitle("20-20-20 Rule")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startExercise() {
        isTimerActive = true
        showExerciseGuide = true
        currentPhase = exercises[0]
        
        // Start exercise voice guidance
        let utterance = AVSpeechUtterance(string: "Follow the instructions.")
        utterance.rate = 0.5
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
    
    private func stopExercise() {
        isTimerActive = false
        showExerciseGuide = false
        synthesizer.stopSpeaking(at: .immediate)
        dismiss()
    }
}

// Remove CameraView struct entirely as it's no longer needed










