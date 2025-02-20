//
//  File 3.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import SwiftUI

struct EducationContent: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let category: Category
    
    enum Category: String {
        case basics = "Basics"
        case prevention = "Prevention"
        case exercises = "Exercises"
        case lifestyle = "Lifestyle"
    }
}

class EducationViewModel: ObservableObject {
    @Published var selectedCategory: EducationContent.Category = .basics
    
    let educationalContent: [EducationContent] = [
        // Basics
        EducationContent(
            title: "Understanding Eye Strain",
            description: "Learn about digital eye strain, its causes, and how it affects your daily life.",
            iconName: "eye.circle",
            category: .basics
        ),
        EducationContent(
            title: "Common Symptoms",
            description: "Identify the warning signs of digital eye strain and vision problems.",
            iconName: "exclamationmark.circle",
            category: .basics
        ),
        
        // Prevention
        EducationContent(
            title: "20-20-20 Rule",
            description: "Every 20 minutes, look at something 20 feet away for 20 seconds.",
            iconName: "timer",
            category: .prevention
        ),
        EducationContent(
            title: "Proper Lighting",
            description: "Optimize your workspace lighting to reduce eye strain.",
            iconName: "lightbulb",
            category: .prevention
        ),
        
        // Exercises
        EducationContent(
            title: "Eye Yoga",
            description: "Simple exercises to relax and strengthen your eye muscles.",
            iconName: "figure.mind.and.body",
            category: .exercises
        ),
        EducationContent(
            title: "Blinking Exercises",
            description: "Learn proper blinking techniques to keep your eyes moisturized.",
            iconName: "eye",
            category: .exercises
        ),
        
        // Lifestyle
        EducationContent(
            title: "Screen Time Management",
            description: "Tips for managing your daily screen time effectively.",
            iconName: "iphone",
            category: .lifestyle
        ),
        EducationContent(
            title: "Healthy Habits",
            description: "Develop daily habits that promote better eye health.",
            iconName: "heart",
            category: .lifestyle
        )
    ]
    
    func filteredContent() -> [EducationContent] {
        educationalContent.filter { $0.category == selectedCategory }
    }
}

struct EducationView: View {
    @StateObject private var viewModel = EducationViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Picker
                Picker("Category", selection: $viewModel.selectedCategory) {
                    Text("Basics").tag(EducationContent.Category.basics)
                    Text("Prevention").tag(EducationContent.Category.prevention)
                    Text("Exercises").tag(EducationContent.Category.exercises)
                    Text("Lifestyle").tag(EducationContent.Category.lifestyle)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(viewModel.filteredContent()) { content in
                            EducationCard(content: content)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Learn")
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct EducationCard: View {
    let content: EducationContent
    
    var body: some View {
        NavigationLink(destination: EducationDetailView(content: content)) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                Image(systemName: content.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Title
                Text(content.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Description
                Text(content.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                Spacer()
            }
            .frame(height: 180)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
}

struct EducationDetailView: View {
    let content: EducationContent
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: content.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 60)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    
                    VStack(alignment: .leading) {
                        Text(content.category.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(content.title)
                            .font(.title2)
                            .bold()
                    }
                }
                .padding(.bottom)
                
                // Content sections - This would be expanded with real content
                DetailSection(title: "Overview", content: content.description)
                DetailSection(title: "Key Points", content: "• Important point 1\n• Important point 2\n• Important point 3")
                DetailSection(title: "Tips", content: "1. Practical tip 1\n2. Practical tip 2\n3. Practical tip 3")
                DetailSection(title: "Learn More", content: "Additional resources and references would go here.")
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

struct DetailSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    EducationView()
}
