//
//  SecondView.swift
//  food_Checker
//
//  Created by Jonas Kilian on 08.05.25.
//


import SwiftUI
import PhotosUI

struct SecondView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var inputImage: UIImage? = nil
    @State private var image: Image? = nil
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false
    @State private var showImagePicker2 = false
    @State private var showCamera2 = false
    @State private var showPickerOptions = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Image picker
                Button {
                    showPickerOptions = true
                } label: {
                    if let image = image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(10)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .frame(width: 200, height: 200)
                            Text("Bild auswählen")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .actionSheet(isPresented: $showPickerOptions) {
                    ActionSheet(
                        title: Text("Bildquelle wählen"),
                        buttons: [
                            .default(Text("Kamera")) {
                                showCamera2 = true
                            },
                            .default(Text("Galerie")) {
                                showImagePicker2 = true
                            },
                            .cancel()
                        ]
                    )
                }
                // Text editor for the response
                // ⭐️ Sternebewertung
                if let rating = extractStarRating(from: responseText) {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .foregroundColor(index <= rating ? .yellow : .gray)
                                .font(.title2)
                        }
                    }
                    .padding(.top)
                }

                // Text editor for the response
                TextEditor(text: $responseText)
                    .frame(height: 150)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal)
                // Send Button
                Button(action: {
                    Task {
                        await submitRequest()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Absenden")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(image == nil || isLoading)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Gericht bewerten")
        }
        
        .sheet(isPresented: $showCamera2) {
            ImagePicker(sourceType: .camera, selectedImage: $inputImage)
                .onDisappear {
                    if let uiImage = inputImage {
                        image = Image(uiImage: uiImage)
                    }
                }
        }
        .sheet(isPresented: $showImagePicker2) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $inputImage)
                .onDisappear {
                    if let uiImage = inputImage {
                        image = Image(uiImage: uiImage)
                    }
                }
        }
    }

    // ⭐️ Sternebewertung extrahieren
    private func extractStarRating(from text: String) -> Int? {
        let pattern = #"([1-5])\s*Sterne"#
        if let match = try? NSRegularExpression(pattern: pattern)
            .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Int(text[range])
        }
        return nil
    }




    // MARK: - Submit Request
    private func submitRequest() async {
        // 1) Thumbnail erzeugen
        guard let uiImage = inputImage,
              let thumb = uiImage.resized(maxDimension: 256),
              let imageData = thumb.jpegData(compressionQuality: 0.4)
        else {
            responseText = "Bitte wähle zuerst ein Bild aus."
            return
        }

        // 2) Data-URL bauen
        let base64 = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"

        // 3) Dictionaries für system- und user-Block
        let systemMessage: [String: Any] = [
            "role": "system",
            "content": "Du bist ein kulinarischer Experte und Restaurantkritiker. Deine Aufgabe ist es, die Qualität eines Gerichts anhand seiner Beschreibung, Zutaten, Zubereitung und sensorischer Eigenschaften (Aussehen, Geruch, Geschmack, Konsistenz) zu bewerten. Gib eine fundierte Einschätzung in klarer, professioneller Sprache mit kurzer Begründung. Gib außerdem eine Sterne Bewertung zwischen 1 und 5 Sternen ab."
        ]
        // Text-Teil
        let textPart: [String: Any] = [
            "type": "text",
            "text": "Bewerte das Essen und gib eine Bewertung zwischen 1 und 5 Sternen"
        ]
        // Bild-Teil
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
            "model": "gpt-4o",
            "max_tokens": 150,
            "messages": [ systemMessage, userMessage ]
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [])
        else {
            responseText = "Fehler beim Erstellen der Anfrage."
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
                let decoded = try JSONDecoder().decode(ChatResponseBody_rate.self, from: data)
                responseText = decoded.choices.first?.message.content
                             ?? "Leere Antwort vom Server."
            case 401:
                responseText = "401 Unauthorized: Ungültiger API-Schlüssel."
            case 429:
                responseText = "429 Rate limit erreicht – bitte später erneut versuchen."
            default:
                let body = String(data: data, encoding: .utf8) ?? "<unlesbar>"
                responseText = "HTTP \(http.statusCode):\n\(body)"
            }
        } catch {
            responseText = "Netzwerk-Fehler: \(error.localizedDescription)"
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