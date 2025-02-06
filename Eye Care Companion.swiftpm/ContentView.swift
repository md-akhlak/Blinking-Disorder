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

// MARK: - View Models
class EyeTrackingViewModel: NSObject, ObservableObject, ARSessionDelegate {
    
    @Published var blinkCount = 0
    @Published var eyebrowTwitchCount = 0
    @Published var eyeStrainDetected = false
    @Published var isTracking = false
    @Published var exerciseDuration: TimeInterval = 30
    @Published var remainingTime: TimeInterval = 0
    @Published var isExerciseActive = false
    @Published var stressLevel: Int = 0
    @Published var screenTime: TimeInterval = 0
    
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
        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking is not supported on this device.")
            return
        }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isTracking = true
        isExerciseActive = true
        remainingTime = exerciseDuration
        
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
        
        // Detect blinking
        if let leftEyeBlink = blendShapes[.eyeBlinkLeft]?.floatValue,
           let rightEyeBlink = blendShapes[.eyeBlinkRight]?.floatValue {
            let blinkThreshold: Float = 0.5
            if leftEyeBlink > blinkThreshold && rightEyeBlink > blinkThreshold {
                blinkCount += 1
            }
        }
        
        // Detect eyebrow twitching
        if let browInnerUp = blendShapes[.browInnerUp]?.floatValue,
           browInnerUp > 0.5 {
            eyebrowTwitchCount += 1
        }
        
        // Detect eye strain (example: prolonged eye closure)
        if let eyeBlinkLeft = blendShapes[.eyeBlinkLeft]?.floatValue,
           let eyeBlinkRight = blendShapes[.eyeBlinkRight]?.floatValue,
           eyeBlinkLeft > 0.8 && eyeBlinkRight > 0.8 {
            eyeStrainDetected = true
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var viewModel = EyeTrackingViewModel()
    @State private var selectedDuration: TimeInterval = 30
    
    var body: some View {
        TabView {
            TrackingView(viewModel: viewModel, selectedDuration: $selectedDuration)
                .tabItem {
                    Label("Track", systemImage: "eye")
                }
            
            RelaxationView()
                .tabItem {
                    Label("Relax", systemImage: "heart")
                }
            
            EducationView()
                .tabItem {
                    Label("Learn", systemImage: "book")
                }
            
//            settingView()
            SettingsView(viewModel: viewModel)
                .tabItem{
                    Label("Setting", systemImage: "gear")
                }
        }
    }
}


struct TrackingView: View {
    @ObservedObject var viewModel: EyeTrackingViewModel
    @Binding var selectedDuration: TimeInterval
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                if viewModel.isExerciseActive {
                    ExerciseView(viewModel: viewModel)
                } else {
                    VStack(spacing: 30) {
                        // Stats Card
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
                }
            }
            .navigationTitle("Eye Care")
            .navigationBarTitleDisplayMode(.large)
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
                    .trim(from: 0, to: viewModel.remainingTime / viewModel.exerciseDuration)
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
            Button(action: { viewModel.stopExercise() }) {
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
    }
}

struct DurationPickerView: View {
    @ObservedObject var viewModel: EyeTrackingViewModel
    @Binding var selectedDuration: TimeInterval
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Eye Tracking Exercise")
                .font(.largeTitle)
            
            Text("Set the duration of the exercise:")
                .font(.headline)
            
            Picker("Duration", selection: $selectedDuration) {
                Text("30 Seconds").tag(30.0)
                Text("1 Minute").tag(60.0)
                Text("2 Minutes").tag(120.0)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button(action: {
                viewModel.exerciseDuration = selectedDuration
                viewModel.startExercise()
            }) {
                Text("Start Exercise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
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
        EducationalContent(title: "What is Blepharospasm?", description: "Learn about the causes and treatments for blepharospasm.", url: "https://example.com/blepharospasm"),
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
    
    var body: some View {
        NavigationStack {
            
            }
            .navigationTitle("Settings")
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
