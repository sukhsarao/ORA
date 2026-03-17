//
//  SplashScreenView.swift
//  ORA
//
//  Created by Sukhman Singh on 5/10/2025.
//

import SwiftUI

/// Splash screen to prevent jittering during loading times.
struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
        }
        
    }
}

#Preview {
    SplashScreenView()
}
