import SwiftUI
@preconcurrency import ARKit
@preconcurrency import AVFoundation

// MARK: - Data Models
struct SymptomLog: Identifiable {
    let id = UUID()
    let date: Date
    let symptomType: String
    let intensity: Int
    let notes: String
    let trigger: String?
}

struct RelaxationExercise: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let duration: TimeInterval
}

struct EducationalContent: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let url: String
}

struct ExerciseSession: Identifiable {
    let id = UUID()
    let timestamp: Date
    let duration: TimeInterval
    let blinkCount: Int
    let twitchCount: Int
}

// MARK: - View Models
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


struct ARViewContainer: UIViewRepresentable {
    let eyeTracker: EyeTrackingViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.session.delegate = eyeTracker
        arView.automaticallyUpdatesLighting = true
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

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
                
                SettingsView(viewModel: viewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .opacity(viewModel.isExerciseActive ? 0 : 1)
            }
            .tint(.blue)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct TimeCard: View {
    let duration: TimeInterval
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Duration icon
            Circle()
                .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: getDurationIcon())
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .blue)
                }
            
            Text(getDurationTitle())
                .font(.headline)
                .foregroundStyle(isSelected ? .primary : .secondary)
            
            // Time text
            Text(formatDuration(duration))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.05),
                       radius: isSelected ? 8 : 4,
                       x: 0,
                       y: isSelected ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .animation(.spring(dampingFraction: 0.7), value: isSelected)
    }
    
    private func getDurationIcon() -> String {
        switch duration {
        case 30:
            return "bolt.fill"
        case 60:
            return "clock.fill"
        default:
            return "timer.square.fill"
        }
    }
    
    private func getDurationTitle() -> String {
        switch duration {
        case 30:
            return "Quick"
        case 60:
            return "Regular"
        default:
            return "Extended"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        seconds == 30 ? "30 sec" : seconds == 60 ? "1 min" : "2 min"
    }
}


struct TrackingView: View {
    @Binding var selectedDuration: TimeInterval
    @ObservedObject var viewModel: EyeTrackingViewModel
    
    let durations: [TimeInterval] = [30, 60, 120]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isExerciseActive {
                        ExerciseView(viewModel: viewModel)
                    } else {
                        // Stats Section
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                StatCard(title: "Blinks", value: "\(viewModel.blinkCount)", icon: "eye")
                                StatCard(title: "Twitches", value: "\(viewModel.eyebrowTwitchCount)", icon: "eye.trianglebadge.exclamationmark")
                            }
                            
