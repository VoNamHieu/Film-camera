import UIKit
import CoreImage

class FilterPipeline {
    
    // Context để xử lý ảnh (dùng GPU)
    private let context = CIContext()
    
    // Hàm chính: Nhận ảnh gốc -> Trả về ảnh màu film
    func processImage(_ inputImage: UIImage) -> UIImage? {
        // 1. Chuyển đổi UIImage sang CIImage để xử lý
        guard let ciImage = CIImage(image: inputImage) else { return nil }
        
        // 2. Tạo chuỗi các bộ lọc (Chain of Filters)
        var processedImage = ciImage
        
        // --- Ví dụ: Bước chỉnh màu (Giả lập màu Film) ---
        // Bạn có thể dùng LUT hoặc chỉnh màu cơ bản
        if let colorFilter = CIFilter(name: "CIPhotoEffectChrome") { // Ví dụ dùng màu Chrome có sẵn
            colorFilter.setValue(processedImage, forKey: kCIInputImageKey)
            if let output = colorFilter.outputImage {
                processedImage = output
            }
        }
        
        // --- Ví dụ: Thêm Grain (Hạt nhiễu) ---
        // (Logic thêm noise sẽ phức tạp hơn, đây là ví dụ giữ chỗ)
        
        // 3. Render lại thành UIImage
        if let cgImage = context.createCGImage(processedImage, from: processedImage.extent) {
            // Cần giữ nguyên chiều xoay (Orientation) của ảnh gốc
            return UIImage(cgImage: cgImage, scale: inputImage.scale, orientation: inputImage.imageOrientation)
        }
        
        return nil
    }
}
