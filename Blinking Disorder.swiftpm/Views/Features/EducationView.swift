//
//  File 3.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import Foundation
import SwiftUI


struct EducationView: View {
    // Educational content sections
    let sections = [
        EducationalSection(
            title: "Understanding Blepharospasm",
            content: [
                ContentItem(
                    title: "What is Blepharospasm?",
                    description: "Blepharospasm is a condition characterized by involuntary muscle contractions and spasms of the eyelids. These spasms can cause excessive blinking, eye closure, and in severe cases, functional blindness. This condition typically affects both eyes and can significantly impact daily activities."
                ),
                ContentItem(
                    title: "Causes and Risk Factors",
                    description: "• Genetic predisposition\n• Brain chemical imbalances\n• Environmental factors\n• Eye irritation\n• Stress and fatigue\n• Certain medications\n• Neurological conditions"
                ),
                ContentItem(
                    title: "Common Symptoms",
                    description: "• Increased frequency of blinking\n• Uncontrollable eye closure\n• Eye irritation and dryness\n• Light sensitivity\n• Vision disturbances\n• Facial spasms\n• Difficulty keeping eyes open"
                ),
                ContentItem(
                    title: "Treatment Options",
                    description: "• Botulinum toxin injections\n• Oral medications\n• Stress management techniques\n• Eye exercises\n• Lifestyle modifications\n• Surgery (in severe cases)"
                ),
                ContentItem(
                    title: "Living with Blepharospasm",
                    description: "Managing blepharospasm involves a combination of medical treatment and lifestyle adjustments. Regular exercise, stress reduction, proper sleep, and avoiding triggers can help minimize symptoms. Support groups and professional counseling can also be beneficial for coping with the condition."
                )
            ]
        ),
        EducationalSection(
            title: "Prevention and Management",
            content: [
                ContentItem(
                    title: "Daily Eye Care",
                    description: "• Take regular breaks from screens\n• Practice the 20-20-20 rule\n• Maintain good eye hygiene\n• Use proper lighting\n• Wear protective eyewear\n• Stay hydrated"
                ),
                ContentItem(
                    title: "Lifestyle Recommendations",
                    description: "• Maintain a regular sleep schedule\n• Practice stress-reduction techniques\n• Exercise regularly\n• Avoid eye strain\n• Follow a healthy diet\n• Limit caffeine intake"
                )
            ]
        )
    ]
    
    var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 25) {
                        // Header Image
                        Image(systemName: "eye.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.top)
                        
                        // Introduction Text
                        Text("Learn about Blepharospasm and how to manage it effectively")
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        // Content Sections
                        ForEach(sections) { section in
                            EnhancedSectionView(section: section)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Education")
                .navigationBarTitleDisplayMode(.large)
                .background(Color(.systemGray6))
            }
        }
}


struct EnhancedSectionView: View {
    let section: EducationalSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header
            HStack {
                Text(section.title)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .padding(.bottom, 5)
            
            // Content Items
            ForEach(section.content) { item in
                EnhancedContentItemView(item: item)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct EnhancedContentItemView: View {
    let item: ContentItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with icon
            HStack(spacing: 10) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.blue)
                
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Description
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 22)
        }
        .padding(15)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
}

// Models
struct EducationalSection: Identifiable {
    let id = UUID()
    let title: String
    let content: [ContentItem]
}

struct ContentItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

// Supporting Views
struct SectionView: View {
    let section: EducationalSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(section.title)
                .font(.title)
                .bold()
                .padding(.bottom, 5)
            
            ForEach(section.content) { item in
                ContentItemView(item: item)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
}

struct ContentItemView: View {
    let item: ContentItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)
                .foregroundColor(.blue)
            
            Text(item.description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
    }
}