                            if viewModel.eyeStrainDetected {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Eye strain detected")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                        
                        // Duration Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Exercise Duration")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                ForEach(durations, id: \.self) { duration in
                                    Button(action: { selectedDuration = duration }) {
                                        TimeCard(duration: duration, isSelected: selectedDuration == duration)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Start Button
                        Button(action: {
                            viewModel.exerciseDuration = selectedDuration
                            viewModel.startExercise()
                        }) {
                            Label("Start Exercise", systemImage: "play.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding()
                        
                        // History Section remains the same
                        if !viewModel.exerciseSessions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Exercise History")
                                    .font(.title2)
                                    .bold()
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.exerciseSessions) { session in
                                    LogCard(session: session)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Eye Care")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }
}


struct LogCard: View {
    let session: ExerciseSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.timestamp, style: .time)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Duration: \(Int(session.duration))s")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            
            Divider()
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Label("Blinks", systemImage: "eye")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    
                    Text("\(session.blinkCount)")
                        .font(.title2.bold())
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Label("Twitches", systemImage: "eye.trianglebadge.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    
                    Text("\(session.twitchCount)")
                        .font(.title2.bold())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct ExerciseView: View {
    @ObservedObject var viewModel: EyeTrackingViewModel
    @State private var targetPosition = CGPoint(x: 0, y: 0)
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.2), lineWidth: 15)
                            .frame(width: min(geometry.size.width * 0.6, 200))
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.remainingTime / viewModel.exerciseDuration))
                            .stroke(
                                LinearGradient(colors: [.blue, .blue.opacity(0.7)],
                                               startPoint: .top,
                                               endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                            )
                            .frame(width: min(geometry.size.width * 0.6, 200))
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                )
                
                VStack(spacing: 24) {
                    Text("Follow the glowing orb with your eyes only")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 30)
                    
                    ZStack {
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
                    .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.4)
                    .onAppear {
                        startOrbMovement(in: geometry)
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
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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


struct StatSquare: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                        viewModel.stopBreathing()
                        dismiss()
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
        }
        .onReceive(timer) { _ in
            viewModel.updateTimer()
            if viewModel.remainingTime <= 0 {
                dismiss()
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
    @State private var remainingTime: TimeInterval = 53 // Total duration
    @State private var currentStep = 0
    @State private var isRubbing = false
    @State private var showWarmth = false
    @State private var showHandsOverEyes = false
    @State private var showEyesClosed = false
    @State private var showBreathing = false
    
    let steps = [
        (title: "Rub your palms together", duration: 20, icon: "hands.sparkles.fill"),
        (title: "Feel the warmth in your palms", duration: 3, icon: "flame.fill"),
        (title: "Cup your palms, place over eyes", duration: 5, icon: "hand.raised.fill"),
        (title: "Keep eyes closed in darkness", duration: 5, icon: "eye.slash.fill"),
        (title: "Breathe deeply and relax", duration: 20, icon: "lungs.fill")
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
                            .trim(from: 0, to: remainingTime / 53)
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
                    Button(action: { dismiss() }) {
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
        let stepStartTime = 53 - totalTimeForPreviousSteps
        return remainingTime - Double((stepStartTime - steps[currentStep].duration))
    }
    
    private func updateStep() {
        let totalTimeForPreviousSteps = steps[0..<currentStep].reduce(0) { $0 + $1.duration }
        let nextStepStartTime = 53 - totalTimeForPreviousSteps
        
        if Int(remainingTime) <= nextStepStartTime - steps[currentStep].duration && currentStep < steps.count - 1 {
            currentStep += 1
            startStepAnimation()
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
    @State private var currentPhase = "Enable camera to start exercise"
    @State private var isTimerActive = false
    @State private var isCameraRunning = false
    @State private var showExerciseGuide = false
    @State private var cameraPermissionGranted = false
    
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
                    ZStack {
                        if isCameraRunning {
                            CameraView(isActive: $isCameraRunning)
                                .frame(height: 300)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        } else {
                            Button(action: {
                                checkCameraPermission()
                            }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "camera.fill")
                                        .font(.largeTitle)
                                    Text("Enable Camera")
                                        .font(.headline)
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                            }
                        }
                        
                        if showExerciseGuide {
                            switch currentPhase {
                            case "Look up":
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                    .offset(y: -100)
                            case "Look down":
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                    .offset(y: 100)
                            case "Look left":
                                Image(systemName: "arrow.left.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                    .offset(x: -100)
                            case "Look right":
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                    .offset(x: 100)
                            default:
                                EmptyView()
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
                    currentPhase = exercises[Int((20 - remainingTime) / 4) % exercises.count]
                }
            } else if remainingTime == 0 {
                stopExercise()
            }
        }
        .navigationTitle("20-20-20 Rule")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startExercise()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        startExercise()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func startExercise() {
        DispatchQueue.main.async {
            isCameraRunning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isTimerActive = true
                showExerciseGuide = true
                currentPhase = exercises[0]
            }
        }
    }
    
    private func stopExercise() {
        isCameraRunning = false
        isTimerActive = false
        showExerciseGuide = false
        dismiss()
    }
}


struct CameraView: UIViewRepresentable {
    @Binding var isActive: Bool
    
    @MainActor
    class Coordinator: NSObject {
        let parent: CameraView
        private(set) var previewLayer: AVCaptureVideoPreviewLayer?
        let session: AVCaptureSession
        
        init(_ parent: CameraView) {
            self.parent = parent
            self.session = AVCaptureSession()
            super.init()
            setupSession()
        }
        
        func setupSession() {
            session.sessionPreset = .high
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device)
            else {
                print("Failed to get camera device")
                return
            }
            
            if session.canAddInput(input) {
                session.addInput(input)
                Task.detached { [weak self] in
                    await self?.session.startRunning()
                }
            }
        }
        
        func updatePreviewLayer(_ frame: CGRect) {
            previewLayer?.frame = frame
        }
        
        func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = layer
        }
        
        func startSession() {
            Task.detached { [weak self] in
                await self?.session.startRunning()
            }
        }
        
        func stopSession() {
            Task.detached { [weak self] in
                await self?.session.stopRunning()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: context.coordinator.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        
        view.layer.addSublayer(previewLayer)
        context.coordinator.setPreviewLayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        Task { @MainActor in
            context.coordinator.updatePreviewLayer(uiView.bounds)
            
            if isActive && !context.coordinator.session.isRunning {
                context.coordinator.startSession()
            } else if !isActive && context.coordinator.session.isRunning {
                context.coordinator.stopSession()
            }
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopSession()
    }
}

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

struct EducationView: View {
    let articles = [
        EducationalContent(title: "What is Blepharospasm?", description: "Learn about the causes and treatments for blepharospasm.", url: "https://en.wikipedia.org/wiki/Blepharospasm"),
        EducationalContent(title: "Understanding Tic Disorders", description: "A guide to tic disorders and how to manage them.", url: "https://example.com/tics"),
        EducationalContent(title: "Eye Strain and Screen Time", description: "Tips to reduce eye strain from prolonged screen use.", url: "https://example.com/eye-strain")
    ]
    
    var body: some View {
        NavigationStack {
            List(articles) { article in
                VStack(alignment: .leading) {
                    Text(article.title)
                        .font(.headline)
                    Text(article.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Education")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: EyeTrackingViewModel
    @State private var notificationsEnabled = false
    @State private var screenBreakReminder = false
    @State private var blinkThreshold = 10.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Session Stats")) {
                    HStack {
                        Text("Total Blinks")
                        Spacer()
                        Text("\(viewModel.blinkCount)")
                    }
                    
                    HStack {
                        Text("Total Twitches")
                        Spacer()
                        Text("\(viewModel.eyebrowTwitchCount)")
                    }
                    
                    HStack {
                        Text("Screen Time")
                        Spacer()
                        Text(formatScreenTime(viewModel.screenTime))
                    }
                }
                
                Section(header: Text("Eye Health")) {
                    if viewModel.eyeStrainDetected {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Potential Eye Strain Detected")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func formatScreenTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
