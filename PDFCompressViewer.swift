import Foundation
import SwiftUI
import PDFKit

struct PDFViewer: View {
    
    private let cardAndImageWidth: CGFloat = .infinity
    private let cardHeight: CGFloat = 60
    private let cornerRadius: CGFloat = 5
    @State private var pdfData: Data?
  
    var pdfURL : String

    var body: some View {
        
        VStack(){
          
            if let pdfData = pdfData {
                PDFViewWrapper(pdfData: pdfData)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
                Text("Downloading PDF...")
                Spacer()
                    .onAppear {
                        downloadPDF(pdfURL: pdfURL)
                    }
            }
        }
    }
    
    func downloadPDF(pdfURL: String) {
            guard let url = URL(string: pdfURL) else {
                print("Invalid PDF URL")
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, _, error in
                if let error = error {
                    print("Error downloading PDF: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("Downloaded data is nil")
                    return
                }
                
                // Compress the PDF
                DispatchQueue.global(qos: .userInitiated).async {
                    if let compressedData = PDFCompressionManager.compressPDF(data) {
                        print("Original size: \(data.sizeInMB) MB")
                           print("Compressed size: \(compressedData.sizeInMB) MB")
                           print("Compression ratio: \(compressedData.count * 100 / data.count)%")
                        DispatchQueue.main.async {
                            self.pdfData = compressedData
                        }
                    } else {
                        print("Failed to compress PDF")
                        // Fallback to original data if compression fails
                        DispatchQueue.main.async {
                            self.pdfData = data
                        }
                    }
                }
            }.resume()
        }


    
    func saveAndSharePDF() {
        guard let pdfData = self.pdfData else {
            print("PDF data is nil.")
            return
        }
        
        var titlePDF: String = ""
        
        if let pdfDocument = PDFDocument(data: pdfData) {
            if let title = pdfDocument.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String {
                titlePDF = title
            } else {
                titlePDF = "\(Date().timeIntervalSince1970)"
            }
        }
        
        guard let pdfURL = saveToTemporaryDirectory(data: pdfData, fileName: "\(titlePDF).pdf") else {
            print("Failed to save PDF.")
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
        
        if let topViewController = UIApplication.shared.keyWindow?.rootViewController {
            var currentViewController = topViewController
            while let presentedViewController = currentViewController.presentedViewController {
                currentViewController = presentedViewController
            }
            currentViewController.present(activityViewController, animated: true, completion: nil)
        }
    }

    func saveToTemporaryDirectory(data: Data, fileName: String) -> URL? {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let fileURL = temporaryDirectoryURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("PDF saved at \(fileURL)")
            return fileURL
        } catch {
            print("Error saving PDF: \(error)")
            return nil
        }
    }

    func subsamplePDF(inputPDFData: Data, subsampleFactor: CGFloat) -> Data? {
        guard let pdfDocument = PDFDocument(data: inputPDFData) else {
            print("Failed to load PDF document")
            return nil
        }
        print("inputPDFData.count")
        print(inputPDFData.count)
        let newPDFDocument = PDFDocument()
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // Get the original page bounds
            let pageBounds = page.bounds(for: .mediaBox)
            let targetSize = CGSize(
                width: pageBounds.width / subsampleFactor,
                height: pageBounds.height
            )
            
            // Render the page as an image
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let image = renderer.image { context in
                // Flip the context vertically to correct the coordinate system
                context.cgContext.translateBy(x: 0, y: targetSize.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                // Scale for subsampling
                context.cgContext.scaleBy(x: 1 / subsampleFactor, y: 1 / subsampleFactor)
                page.draw(with: .mediaBox, to: context.cgContext)
            }
            
            // Create a new PDF page from the downsampled image
            if let compressedPage = PDFPage(image: image) {
                newPDFDocument.insert(compressedPage, at: pageIndex)
            }
        }
        
        // Export the new PDF as data
        return newPDFDocument.dataRepresentation()
    }


}

class PDFCompressionManager {
    enum CompressionQuality {
        case low
        case medium
        case high
        
        var imageCompressionQuality: CGFloat {
            switch self {
            case .low: return 0.3
            case .medium: return 0.5
            case .high: return 0.7
            }
        }
        
        var imageScale: CGFloat {
            switch self {
            case .low: return 0.5
            case .medium: return 0.7
            case .high: return 0.8
            }
        }
    }
    
    static func compressPDF(_ inputData: Data, quality: CompressionQuality = .medium) -> Data? {
        autoreleasepool {
            guard let originalPDF = PDFDocument(data: inputData) else {
                print("Failed to create PDF document")
                return nil
            }
            
            let compressedPDF = PDFDocument()
            let pageCount = originalPDF.pageCount
            
            // Process pages in batches to manage memory
            let batchSize = 3
            var currentPage = 0
            
            while currentPage < pageCount {
                autoreleasepool {
                    let endPage = min(currentPage + batchSize, pageCount)
                    
                    for pageIndex in currentPage..<endPage {
                        if let page = originalPDF.page(at: pageIndex),
                           let compressedPage = compressPage(page, quality: quality) {
                            compressedPDF.insert(compressedPage, at: pageIndex)
                        }
                    }
                    
                    currentPage = endPage
                }
            }
            
            return compressedPDF.dataRepresentation()
        }
    }
    
    private static func compressPage(_ page: PDFPage, quality: CompressionQuality) -> PDFPage? {
        autoreleasepool {
            let pageBounds = page.bounds(for: .mediaBox)
            let scale = quality.imageScale
            
            // Calculate target size
            let targetSize = CGSize(
                width: pageBounds.width * scale,
                height: pageBounds.height * scale
            )
            
            // Create renderer with target size
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            
            let image = renderer.image { context in
                // Fill background with white
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: targetSize))
                
                // Set up PDF drawing context
                context.cgContext.translateBy(x: 0, y: targetSize.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.scaleBy(x: scale, y: scale)
                
                // Draw the page
                page.draw(with: .mediaBox, to: context.cgContext)
            }
            
            // Compress the image
            guard let compressedImageData = image.jpegData(compressionQuality: quality.imageCompressionQuality),
                  let compressedImage = UIImage(data: compressedImageData) else {
                return nil
            }
            
            return PDFPage(image: compressedImage)
        }
    }
}

// Extension to check PDF size
extension Data {
    var sizeInMB: Double {
        Double(count) / (1024 * 1024)
    }
}

// Usage example
class PDFHandler {
    func compressAndSavePDF(inputURL: URL, completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                do {
                    // Read input PDF
                    let inputData = try Data(contentsOf: inputURL)
                    print("Original PDF size: \(inputData.sizeInMB) MB")
                    
                    // Determine compression quality based on file size
                    let quality: PDFCompressionManager.CompressionQuality
                    switch inputData.sizeInMB {
                    case ..<1:
                        quality = .high
                    case 1..<5:
                        quality = .medium
                    default:
                        quality = .low
                    }
                    
                    // Compress PDF
                    guard let compressedData = PDFCompressionManager.compressPDF(inputData, quality: quality) else {
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        return
                    }
                    
                    print("Compressed PDF size: \(compressedData.sizeInMB) MB")
                    
                    // Save compressed PDF
                    let outputURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("pdf")
                    
                    try compressedData.write(to: outputURL)
                    
                    DispatchQueue.main.async {
                        completion(outputURL)
                    }
                } catch {
                    print("Error: \(error)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
}
