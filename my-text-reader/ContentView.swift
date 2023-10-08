//
//  ContentView.swift
//  My Text Reader
//
//  Created by Murat Dinç on 26.09.2023.
//  DivWizard - divwizard.com
//

import SwiftUI
import AVFoundation

// This class manages the tab information that the user selects.
class TabSelectionViewModel: ObservableObject {
    // The selectedTab property to store the currently selected tab index.
    @Published var selectedTab: Int {
        didSet {
            // When selectedTab changes, we save its value in UserDefaults with the key "SelectedTab".
            UserDefaults.standard.set(selectedTab, forKey: "SelectedTab")
        }
    }
    
    // When initializing, we retrieve the previously stored selectedTab value from UserDefaults.
    init() {
        self.selectedTab = UserDefaults.standard.integer(forKey: "SelectedTab")
    }
}

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var selectedLanguageIndex = 0 // Sequence number of the default language
    @Published var speechRate = 1.0 // Set speed (1.0 default speed)

    private var synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self

        //  Load saved settings from UserDefaults
        if let savedSpeechRate = UserDefaults.standard.value(forKey: "SpeechRate") as? Double {
            speechRate = savedSpeechRate
        }

        if let savedLanguageIndex = UserDefaults.standard.value(forKey: "SelectedLanguageIndex") as? Int {
            selectedLanguageIndex = savedLanguageIndex
        }
    }

    // Store settings and read text when reading starts
    func speakText(_ text: String) {
        UserDefaults.standard.set(speechRate, forKey: "SpeechRate")
        UserDefaults.standard.set(selectedLanguageIndex, forKey: "SelectedLanguageIndex")
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: supportedLanguages[selectedLanguageIndex])
        utterance.rate = Float(AVSpeechUtteranceDefaultSpeechRate) * Float(speechRate) // Set speed by user
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    // List of supported languages
    let supportedLanguages = [
        "US", "TR", "FR", "DE", "ES", "IT", "NL", "RU", "JP", "KR", "BR", "SE", "CN"
    ]
    
    func stopSpeech() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    // Function called when the read operation is complete
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

class SystemSpeechManager: ObservableObject {
    @Published var isReading = false
    @Published var SystemSpeechRate = UserDefaults.standard.double(forKey: "SystemSpeechRate")
    @Published var selectedVoice = UserDefaults.standard.string(forKey: "selectedVoice") ?? "Default"

    init() {
        // Load saved settings from UserDefaults
        if let savedVoice = UserDefaults.standard.string(forKey: "selectedVoice") {
            selectedVoice = savedVoice
        }
        if let SystemSavedSpeechRate = UserDefaults.standard.object(forKey: "SystemSpeechRate") as? Double {
            SystemSpeechRate = SystemSavedSpeechRate
        }
    }
    
    // Computed property to check if the selected voice is "Default"
    var isDefaultVoiceSelected: Bool {
        return selectedVoice == "Default"
    }

    func startReading(_ text: String) {
        // Save settings to UserDefaults when reading starts
        UserDefaults.standard.set(selectedVoice, forKey: "selectedVoice")
        UserDefaults.standard.set(SystemSpeechRate, forKey: "SystemSpeechRate")

        let quotedText = "\"\(text)\""
        var command = "say -r \(Int(SystemSpeechRate))"

        // Conditionally include the -v option if a non-default voice is selected
        if !isDefaultVoiceSelected {
            command += " -v \(selectedVoice)"
        }

        command += " \(quotedText)" // Set reading speed and voiceover language

        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        process.launch()
        isReading = true // Reading started

        // Update status when the operation is complete
        process.terminationHandler = { _ in
            self.isReading = false
        }
    }

    func stopReading() {
        // End active process
        if isReading {
            let process = Process()
            process.launchPath = "/usr/bin/killall"
            process.arguments = ["say"]
            process.launch()
        }
        isReading = false
    }
}

struct ContentView: View {
    @StateObject private var tabSelection = TabSelectionViewModel()
    @State private var isMenuOpen = false // Keeps track of whether the menu is open or closed

