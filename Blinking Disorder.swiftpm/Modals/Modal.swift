//
//  File.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import Foundation
import UIKit


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

