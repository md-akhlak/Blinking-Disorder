import SwiftUI
@preconcurrency import ARKit

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

// Your imports remain the same

struct TimeCard: View {
    let duration: TimeInterval
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(duration == 30 ? "Quick" : duration == 60 ? "Regular" : "Extended")
                .font(.headline)
                .foregroundStyle(isSelected ? .white : .primary)
            
            Text(formatDuration(duration))
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ?
                    AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.8)],
                                              startPoint: .leading,
                                              endPoint: .trailing)) :
                    AnyShapeStyle(Color(.systemGray6)))
        )
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        seconds == 30 ? "30 sec" : seconds == 60 ? "1 min" : "2 min"
    }
}

// Rest of the code remains the same
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
                                .background(Color.blue.gradient)
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
    
    var body: some View {
        VStack(spacing: 25) {
            // Timer Display
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 10)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.remainingTime / viewModel.exerciseDuration))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.remainingTime)
                
                VStack {
                    Text("\(Int(viewModel.remainingTime))")
                        .font(.system(size: 50, weight: .bold))
                    Text("seconds")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Text("Follow the moving dot with your eyes")
                .font(.headline)
            
            // Exercise Area
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .offset(x: viewModel.isExerciseActive ? CGFloat.random(in: -100...100) : 0,
                            y: viewModel.isExerciseActive ? CGFloat.random(in: -100...100) : 0)
                    .animation(.easeInOut(duration: 1), value: viewModel.isExerciseActive)
            }
            .frame(maxWidth: .infinity, maxHeight: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            
            // Stop Button
            Button(action: {
                print("Stop Exercise Button Pressed")
                viewModel.stopExercise()
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop Exercise")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(15)
            }
        }
        .padding()
        .background(Color.white) // Ensure background is visible
        .edgesIgnoringSafeArea(.all)
    }
}

struct BreathingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isBreathing = false
    @State private var breathingPhase = "Get Ready"
    @State private var scale: CGFloat = 1.0
    @State private var remainingTime: TimeInterval = 300 // 5 minutes total
    @State private var phaseCountdown: Int = 5 // Countdown for each phase
    @State private var opacity: Double = 0.3
    
    let breathTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                // Timer Display Card
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
                
                // Breathing Animation
                ZStack {
                    // Background circles
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            .frame(width: CGFloat(200 + index * 30), height: CGFloat(200 + index * 30))
                    }
                    
                    // Main breathing circle
                    Circle()
                        .fill(Color.blue.opacity(opacity))
                        .frame(width: 200, height: 200)
                        .scaleEffect(scale)
                        .animation(.easeInOut(duration: 5), value: scale)
                    
                    VStack(spacing: 15) {
                        Text(breathingPhase)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.blue)
                        
                        Text("\(phaseCountdown)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Stop Button
                Button(action: {
                    dismiss()
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
        .onAppear {
            startBreathing()
        }
        .onReceive(breathTimer) { _ in
            if isBreathing {
                if phaseCountdown > 0 {
                    phaseCountdown -= 1
                } else {
                    phaseCountdown = 5 // Reset countdown
                    if breathingPhase == "Inhale" {
                        breathingPhase = "Exhale"
                        scale = 1.0
                        opacity = 0.3
                    } else {
                        breathingPhase = "Inhale"
                        scale = 1.5
                        opacity = 0.7
                    }
                }
            }
        }
        .onReceive(countdownTimer) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                dismiss()
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startBreathing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isBreathing = true
            breathingPhase = "Inhale"
            scale = 1.5
            opacity = 0.7
            phaseCountdown = 5
        }
    }
}

// Your imports remain the same

struct EyePalmingView: View {
        @Environment(\.dismiss) private var dismiss
        @State private var remainingTime: TimeInterval = 53 // Total duration
        @State private var currentStep = 0
        @State private var handPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: 200)
        @State private var isRubbing = false
        @State private var showWarmth = false
        @State private var handScale: CGFloat = 1.0
        @State private var handRotation: Double = 0
        
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
                            // Face outline
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 140, height: 140)
                            
                            // Eyes
                            HStack(spacing: 40) {
                                Circle()
                                    .fill(Color.blue.opacity(0.7))
                                    .frame(width: 15, height: 15)
                                
                                Circle()
                                    .fill(Color.blue.opacity(0.7))
                                    .frame(width: 15, height: 15)
                            }
                            
                            // Hands Animation
                            Group {
                                if currentStep < 3 {
                                    // Left hand
                                    Image(systemName: "hand.raised.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80)
                                        .foregroundColor(.blue)
                                        .offset(x: isRubbing ? -50 : -40, y: handPosition.y)
                                        .rotationEffect(.degrees(isRubbing ? -15 : -30))
                                        .scaleEffect(handScale)
                                    
                                    // Right hand
                                    Image(systemName: "hand.raised.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80)
                                        .foregroundColor(.blue)
                                        .offset(x: isRubbing ? 50 : 40, y: handPosition.y)
                                        .rotationEffect(.degrees(isRubbing ? 15 : 30))
                                        .scaleEffect(handScale)
                                }
                            }
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRubbing)
                            
                            // Warmth effect
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
        }
    
    private func startStepAnimation() {
            withAnimation(.easeInOut(duration: 0.5)) {
                switch currentStep {
                case 0: // Rubbing palms
                    isRubbing = true
                    handPosition.y = 30
                    handScale = 1.1
                    showWarmth = false
                case 1: // Feel warmth
                    isRubbing = false
                    showWarmth = true
                    handPosition.y = 20
                    handScale = 1.0
                case 2: // Place over eyes
                    showWarmth = false
                    handPosition.y = 0
                    handScale = 1.2
                case 3, 4: // Keep closed and relax
                    handPosition.y = 0
                    handScale = 1.2
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
                
                // Camera Preview and Exercise Area
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
                        
                        // Exercise direction indicators
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
                    
                    // Exercise Instructions
                    Text(currentPhase)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Stop Button
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
                // Change exercise every 4 seconds
                if showExerciseGuide {
                    currentPhase = exercises[Int((20 - remainingTime) / 4) % exercises.count]
                }
            } else if remainingTime == 0 {
                stopExercise()
            }
        }
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
            // Add a delay before showing the guide to ensure camera is running
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

// Add CameraView for handling camera preview
@preconcurrency import AVFoundation

// Your imports remain the same
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

// Your imports remain the same

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
                        // Exercise views based on exercise name
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

// Rest of your code remains the same
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
