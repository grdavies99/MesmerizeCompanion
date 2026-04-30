//
//  ContentView.swift
//  MesmerizeCompanion
//
//  Created by Garrett Davies on 4/25/26.
//

import SwiftUI

struct ContentView: View {
    @State private var browser = BonjourBrowser()
    @State private var observer = MediaStateObserver()

    // Connection state
    @State private var manualHost = ""
    @State private var manualPort = "8765"
    @State private var connectedService: MesmerizeService?
    @State private var connectionLabel = ""
    @State private var isConnected = false

    // Firefox
    @State private var urlText = "https://www.google.com"
    @State private var selectedMode: MesmerizeService.FirefoxMode = .newTab

    // Skip-to-position
    @State private var skipPositionText = ""

    // Seek
    @State private var seekSeconds: Double = 10

    // Volume
    @State private var volumeLevel: Double = 0.5

    // Settings
    @AppStorage("mediaControlsEnabled") private var mediaControlsEnabled = true
    @AppStorage("liveStreamEnabled") private var liveStreamEnabled = true

    // Feedback
    @State private var statusMessage = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                connectionSection
                if isConnected {
                    settingsSection
                    if liveStreamEnabled {
                        nowPlayingSection
                    }
                    firefoxSection
                    if mediaControlsEnabled {
                        mediaSection
                    }
                }
            }
            .navigationTitle("Mesmerize")
            .onAppear { browser.startBrowsing() }
            .onDisappear {
                browser.stopBrowsing()
                observer.disconnect()
            }
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
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isLoading)
                    }
                } else if browser.isSearching {
                    HStack {
                        ProgressView()
                        Text("Scanning for services…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(.secondary)
                        Text("No services found")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    browser.stopBrowsing()
                    browser.startBrowsing()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(browser.isSearching)

                // Manual entry fallback
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
                    .disabled(manualHost.isEmpty || isLoading)
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

    // MARK: - Settings

    private var settingsSection: some View {
        Section("Settings") {
            Toggle("Media Controls", isOn: $mediaControlsEnabled)
            Toggle("Live Playback Stream", isOn: $liveStreamEnabled)
                .onChange(of: liveStreamEnabled) { _, enabled in
                    if enabled {
                        if let service = connectedService {
                            observer.connect(to: service.baseURL)
                        }
                    } else {
                        observer.disconnect()
                    }
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

    // MARK: - Now Playing

    private var nowPlayingSection: some View {
        Section("Now Playing") {
            if observer.isConnected {
                // Position display
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                    Text("Position")
                    Spacer()
                    Text(formattedTime(observer.state.position))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                // Live volume display
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.secondary)
                    Text("Volume")
                    Spacer()
                    Text("\(Int(observer.state.volume * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    ProgressView()
                    Text("Connecting to stream…")
                        .foregroundStyle(.secondary)
                }
            }
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

            // Skip to position
            HStack {
                TextField("Seconds (e.g. 90.5)", text: $skipPositionText)
                    .keyboardType(.decimalPad)
                Button {
                    sendSkip()
                } label: {
                    Label("Skip to", systemImage: "arrow.right.to.line")
                }
                .disabled(Double(skipPositionText) == nil || isLoading)
            }

            // Seek forward/backward
            VStack(alignment: .leading, spacing: 8) {
                Text("Seek: \(Int(seekSeconds))s")
                    .font(.subheadline)
                Slider(value: $seekSeconds, in: 5...120, step: 5)
                HStack {
                    Button {
                        sendSeek(offset: -seekSeconds)
                    } label: {
                        Label("\(Int(seekSeconds))s", systemImage: "gobackward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    Button {
                        sendSeek(offset: seekSeconds)
                    } label: {
                        Label("\(Int(seekSeconds))s", systemImage: "goforward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
            }
            .padding(.vertical, 4)

            // Volume
            VStack(alignment: .leading, spacing: 8) {
                Text("Volume: \(Int(volumeLevel * 100))%")
                    .font(.subheadline)
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: $volumeLevel, in: 0...1, step: 0.05)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
                Button {
                    sendVolume()
                } label: {
                    Label("Set Volume", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
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
                if liveStreamEnabled {
                    observer.connect(to: service.baseURL)
                }
                statusMessage = "Connected – \(response)"
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func disconnect() {
        observer.disconnect()
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

    private func sendSkip() {
        guard let service = connectedService,
              let position = Double(skipPositionText) else { return }
        isLoading = true
        statusMessage = ""

        Task {
            do {
                let response = try await service.skipToPosition(position)
                statusMessage = response
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func sendSeek(offset: Double) {
        guard let service = connectedService else { return }
        isLoading = true
        statusMessage = ""

        Task {
            do {
                let response = try await service.seek(offset: offset)
                statusMessage = response
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func sendVolume() {
        guard let service = connectedService else { return }
        isLoading = true
        statusMessage = ""

        Task {
            do {
                let response = try await service.setVolume(level: volumeLevel)
                statusMessage = response
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    // MARK: - Helpers

    private func formattedTime(_ totalSeconds: Double) -> String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
