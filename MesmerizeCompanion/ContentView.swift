//
//  ContentView.swift
//  MesmerizeCompanion
//
//  Created by Garrett Davies on 4/25/26.
//

import SwiftUI

struct ContentView: View {
    @State private var browser = BonjourBrowser()

    // Connection state
    @State private var manualHost = ""
    @State private var manualPort = "8765"
    @State private var connectedService: MesmerizeService?
    @State private var connectionLabel = ""
    @State private var isConnected = false

    // Firefox
    @State private var urlText = "https://www.google.com"
    @State private var selectedMode: MesmerizeService.FirefoxMode = .newTab

    // Feedback
    @State private var statusMessage = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                connectionSection
                if isConnected {
                    firefoxSection
                    mediaSection
                }
            }
            .navigationTitle("Mesmerize")
            .onAppear { browser.startBrowsing() }
            .onDisappear { browser.stopBrowsing() }
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Section {
            if isConnected {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(connectionLabel)
                    Spacer()
                    Button("Disconnect") {
                        disconnect()
                    }
                    .foregroundStyle(.red)
                }
            } else {
                // Discovered services
                if !browser.services.isEmpty {
                    ForEach(browser.services) { svc in
                        Button {
                            connect(host: svc.host, port: svc.port, label: svc.name)
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                VStack(alignment: .leading) {
                                    Text(svc.name).fontWeight(.medium)
                                    Text("\(svc.host):\(svc.port)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else if browser.isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching for Mesmerize services…")
                            .foregroundStyle(.secondary)
                    }
                }

                // Manual entry
                HStack {
                    TextField("Host / IP", text: $manualHost)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Port", text: $manualPort)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                    Button("Connect") {
                        let port = Int(manualPort) ?? 8765
                        connect(host: manualHost, port: port, label: manualHost)
                    }
                    .disabled(manualHost.isEmpty)
                }
            }
        } header: {
            Text("Connection")
        } footer: {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundStyle(statusMessage.starts(with: "Error") ? .red : .secondary)
            }
        }
    }

    // MARK: - Firefox

    private var firefoxSection: some View {
        Section("Firefox") {
            TextField("URL", text: $urlText)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)

            Picker("Mode", selection: $selectedMode) {
                ForEach(MesmerizeService.FirefoxMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode)
                }
            }

            Button {
                sendFirefox()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                    }
                    Label("Open in Firefox", systemImage: "globe")
                }
            }
            .disabled(urlText.isEmpty || isLoading)
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        Section("Media Controls") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                ForEach(MesmerizeService.MediaAction.allCases) { action in
                    Button {
                        sendMedia(action)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.title2)
                            Text(action.label)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Actions

    private func connect(host: String, port: Int, label: String) {
        let service = MesmerizeService(host: host, port: port)
        isLoading = true
        statusMessage = ""

        Task {
            do {
                let response = try await service.healthCheck()
                connectedService = service
                connectionLabel = "\(label) (\(host):\(port))"
                isConnected = true
                statusMessage = "Connected – \(response)"
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func disconnect() {
        connectedService = nil
        isConnected = false
        connectionLabel = ""
        statusMessage = ""
    }

    private func sendFirefox() {
        guard let service = connectedService else { return }
        isLoading = true
        statusMessage = ""

        Task {
            do {
                let response = try await service.openFirefox(mode: selectedMode, url: urlText)
                statusMessage = response
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func sendMedia(_ action: MesmerizeService.MediaAction) {
        guard let service = connectedService else { return }
        isLoading = true
        statusMessage = ""

        Task {
            do {
                let response = try await service.sendMediaAction(action)
                statusMessage = response
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
