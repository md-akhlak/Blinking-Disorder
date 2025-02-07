import SwiftUI
import ARKit

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
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title)
                .bold()
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}



struct TrackingView: View {
    @Binding var selectedDuration: TimeInterval
    @ObservedObject var viewModel: EyeTrackingViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isExerciseActive {
                        ExerciseView(viewModel: viewModel)
                    } else {
                        VStack(spacing: 30) {
                            VStack(spacing: 15) {
                                HStack(spacing: 20) {
                                    StatCard(title: "Blinks", value: "\(viewModel.blinkCount)", icon: "eye")
                                    StatCard(title: "Twitches", value: "\(viewModel.eyebrowTwitchCount)", icon: "eye.trianglebadge.exclamationmark")
                                }
                                
                                if viewModel.eyeStrainDetected {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Eye strain detected")
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(15)
                            
                            // Duration Selector
                            VStack(spacing: 15) {
                                Text("Exercise Duration")
                                    .font(.headline)
                                
                                Picker("Duration", selection: $selectedDuration) {
                                    Text("30 Seconds").tag(30.0)
                                    Text("1 Minute").tag(60.0)
                                    Text("2 Minutes").tag(120.0)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(15)
                            
                            // Start Button
                            Button(action: {
                                viewModel.exerciseDuration = selectedDuration
                                viewModel.startExercise()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start Exercise")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(15)
                            }
                        }
                        .padding()
                        
                        // Exercise History Section
                        if !viewModel.exerciseSessions.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Exercise History")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(spacing: 15) {
                                        ForEach(viewModel.exerciseSessions) { session in
                                            LogCard(session: session)
                                        }
                                    }
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
        }
    }
}



struct LogCard: View {
    let session: ExerciseSession
        
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Timestamp and Duration
            HStack {
                Text(session.timestamp, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("Duration: \(Int(session.duration))s")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 20) {
                // Blinks
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "eye")
                            .foregroundColor(.blue)
                        Text("Blinks")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    Text("\(session.blinkCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Twitches
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "eye.trianglebadge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("Twitches")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    Text("\(session.twitchCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
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

// MARK: - Relaxation View
struct RelaxationView: View {
    
    let exercises = [
        RelaxationExercise(name: "Deep Breathing", description: "Take slow, deep breaths to reduce stress.", duration: 300),
        RelaxationExercise(name: "Eye Palming", description: "Rub your palms together and place them over your eyes.", duration: 180),
        RelaxationExercise(name: "20-20-20 Rule", description: "Every 20 minutes, look at something 20 feet away for 20 seconds.", duration: 20)
    ]
    
    var body: some View {
        NavigationStack {
            List(exercises) { exercise in
                VStack(alignment: .leading) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(exercise.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Duration: \(Int(exercise.duration))s")
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Relaxation")
                        .navigationBarTitleDisplayMode(.large)
        }
    }
}


// MARK: - Education View
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

// MARK: - Settings View
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

