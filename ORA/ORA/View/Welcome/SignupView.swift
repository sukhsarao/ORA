import SwiftUI

// MARK: - SignupView
/// A registration screen for new users to create an ORA account.
/// Provides fields for username, email, password, and password confirmation.
/// Validates input and navigates to the main app view on success.
struct SignupView: View {
    
    @EnvironmentObject var auth: AuthManager
    
    // Form state
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // Navigation state
    @State private var goToMain = false
    @State private var goToLogin = false
    
    // Error message state
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color("Background").ignoresSafeArea()
                
                // Decorative coffee layout circles
                CoffeeLayout {
                    RadialCircle(size: 300, colors: [Color("CircleOne"), Color("CircleTwo")])
                    RadialCircle(size: 200, colors: [Color("CircleOne"), Color("CircleTwo")])
                }
                
                VStack {
                    // App logo
                    HStack {
                        Text("ORA")
                            .font(Font.custom("Skranji-Bold", size: 40))
                            .foregroundColor(Color("Primary"))
                            .padding(.leading)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Registration form
                    VStack(spacing: 20) {
                        Text("Register")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Input fields
                        VStack(alignment: .leading, spacing: 10) {
                            Group {
                                Text("Username")
                                TextField("Choose a username", text: $username)
                                    .padding()
                                    .background(AppColor.primary.opacity(0.2))
                                    .cornerRadius(15)
                                    .tint(Color("Primary"))
                                
                                Text("Email")
                                TextField("Enter your email", text: $email)
                                    .padding()
                                    .background(AppColor.primary.opacity(0.2))
                                    .cornerRadius(15)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .tint(Color("Primary"))
                                
                                Text("Password")
                                SecureField("Enter your password", text: $password)
                                    .padding()
                                    .background(AppColor.primary.opacity(0.2))
                                    .cornerRadius(15)
                                    .tint(Color("Primary"))
                                
                                Text("Confirm Password")
                                SecureField("Re-enter your password", text: $confirmPassword)
                                    .padding()
                                    .background(AppColor.primary.opacity(0.2))
                                    .cornerRadius(15)
                                    .tint(Color("Primary"))
                            }
                        }
                        .foregroundColor(Color("Primary"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        
                        // Sign up button
                        Button(action: handleSignUp) {
                            Text("Sign up")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("Primary"))
                                .cornerRadius(25)
                        }
                        
                        // Error message display
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                                .transition(.opacity)
                        }
                        
                        // Navigation to login
                        HStack {
                            Text("Have an account?")
                            Button("Log in") { goToLogin = true }
                                .foregroundColor(Color("Primary"))
                        }
                        .font(.system(size: 14, weight: .medium))
                    }
                    .padding()
                    .background(Color("CircleTwo").opacity(0.55))
                    .cornerRadius(20)
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            // Navigation links
            .navigationDestination(isPresented: $goToMain) {
                ORAMainView()
                    .environmentObject(auth)
                    .navigationBarBackButtonHidden()
            }
            .navigationDestination(isPresented: $goToLogin) {
                LoginView()
                    .environmentObject(auth)
                    .navigationBarBackButtonHidden()
            }
        }
    }
    
    // MARK: - Sign up handler
    private func handleSignUp() {
        // Field validations
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            withAnimation { errorMessage = "Please fill in all fields." }
            return
        }
        
        guard isValidEmail(email) else {
            withAnimation { errorMessage = "Invalid email format." }
            return
        }
        
        guard password == confirmPassword else {
            withAnimation { errorMessage = "Passwords do not match." }
            return
        }
        
        guard isStrongPassword(password) else {
            withAnimation { errorMessage = "Password must be at least 6 characters." }
            return
        }
        
        // Clear previous error
        errorMessage = ""
        
        // Sign up via AuthManager
        auth.signUp(username: username, email: email, password: password) { error in
            DispatchQueue.main.async {
                if let error = error {
                    withAnimation {
                        errorMessage = error.localizedDescription
                    }
                } else {
                    goToMain = true
                }
            }
        }
    }
    
    /// Helper: Use regular expressions to ensure that email is in a valid structure
    private func isValidEmail(_ email: String) -> Bool {
        // regex - ensures it follows a standard email strucutre
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }
    
    /// Helper: Ensures password is a "Strong Password" by making sure it's length is greater than 6.
    /// Improvements to be made:
    /// Add stronger checks as only length is not secure
    private func isStrongPassword(_ password: String) -> Bool {
        return password.count >= 6
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SignupView()
            .environmentObject(AuthManager())
    }
}
