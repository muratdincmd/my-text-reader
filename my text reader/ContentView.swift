//
//  ContentView.swift
//  My Text Reader
//
//  Created by Murat Dinç on 26.09.2023.
//  DivWizard - divwizard.com
//


import SwiftUI
import AVFoundation

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var selectedLanguageIndex = 0
    @Published var speechRate = 1.0 // Set speed (1.0 default speed)

    private var synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: supportedLanguages[selectedLanguageIndex])
        utterance.rate = Float(AVSpeechUtteranceDefaultSpeechRate) * Float(speechRate) // Set speed by user
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stopSpeech() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    let supportedLanguages = [
        "US", "TR", "FR", "DE", "ES", "IT", "NL", "RU", "JP", "KR", "BR", "SE", "CN"
    ]
}

struct ContentView: View {
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
                }
                
                Spacer()
                
                Text("Created by")
                Link("DivWizard", destination: URL(string: "https://divwizard.com/")!)
                
            }
            .padding(.top, 15)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
