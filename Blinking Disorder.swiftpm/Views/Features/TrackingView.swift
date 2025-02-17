//
//  File.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import Foundation
import SwiftUI
import AVFAudio


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
    
    // Add voice synthesizer
    let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        ExerciseContentView(
            viewModel: viewModel,
            targetPosition: $targetPosition,
            isAnimating: $isAnimating,
            synthesizer: synthesizer
        )
    }
    
    // All other functions remain the same
}
