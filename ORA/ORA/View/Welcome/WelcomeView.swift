import SwiftUI

// MARK: - WelcomeView
/// The first screen users see when opening the app.
/// Provides options to navigate to Login or Signup screens.
/// Shows app branding with decorative circular gradients.
struct WelcomeView: View {
    
    // Navigation state
    @State private var goToLogin = false
    @State private var goToSignup = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color("Background").ignoresSafeArea()
                
                VStack {
                    // Branding area with background circles
                    ZStack {
                        CoffeeLayout {
                            RadialCircle(size: 300, colors: [Color("CircleOne"), Color("CircleTwo")])
                            RadialCircle(size: 200, colors: [Color("CircleOne"), Color("CircleTwo")])
                        }
                        
                        VStack(spacing: 10) {
                            // Logo
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 120))
                                .foregroundColor(Color("Primary"))
                            
                            // App title
                            Text("ORA")
                                .font(Font.custom("Skranji-Bold", size: 60))
                                .bold()
                                .foregroundColor(Color("Primary"))
                            
                            // Tagline
                            Text("Bringing Melbourne's coffee to your cup.")
                                .font(.subheadline).bold()
                                .foregroundColor(Color("Primary"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 20) {
                        // Login button
                        Button("Login") { goToLogin = true }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(Color("Primary"))
                            .cornerRadius(50)
                            .frame(width: 250, height: 50)
                        
                        // Signup button
                        Button("Signup") { goToSignup = true }
                            .font(.headline)
                            .foregroundColor(Color("Primary"))
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 50)
                                    .stroke(Color("Primary"), lineWidth: 2)
                            )
                            .frame(width: 250, height: 50)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            // MARK: - Navigation destinations
            .navigationDestination(isPresented: $goToLogin) {
                LoginView()
                    .environmentObject(AuthManager())
            }
            .navigationDestination(isPresented: $goToSignup) {
                SignupView()
                    .environmentObject(AuthManager())
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WelcomeView()
}