    var body: some View {
        VStack {

            TabView(selection: $tabSelection.selectedTab) {
                AVFoundationView()
                    .tabItem {
                        Label("AVFoundation", systemImage: "speaker.wave.2.fill")
                    }
                    .tag(0)
                System()
                    .tabItem {
                        Label("System", systemImage: "terminal.fill")
                    }
                    .tag(1)
                Siri()
                    .tabItem {
                        Label("Siri", systemImage: "mic.fill")
                    }
                    .tag(2)
            }
            .padding()
            
        }
    }
}

struct AVFoundationView: View {
    @State private var textToSpeak = ""
    @ObservedObject private var speechManager = SpeechManager()
    
    var body: some View {
        VStack {
            TextEditor(text: $textToSpeak)
                .padding()
                .border(Color.gray, width: 1)
                .cornerRadius(8)
                .font(.system(size: 16))
                .lineSpacing(5)
                .overlay(
                    Text("Text Field to Read").opacity(textToSpeak.isEmpty ? 1 : 0)
                    .foregroundColor(.gray)
                )
            
            Picker("Select Language:", selection: $speechManager.selectedLanguageIndex) {
                ForEach(0..<speechManager.supportedLanguages.count, id: \.self) { index in
                    Text(speechManager.supportedLanguages[index])
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.top, 15)

            Slider(value: $speechManager.speechRate, in: 0.5...1.75, step: 0.05) {
                Text("Reading Speed: \(String(format: "%.2f", speechManager.speechRate))x")
            }
            .padding(.top, 10)

            HStack {
                
                ShareLink("Share", item: URL(string: "https://github.com/muratdincmd/my-text-reader")!)
                
                Spacer()
                
                Button(action: {
                    if speechManager.isSpeaking {
                        speechManager.stopSpeech()
                    } else {
                        speechManager.speakText(textToSpeak)
                    }
                }) {
                    Text(speechManager.isSpeaking ? "Stop Reading" : "Read Text")
                        .foregroundColor(speechManager.isSpeaking ? Color.red : Color.primary)
                        .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                }
                .disabled(textToSpeak.isEmpty)
                
                Spacer()
                
                HStack {
                    Text("Created by")
                    Spacer().frame(width: 5)
                    Link("DivWizard", destination: URL(string: "https://divwizard.com/")!)
                }

            }
            .padding(.top, 15)
        }
        .padding()
    }
}
    
struct System: View {
    @State private var enteredText = ""
    @ObservedObject private var systemSpeechManager = SystemSpeechManager()
    @State private var selectedVoice = "Voiceover Language" // Default Menu Text

