//
//  File 3.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import Foundation
import SwiftUI


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
