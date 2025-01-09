# README: PDF Viewer and Compressor

This SwiftUI project provides a **PDF Viewer** with integrated functionality for downloading, compressing, and sharing PDF files. Below is a detailed breakdown of the project's features, structure, and usage instructions.

---

## Features

1. **PDF Viewing**  
   - Displays PDF files using a custom `PDFViewWrapper`.
   
2. **PDF Downloading**  
   - Downloads PDFs from a provided URL and displays progress messages.

3. **PDF Compression**  
   - Reduces file size with adjustable quality levels (`low`, `medium`, `high`) to optimize storage and performance.

4. **Save and Share PDFs**  
   - Saves compressed PDF files to a temporary directory and enables sharing via a `UIActivityViewController`.

5. **Dynamic Quality Adjustment**  
   - Determines compression quality based on the original file size.

---

## Key Components

### 1. **PDFViewer (SwiftUI View)**
   - Handles the UI and logic for downloading and displaying PDFs.
   - **Properties**:
     - `pdfURL`: URL string of the PDF to download.
     - `pdfData`: State variable to store the downloaded PDF data.
   - **Methods**:
     - `downloadPDF(pdfURL:)`: Downloads and compresses the PDF.
     - `saveAndSharePDF()`: Saves the compressed PDF and opens a sharing sheet.

### 2. **PDFCompressionManager**
   - Manages the compression of PDF files.
   - **CompressionQuality**: Enum to define the compression level (low, medium, high).
   - **Methods**:
     - `compressPDF(_:quality:)`: Compresses an entire PDF.
     - `compressPage(_:quality:)`: Compresses individual PDF pages.

### 3. **Helper Extensions**
   - `Data.sizeInMB`: Calculates the size of a data object in MB.

---

## Usage

1. **Setup and Initialization**  
   Add the `PDFViewer` to your SwiftUI view hierarchy and pass the URL of the desired PDF:
   ```swift
   PDFViewer(pdfURL: "https://example.com/sample.pdf")
   ```

2. **Compress and Save**  
   The downloaded PDF will be automatically compressed. You can save and share the file by calling:
   ```swift
   saveAndSharePDF()
   ```

3. **Custom Compression**  
   To compress a local PDF and save it:
   ```swift
   let handler = PDFHandler()
   handler.compressAndSavePDF(inputURL: yourPDFURL) { compressedURL in
       if let compressedURL = compressedURL {
           print("Compressed PDF saved at \(compressedURL)")
       } else {
           print("Compression failed.")
       }
   }
   ```

---

## Notes

- **Error Handling**: Includes basic error handling for invalid URLs, failed downloads, and compression errors.
- **Memory Optimization**: Processes PDF pages in batches to avoid excessive memory usage.

---

## Dependencies

- Requires **PDFKit** and **SwiftUI** frameworks.

---

## License

This project is licensed under the [MIT License](LICENSE).
