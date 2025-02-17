//
//  File.swift
//  Blinking Disorder
//
//  Created by Akhlak iSDP on 18/02/25.
//

import Foundation
import SwiftUI
import ARKit

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
