import SwiftUI
import MobileCoreServices

struct MemeData: Codable {
    let data: MemeResponse
}

struct MemeResponse: Codable {
    let memes: [Meme]
}

struct Meme: Codable, Identifiable {
    let id: String
    let name: String
    let url: String
    let width: Int
    let height: Int
    let boxCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, url, width, height
        case boxCount = "box_count"
    }
}

struct ContentView: View {
    @State private var memes: [Meme] = []
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(memes) { meme in
                        NavigationLink(destination: DetailView(meme: meme)) {
                            if let imageUrl = URL(string: meme.url), let imageData = try? Data(contentsOf: imageUrl), let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(10)
                                    .padding(2)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("MimGenerator")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await fetchData()
                memes.shuffle() // Shuffle the memes array after fetching data
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.isRefreshing = false
                }
            }
        }
        .onAppear {
            Task {
                await fetchData()
            }
        }
    }
    
    func fetchData() async {
        if let url = URL(string: "https://api.imgflip.com/get_memes") {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decodedResponse = try JSONDecoder().decode(MemeData.self, from: data)
                self.memes = decodedResponse.data.memes
            } catch {
                print("Error fetching data: \(error)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
struct DetailView: View {
    let meme: Meme
    @State private var showingActionSheet = false
    @State private var selectedAction: ActionItem?
    @State private var logoImage: UIImage?
    @State private var textToAdd: String = ""
    @State private var memeImage: UIImage? // Added state for meme image
    
    enum ActionItem: Int, Identifiable {
        case addLogo, addText, save, share
        
        var id: Int { self.rawValue }
    }
    
    var body: some View {
        VStack {
            if let uiImage = memeImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }
            Text(meme.name)
                .font(.title)
                .padding()
        }
        .navigationTitle("Meme Generator")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(title: Text("Add to Image"), buttons: [
                .default(Text("Add Logo"), action: {
                    selectedAction = .addLogo
                }),
                .default(Text("Add Text"), action: {
                    selectedAction = .addText
                }),
                .default(Text("Save"), action: {
                    selectedAction = .save
                }),
                .default(Text("Share"), action: {
                    selectedAction = .share
                }),
                .cancel()
            ])
        }
        .sheet(item: $selectedAction) { actionItem in
            switch actionItem {
            case .addLogo:
                ImagePicker(sourceType: .photoLibrary) { image in
                    if let image = image {
                        self.logoImage = image
                        self.placeLogoOnMeme()
                    }
                }
            case .addText:
                TextEditor(text: $textToAdd)
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                self.addTextToMeme()
                            }
                        }
                    }
            case .save:
                // Return an empty Text view
                Text("")
                    .onAppear {
                        if let memeImage = memeImage {
                            UIImageWriteToSavedPhotosAlbum(memeImage, nil, nil, nil)
                        }
                    }
            case .share:
                // Return an empty Text view
                Text("")
                    .onAppear {
                        if let memeImage = memeImage {
                            let activityViewController = UIActivityViewController(activityItems: [memeImage], applicationActivities: nil)
                            UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
                        }
                    }
            }
        }
        .onAppear {
            // Fetch and display the meme image on appearance
            fetchMemeImage()
        }
    }
    
    // Function to fetch meme image
    func fetchMemeImage() {
        guard let imageUrl = URL(string: meme.url) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageUrl)
                self.memeImage = UIImage(data: data)
            } catch {
                print("Error fetching meme image: \(error)")
            }
        }
    }

    
    // Function to place logo on meme image
    func placeLogoOnMeme() {
        guard let memeImage = memeImage, let logoImage = logoImage else { return }
        let newSize = CGSize(width: memeImage.size.width, height: memeImage.size.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        memeImage.draw(in: CGRect(origin: .zero, size: newSize))
        
        let logoSize = CGSize(width: memeImage.size.width * 0.5, height: memeImage.size.height * 0.5)
        logoImage.draw(in: CGRect(origin: CGPoint(x: memeImage.size.width / 2 - logoSize.width / 2, y: memeImage.size.height / 2 - logoSize.height / 2), size: logoSize))
        
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
        UIGraphicsEndImageContext()
        
        self.memeImage = newImage
    }
    
    // Function to add text to meme image
    func addTextToMeme() {
        guard let memeImage = memeImage else { return }
        let newSize = CGSize(width: memeImage.size.width, height: memeImage.size.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        memeImage.draw(in: CGRect(origin: .zero, size: newSize))
        
        let textRect = CGRect(x: 10, y: 10, width: newSize.width - 20, height: 100)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        textToAdd.draw(in: textRect, withAttributes: attributes)
        
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
        UIGraphicsEndImageContext()
        
        self.memeImage = newImage
    }
}


struct ImagePicker: UIViewControllerRepresentable {
    typealias SourceType = UIImagePickerController.SourceType
    let sourceType: SourceType
    let completionHandler: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completionHandler: completionHandler)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completionHandler: (UIImage?) -> Void
        
        init(completionHandler: @escaping (UIImage?) -> Void) {
            self.completionHandler = completionHandler
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                completionHandler(image)
            } else {
                completionHandler(nil)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completionHandler(nil)
        }
    }
}
