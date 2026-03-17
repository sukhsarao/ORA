//
//  LoginView.swift
//  ORA
//
//  Created by Sukhman Singh on 19/9/2025.
//

import SwiftUI

// MARK: - LoginView
/// Displays a login screen with username/password fields, a login button,
/// and navigation links to the main app view or the signup screen.
struct LoginView: View {
    
    // MARK: Environment
    @EnvironmentObject var auth: AuthManager
    
    // MARK: State
    @State private var username = ""
    @State private var password = ""
    @State private var goToMain = false      // Navigate to main app on successful login
    @State private var goToSignUp = false   // Navigate to signup screen
    @State private var errorMessage = ""    // Shows login errors
    
    // MARK: Body
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: Background
                Color("Background").ignoresSafeArea()
                
                CoffeeLayout {
                    RadialCircle(size: 300, colors: [Color("CircleOne"), Color("CircleTwo")])
                    RadialCircle(size: 200, colors: [Color("CircleOne"), Color("CircleTwo")])
                }
                
                VStack {
                    // MARK: Header / Logo
                    HStack {
                        Text("ORA")
                            .font(Font.custom("Skranji-Bold", size: 40))
                            .foregroundColor(Color("Primary"))
                            .padding(.leading)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // MARK: Form Card
                    VStack(spacing: 20) {
                        Text("Login")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        // Welcome text
                        HStack(spacing: 4) {
                            Text("Welcome to")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Color("Primary"))
                            Text("ORA")
                                .font(Font.custom("Skranji-Bold", size: 18))
                                .foregroundColor(Color("Primary"))
                        }
                        
                        // MARK: Username & Password Fields
                        VStack(alignment: .leading, spacing: 15) {
                            // Username
                            Text("Username")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color("Primary"))
                            TextField("Enter your username", text: $username)
                                .padding()
                                .background(AppColor.primary.opacity(0.2))
                                .cornerRadius(15)
                                .tint(Color("Primary"))
                            
                            // Password
                            Text("Password")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color("Primary"))
                            SecureField("Enter your password", text: $password)
                                .padding()
                                .background(AppColor.primary.opacity(0.2))
                                .cornerRadius(15)
                                .tint(Color("Primary"))
                        }
                        
                        // MARK: Login Button
                        Button(action: {
                            guard !username.isEmpty, !password.isEmpty else {
                                withAnimation { errorMessage = "Please enter both username and password." }
                                return
                            }
                            
                            auth.login(username: username, password: password) { error in
                                withAnimation {
                                    if error != nil {
                                        errorMessage = "Incorrect username or password. Please try again."
                                    } else {
                                        errorMessage = ""
                                        goToMain = true
                                    }
                                }
                            }
                        }) {
                            Text("Login")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("Primary"))
                                .cornerRadius(25)
                        }
                        .padding(.top, 8)

                        // MARK: Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                                .transition(.opacity)
                        }

                        // MARK: Signup Navigation
                        HStack {
                            Text("No account?")
                            Button("Sign up") {
                                goToSignUp = true
                            }
                            .foregroundColor(Color("Primary"))
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .padding()
                    .background(Color("CircleTwo").opacity(0.45))
                    .cornerRadius(20)
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            // MARK: Navigation
            .navigationDestination(isPresented: $goToMain) {
                ORAMainView()
                    .environmentObject(auth)
                    .navigationBarBackButtonHidden()
            }
            .navigationDestination(isPresented: $goToSignUp) {
                SignupView()
                    .environmentObject(auth)
                    .navigationBarBackButtonHidden()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
