//
//  fresh.swift
//  food_Checker
//
//  Created by Jonas Kilian on 08.05.25.
//

import SwiftUI
import PhotosUI

// MARK: - OpenAI API Models
struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequestBody: Codable {
    let model: String
    let messages: [ChatMessage]
    let max_tokens: Int
    let temperature: Double?
}

struct ChatChoice: Codable {
    let index: Int
    let message: ChatMessage
    let finish_reason: String
}

struct ChatResponseBody: Codable {
    let id: String
    let object: String
    let created: Int
    let choices: [ChatChoice]
    let usage: Usage?
}

struct Usage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}


struct ImageURL: Codable {
    let url: String
    let detail: String?    // "low" "high" "auto"
}

struct ContentPart: Codable {
    let type: String       // "text" oder "image_url"
    let text: String?      // nur für type=="text"
    let image_url: ImageURL?  // nur für type=="image_url"
}





enum OpenAIError: Error {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval)
    case invalidResponse(status: Int, body: String)
    case other(Error)
}




// Debug

let session: URLSession = {
    let cfg = URLSessionConfiguration.default
    cfg.timeoutIntervalForRequest = 30
    cfg.timeoutIntervalForResource = 60
    cfg.waitsForConnectivity = false
    return URLSession(configuration: cfg)
}()





// MARK: - Content Fresh
struct FirstView: View {
    enum PickerSource: String, Identifiable {
        case camera, library
        var id: String { rawValue }
    }

    @State private var pickerSource: PickerSource? = nil
    @State private var inputImage: UIImage? = nil
    @State private var image: Image? = nil
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false
    @State private var showPickerOptions = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
               /* LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.5, green: 0.8, blue: 0.5),
                        Color(red: 0.2, green: 0.3, blue: 0.4)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all) */
                
                ScrollView {
                    VStack(spacing: 20) {
                  
                        Button {
                            showPickerOptions = true
                        } label: {
                            if let image = image {
                                image
                                    .resizable()
                                    .scaledToFit().cornerRadius(8)
                                    .frame(maxWidth: 300, maxHeight: 200)
                                    .cornerRadius(10)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                        .frame(width: 300, height: 200)
                                    Text("Bild auswählen")
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .confirmationDialog("Bildquelle wählen",
                                            isPresented: $showPickerOptions,
                                            titleVisibility: .visible) {
                            Button("Kamera")  { pickerSource = .camera }
                            Button("Galerie") { pickerSource = .library }
                            Button("Abbrechen", role: .cancel) {}
                        }
                                            .sheet(item: $pickerSource) { source in
                                                ImagePicker(
                                                    sourceType: source == .camera ? .camera : .photoLibrary,
                                                    selectedImage: $inputImage
                                                )
                                                .onDisappear {
                                                    if let ui = inputImage {
                                                        image = Image(uiImage: ui)
                                                    }
                                                }
                                            }
                        
                        // Antwortanzeige (nur wenn vorhanden)
                        if !responseText.isEmpty {
                            let editor = TextEditor(text: $responseText)
                                .frame(height: 350)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )

                            editor
                                .transition(.opacity)
                                .animation(.easeInOut, value: responseText)
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 300)
                    }
                    .padding(.top)
                }
                

                Button {
                    Task { await submitRequest() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Absenden")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .disabled(inputImage == nil || isLoading)
                .padding(.bottom, 20)
            }
            .navigationTitle("Essen noch gut")
        }
    }

    // MARK: API anfrage
    private func submitRequest() async {

        guard let uiImage = inputImage,
              let thumb = uiImage.resized(maxDimension: 256),
              let imageData = thumb.jpegData(compressionQuality: 0.4)
        else {
            responseText = "Bitte wähle zuerst ein Bild aus."
            return
        }


        let base64 = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"

        // 3) Dictionaries für system- und user-Block
        let systemMessage: [String: Any] = [
            "role": "system",
            "content": "Du bist ein Experte für Lebensmittelqualität. Deine Aufgabe ist es, Lebensmittel anhand von visuellen Merkmalen wie Farbe, Konsistenz, Frischeanzeichen oder eventuellen Verderbmerkmalen (z. B. Schimmel, Druckstellen) zu bewerten. Gib eine kurze Einschätzung zur Frische und Verzehrbarkeit. Füge 1–2 Kriterien hinzu, die für die Bewertung besonders wichtig sind."
        ]

        let textPart: [String: Any] = [
            "type": "text",
            "text": "Beurteile bitte das Lebensmittel auf dem Bild: Ist es frisch und in gutem Zustand? Ist es noch verzehrbar? Begründe deine Einschätzung kurz."
        ]
        
        let imagePart: [String: Any] = [
            "type": "image_url",
            "image_url": [
                "url": dataURL,
                "detail": "auto"
            ]
        ]
        
        let userMessage: [String: Any] = [
            "role": "user",
            "content": [ textPart, imagePart ]
        ]

    
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 250,
            "messages": [ systemMessage, userMessage ]
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [])
        else {
            responseText = "Fehler Api url"
            return
        }


        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

     
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                responseText = "Kein HTTP-Response"
                return
            }

            switch http.statusCode {
            case 200...299:
                let decoded = try JSONDecoder().decode(ChatResponseBody.self, from: data)
                responseText = decoded.choices.first?.message.content
                             ?? "Leere Antwort vom Server"
            case 401:
                responseText = "falscher API-Schlüssel."
            case 429:
                responseText = "Rate limit erreicht"
            default:
                let body = String(data: data, encoding: .utf8) ?? "<unlesbar>"
                responseText = "HTTP \(http.statusCode):\n\(body)"
            }
        } catch {
            responseText = "Internet: \(error.localizedDescription)"
        }
    }
    // MARK: Bild Laden
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.inputImage = uiImage
                    self.image = Image(uiImage: uiImage)
                }
            }
        }
    }
}



#Preview {
    FirstView()
}

