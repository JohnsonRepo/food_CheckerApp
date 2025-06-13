//
//  rate.swift.swift
//  food_Checker
//
//  Created by Jonas Kilian on 08.05.25.
//

import SwiftUI
import PhotosUI

// MARK: - OpenAI API Models
struct ChatMessage_rate: Codable {
    let role: String
    let content: String
}

struct ChatRequestBody_rate: Codable {
    let model: String
    let messages: [ChatMessage_rate]
    let max_tokens: Int
    let temperature: Double?
}

struct ChatChoice_rate: Codable {
    let index: Int
    let message: ChatMessage_rate
    let finish_reason: String
}

struct ChatResponseBody_rate: Codable {
    let id: String
    let object: String
    let created: Int
    let choices: [ChatChoice_rate]
    let usage: Usage_rate?
}

struct Usage_rate: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

struct ImageURL_rate: Codable {
    let url: String
    let detail: String?
}

struct ContentPart_rate: Codable {
    let type: String
    let text: String?
    let image_url: ImageURL_rate?
}

// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.presentationMode) private var presentationMode
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Rate View
struct SecondView: View {
    enum PickerSource: String, Identifiable {
        case camera, library
        var id: String { rawValue }
    }

    @State private var pickerSource: PickerSource? = nil
    @State private var inputImage: UIImage? = nil
    @State private var image: Image? = nil
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false
    @State private var showPickerOptions: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: Image Picker
                    Button {
                        showPickerOptions = true
                    } label: {
                        if let image = image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(16)
                                .shadow(radius: 5)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    .frame(height: 220)
                                    .foregroundColor(.gray.opacity(0.3))
                                
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Bild auswählen")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .confirmationDialog("Bildquelle wählen", isPresented: $showPickerOptions, titleVisibility: .visible) {
                        Button("Kamera") { pickerSource = .camera }
                        Button("Galerie") { pickerSource = .library }
                        Button("Abbrechen", role: .cancel) {}
                    }
                    .sheet(item: $pickerSource) { source in
                        ImagePicker(
                            sourceType: source == .camera ? .camera : .photoLibrary,
                            selectedImage: $inputImage
                        )
                        .onDisappear {
                            if let uiImage = inputImage {
                                image = Image(uiImage: uiImage)
                            }
                        }
                    }

                    // MARK: Bewertung
                    let parsed = parseResponse(responseText)
                    
                    if let rating = parsed.rating {
                        VStack {
                            HStack(spacing: 6) {
                                ForEach(1...5, id: \.self) { idx in
                                    Image(systemName: "star.fill")
                                        .foregroundColor(idx <= rating ? .yellow : .gray)
                                        .font(.title2)
                                }
                            }
                            .padding(.bottom, 6)
                            
                            Text("\(rating) von 5")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // MARK: Kommentaranzeige
                    if !parsed.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Analyse")
                                .font(.headline)
                            
                            ScrollView {
                                Text(parsed.comment)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(minHeight: 100, maxHeight: 250)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }

                    // MARK: Submit Button
                    Button(action: {
                        Task { await submitRequest() }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Absenden")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(inputImage == nil || isLoading ? Color.gray.opacity(0.4) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(inputImage == nil || isLoading)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Gericht bewerten")
        }
    }

    private func parseResponse(_ text: String) -> (rating: Int?, comment: String) {
        let pattern = #"([1-5])\s*Sterne"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (nil, text.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let fullRange = NSRange(text.startIndex..., in: text)
        
        // Extract rating
        var rating: Int? = nil
        if let match = regex.firstMatch(in: text, range: fullRange),
           let range = Range(match.range(at: 1), in: text) {
            rating = Int(text[range])
        }
        
        // Clean response 
        let cleanedComment = regex.stringByReplacingMatches(in: text, range: fullRange, withTemplate: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (rating, cleanedComment)
    }
    // MARK: - Submit Request
    private func submitRequest() async {
        guard let uiImage = inputImage,
              let thumb = uiImage.resized(maxDimension: 256),
              let imageData = thumb.jpegData(compressionQuality: 0.4) else {
            responseText = "Bitte wähle zuerst ein Bild aus."
            return
        }
        let base64 = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"

        let systemMessage: [String: Any] = [
            "role": "system",
            "content": """
        Du bist ein kulinarischer Experte und Restaurantkritiker. \
        Bewerte ein Gericht anhand seiner Beschreibung, Zutaten, Zubereitung und sensorischer Eigenschaften \
        (Aussehen, Geruch, Geschmack, Konsistenz). \
        Formuliere eine kurze, professionelle Einschätzung. \
        Gib konkrete Verbesserungsvorschläge. \
        Am Ende deiner Antwort steht ausschließlich die Bewertung im Format „X Sterne“ (z. B. „4 Sterne“). \
        Verwende das Wort „Sterne“ **nur** in dieser Bewertung, nicht im restlichen Text. Begrenze deine Antwort auf 500 Zeichen
        """
        ]
        let textPart: [String: Any] = ["type": "text", "text": "Bewerte das Essen und gib eine Bewertung ab."]
        let imagePart: [String: Any] = [
            "type": "image_url",
            "image_url": ["url": dataURL, "detail": "auto"]
        ]
        let userMessage: [String: Any] = ["role": "user", "content": [textPart, imagePart]]
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 450,
            "messages": [systemMessage, userMessage]
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            responseText = "Fehler beim Erstellen der Anfrage."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
            case 200..<300:
                let decoded = try JSONDecoder().decode(ChatResponseBody_rate.self, from: data)
                responseText = decoded.choices.first?.message.content ?? "Leere Antwort vom Server."
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
}

#Preview {
    SecondView()
}