    var body: some View {
        VStack {
            TextEditor(text: $enteredText)
                .padding()
                .border(Color.gray, width: 1)
                .cornerRadius(8)
                .font(.system(size: 16))
                .lineSpacing(5)
                .overlay(
                    Text("Text Field to Read").opacity(enteredText.isEmpty ? 1 : 0)
                        .foregroundColor(.gray)
                )
            
            HStack {
                Menu(systemSpeechManager.selectedVoice) {
                    Button("Default") {
                        systemSpeechManager.selectedVoice = "Default"
                    }
                    Button("Albert [en_US]") {
                        systemSpeechManager.selectedVoice = "Albert"
                    }
                    Button("Alice [it_IT]") {
                        systemSpeechManager.selectedVoice = "Alice"
                    }
                    Button("Alva [sv_SE]") {
                        systemSpeechManager.selectedVoice = "Alva"
                    }
                    Button("Amélie [fr_CA]") {
                        systemSpeechManager.selectedVoice = "Amélie"
                    }
                    Button("Amira [ms_MY]") {
                        systemSpeechManager.selectedVoice = "Amira"
                    }
                    Button("Anna [de_DE]") {
                        systemSpeechManager.selectedVoice = "Anna"
                    }
                    Button("Bad News [en_US]") {
                        systemSpeechManager.selectedVoice = "Bad News"
                    }
                    Button("Bahh [en_US]") {
                        systemSpeechManager.selectedVoice = "Bahh"
                    }
                    Button("Bells [en_US]") {
                        systemSpeechManager.selectedVoice = "Bells"
                    }
                    Button("Boing [en_US]") {
                        systemSpeechManager.selectedVoice = "Boing"
                    }
                    Button("Bubbles [en_US]") {
                        systemSpeechManager.selectedVoice = "Bubbles"
                    }
                    Button("Carmit [he_IL]") {
                        systemSpeechManager.selectedVoice = "Carmit"
                    }
                    Button("Cellos [en_US]") {
                        systemSpeechManager.selectedVoice = "Cellos"
                    }
                    Button("Damayanti [id_ID]") {
                        systemSpeechManager.selectedVoice = "Damayanti"
                    }
                    Button("Daniel [en_GB]") {
                        systemSpeechManager.selectedVoice = "Daniel"
                    }
                    Button("Daria [bg_BG]") {
                        systemSpeechManager.selectedVoice = "Daria"
                    }
                    Button("Wobble [en_US]") {
                        systemSpeechManager.selectedVoice = "Wobble"
                    }
                    Button("Ellen [nl_BE]") {
                        systemSpeechManager.selectedVoice = "Ellen"
                    }
                    Button("Fred [en_US]") {
                        systemSpeechManager.selectedVoice = "Fred"
                    }
                    Button("Good News [en_US]") {
                        systemSpeechManager.selectedVoice = "Good News"
                    }
                    Button("Jester [en_US]") {
                        systemSpeechManager.selectedVoice = "Jester"
                    }
                    Button("Ioana [ro_RO]") {
                        systemSpeechManager.selectedVoice = "Ioana"
                    }
                    Button("Jacques[fr_FR]") {
                        systemSpeechManager.selectedVoice = "Jacques"
                    }
                    Button("Joana [pt_PT]") {
                        systemSpeechManager.selectedVoice = "Joana"
                    }
                    Button("Junior [en_US]") {
                        systemSpeechManager.selectedVoice = "Junior"
                    }
                    Button("Kanya [th_TH]") {
                        systemSpeechManager.selectedVoice = "Kanya"
                    }
                    Button("Karen [en_AU]") {
                        systemSpeechManager.selectedVoice = "Karen"
                    }
                    Button("Kathy [en_US]") {
                        systemSpeechManager.selectedVoice = "Kathy"
                    }
                    Button("Kyoko [ja_JP]") {
                        systemSpeechManager.selectedVoice = "Kyoko"
                    }
                    Button("Lana [hr_HR]") {
                        systemSpeechManager.selectedVoice = "Lana"
                    }
                    Button("Laura [sk_SK]") {
                        systemSpeechManager.selectedVoice = "Laura"
                    }
                    Button("Lekha [hi_IN]") {
                        systemSpeechManager.selectedVoice = "Lekha"
                    }
                    Button("Lesya [uk_UA]") {
                        systemSpeechManager.selectedVoice = "Lesya"
                    }
                    Button("Linh [vi_VN]") {
                        systemSpeechManager.selectedVoice = "Linh"
                    }
                    Button("Luciana [pt_BR]") {
                        systemSpeechManager.selectedVoice = "Luciana"
                    }
                    Button("Majed [ar_00]") {
                        systemSpeechManager.selectedVoice = "Majed"
                    }
                    Button("Tünde [hu_HU]") {
                        systemSpeechManager.selectedVoice = "Tünde"
                    }
                    Button("Meijia [zh_TW]") {
                        systemSpeechManager.selectedVoice = "Meijia"
                    }
                    Button("Melina [el_GR]") {
                        systemSpeechManager.selectedVoice = "Melina"
                    }
                    Button("Milena [ru_RU]") {
                        systemSpeechManager.selectedVoice = "Milena"
                    }
                    Button("Moira [en_IE]") {
                        systemSpeechManager.selectedVoice = "Moira"
                    }
                    Button("Mónica [es_ES]") {
                        systemSpeechManager.selectedVoice = "Mónica"
                    }
                    Button("Montse [ca_ES]") {
                        systemSpeechManager.selectedVoice = "Montse"
                    }
                    Button("Nora [nb_NO]") {
                        systemSpeechManager.selectedVoice = "Nora"
                    }
                    Button("Organ [en_US]") {
                        systemSpeechManager.selectedVoice = "Organ"
                    }
                    Button("Paulina [es_MX]") {
                        systemSpeechManager.selectedVoice = "Paulina"
                    }
                    Button("Superstar [en_US]") {
                        systemSpeechManager.selectedVoice = "Superstar"
                    }
                    Button("Ralph [en_US]") {
                        systemSpeechManager.selectedVoice = "Ralph"
                    }
                    Button("Rishi [en_IN]") {
                        systemSpeechManager.selectedVoice = "Rishi"
                    }
                    Button("Samantha [en_US]") {
                        systemSpeechManager.selectedVoice = "Samantha"
                    }
                    Button("Sara [da_DK]") {
                        systemSpeechManager.selectedVoice = "Sara"
                    }
                    Button("Satu [fi_FI]") {
                        systemSpeechManager.selectedVoice = "Satu"
                    }
                    Button("Sinji [zh_HK]") {
                        systemSpeechManager.selectedVoice = "Sinji"
                    }
                    Button("Tessa [en_ZA]") {
                        systemSpeechManager.selectedVoice = "Tessa"
                    }
                    Button("Thomas [fr_FR]") {
                        systemSpeechManager.selectedVoice = "Thomas"
                    }
                    Button("Tingting [zh_CN]") {
                        systemSpeechManager.selectedVoice = "Tingting"
                    }
                    Button("Trinoids [en_US]") {
                        systemSpeechManager.selectedVoice = "Trinoids"
                    }
                    Button("Whisper [en_US]") {
                        systemSpeechManager.selectedVoice = "Whisper"
                    }
                    Button("Xander [nl_NL]") {
                        systemSpeechManager.selectedVoice = "Xander"
                    }
                    Button("Yelda [tr_TR]") {
                        systemSpeechManager.selectedVoice = "Yelda"
                    }
                    Button("Yuna [ko_KR]") {
                        systemSpeechManager.selectedVoice = "Yuna"
                    }
                    Button("Zarvox [en_US]") {
                        systemSpeechManager.selectedVoice = "Zarvox"
                    }
                    Button("Zosia [pl_PL]") {
                        systemSpeechManager.selectedVoice = "Zosia"
                    }
                    Button("Zuzana [cs_CZ]") {
                        systemSpeechManager.selectedVoice = "Zuzana"
                    }
                }
                .padding(.trailing, 10)
                .frame(maxWidth: 200)
                
                Slider(value: $systemSpeechManager.SystemSpeechRate, in: 150...300, step: 10) {
                    Text("Reading Speed: \(Int(systemSpeechManager.SystemSpeechRate))")
                }
            }
            .padding(EdgeInsets(top: 18, leading: 0, bottom: 18, trailing: 0))

            HStack {
                ShareLink("Share", item: URL(string: "https://github.com/muratdincmd/my-text-reader")!)

                Spacer()

                Button(action: {
                  if systemSpeechManager.isReading {
                      systemSpeechManager.stopReading()
                  } else {
                      systemSpeechManager.startReading(enteredText)
                  }
                }) {
                    Text(systemSpeechManager.isReading ? "Stop Reading" : "Read Text")
                    .foregroundColor(systemSpeechManager.isReading ? Color.red : Color.primary)
                    .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                }
                .disabled(enteredText.isEmpty)

                Spacer()

                HStack {
                    Text("Created by")
                    Spacer().frame(width: 5)
                    Link("DivWizard", destination: URL(string: "https://divwizard.com/")!)
                }
            }
        }
        .padding()
    }
}

struct Siri: View {
    var body: some View {
        Text("Maybe Later")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
