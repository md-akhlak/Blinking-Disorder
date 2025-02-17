//
//  File 4.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import Foundation
import SwiftUI

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
