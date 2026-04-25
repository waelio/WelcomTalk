//
//  ContentView.swift
//  WelcomTalk
//
//  Created by waelio on 07/03/2026.
//

import SwiftUI      

struct ContentView: View {
    @State private var showingCreateSession = false
    @State private var showingJoinSession = false
    @State private var showingDemoSession = false
    @State private var showingMessagingSettings = false
    @StateObject private var demoViewModel = SessionViewModel()

    private var websiteStartURL: URL {
        URL(string: "https://welcomesit.netlify.app/")!
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "scale.3d")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    VStack(spacing: 10) {
                        Text("Equal Time for Every Voice")
                            .font(.title)
                            .bold()

                        Text("WelcomTalk is a fairness-first conversation app. One person speaks at a time, each participant gets the same timed turn, and the app stays neutral while everyone presents their side.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Equal timed turns by default", systemImage: "timer")
                        Label("Neutral structure without interruptions", systemImage: "arrow.left.arrow.right.circle")
                        Label("Notes, logs, and follow-up in one place", systemImage: "doc.text")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                    VStack(spacing: 15) {
                        Button {
                            showingCreateSession = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Start Fair Conversation")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start Fair Conversation")

                        Button {
                            showingJoinSession = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Join Equal-Time Session")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Join Equal-Time Session")

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Start from the website")
                                .font(.headline)

                            Text("Anyone can begin on the website, create the JSON request record, and then continue in the app.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)

                            Link(destination: websiteStartURL) {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Open Website JSON Builder")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.18))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                            }
                            .accessibilityLabel("Open Website JSON Builder")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(16)

                        Divider()
                            .padding(.vertical, 10)

                        Button {
                            showingDemoSession = true
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Try Fairness Demo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Try Fairness Demo")
                    }
                    .padding(.horizontal, 40)

                    Text("Current live session engine supports two participants today, while the broader product direction stays open to bigger moderated formats later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)

                    VStack(spacing: 8) {
                        HStack(spacing: 20) {
                            FeatureLabel(icon: "scale.3d", text: "Equal Turns", color: .blue)
                            FeatureLabel(icon: "note.text", text: "Private Notes", color: .orange)
                            FeatureLabel(icon: "list.bullet", text: "Session Log", color: .purple)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("WelcomTalk")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingMessagingSettings = true
                    } label: {
                        Image(systemName: "network")
                    }
                    .accessibilityLabel("network")
                    .tint(.blue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: appShareMessage) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
            }
            .sheet(isPresented: $showingCreateSession) {
                CreateSessionView()
            }
            .sheet(isPresented: $showingJoinSession) {
                JoinSessionView()
            }
            .sheet(isPresented: $showingMessagingSettings) {
                MessagingServerSettingsView()
            }
            .fullScreenCover(isPresented: $showingDemoSession) {
                NavigationStack {
                    SessionView(sessionViewModel: demoViewModel)
                }
            }
        }
    }

    private var appShareMessage: String {
        "Try WelcomTalk - Equal Time for Every Voice\n\nWelcomTalk helps people present their side fairly with equal timed turns, one speaker at a time, and a neutral structure that reduces interruptions.\n\nStart from the website to generate the JSON request record:\nhttps://welcomesit.netlify.app/\n\nThen continue in the app to start or join the conversation."
    }
}

struct FeatureLabel: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
