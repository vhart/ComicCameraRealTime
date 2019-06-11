import UIKit
import GPUImage

class ChromaKey {

    // Hue ranges from and to values
    let startRange: CGFloat = 0.3
    let endRange: CGFloat = 0.4

    private var backgrounds: [CGSize: CIImage] = [:]

    var cubeRGB: [Float] {
        let size = 64
        var cubeRGB = [Float]()

        // 2
        for z in 0 ..< size {
            let blue = CGFloat(z) / CGFloat(size-1)
            for y in 0 ..< size {
                let green = CGFloat(y) / CGFloat(size-1)
                for x in 0 ..< size {
                    let red = CGFloat(x) / CGFloat(size-1)

                    // 3
                    let hue = getHue(red: red, green: green, blue: blue)
                    let alpha: CGFloat = (hue >= 180 && hue <= 216) ? 0: 1

                    // 4
                    cubeRGB.append(Float(red * alpha))
                    cubeRGB.append(Float(green * alpha))
                    cubeRGB.append(Float(blue * alpha))
                    cubeRGB.append(Float(alpha))
                }
            }
        }

        return cubeRGB
    }

    // Get hue function
    func getHue(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1)
        var hue: CGFloat = 0
        color.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        return hue
    }

    // Create Chroma Key Filter function
    func chromaKeyFilter() -> CIFilter? {
        var newCube = cubeRGB
        // 1
        let data = Data(buffer: UnsafeBufferPointer(start: &newCube, count: newCube.count))

        // 5
        let colorCubeFilter = CIFilter(name: "CIColorCube", parameters: ["inputCubeDimension": 64, "inputCubeData": data])
        return colorCubeFilter
    }

    // Separated code
    // Pixel filtering function
    func filterPixels(foregroundCIImage: CIImage) -> CIImage {
        // Remove Green from the Source Image
        let chromaCIFilter = self.chromaKeyFilter()
        chromaCIFilter?.setValue(foregroundCIImage, forKey: kCIInputImageKey)
        let sourceCIImageWithoutBackground = chromaCIFilter?.outputImage
        var image = CIImage()
        if let filteredImage = sourceCIImageWithoutBackground {
            image = filteredImage
        }
        return image
    }

    // Image compositing function
    func compositeImages(foregroundCIImage: CIImage, backgroundCIImage: CIImage) -> CIImage {
        // Composite over a Background Image
        let compositor = CIFilter(name:"CISourceOverCompositing")
        compositor?.setValue(foregroundCIImage, forKey: kCIInputImageKey)
        compositor?.setValue(backgroundCIImage, forKey: kCIInputBackgroundImageKey)
        let compositedCIImage = compositor?.outputImage
        var image = CIImage()
        if let compositeImage = compositedCIImage {
            image = compositeImage
        }
        return image
    }

    // Complete combined filtering and compositing function
    func filterAndComposite(foregroundCIImage: CIImage) -> CIImage? {
        guard let background = getBackground(size: foregroundCIImage.extent.size), foregroundCIImage.extent.width > 0, foregroundCIImage.extent.height > 0 else { return foregroundCIImage }

        

        let filter = GPUImageChromaKeyFilter()
        let transparent = filter.image(byFilteringImage: UIImage(ciImage: foregroundCIImage))

        // Remove Green from the Source Image
//        let chromaCIFilter = self.chromaKeyFilter()
//        chromaCIFilter?.setValue(foregroundCIImage, forKey: kCIInputImageKey)
        let sourceCIImageWithoutBackground = transparent!.ciImage //chromaCIFilter?.outputImage

        // Composite over a Background Image
        let compositor = CIFilter(name:"CISourceOverCompositing")
        compositor?.setValue(sourceCIImageWithoutBackground, forKey: kCIInputImageKey)
        compositor?.setValue(background, forKey: kCIInputBackgroundImageKey)
        let compositedCIImage = compositor?.outputImage

        return compositedCIImage
    }

    private func getBackground(size: CGSize) -> CIImage? {
        if let existing = backgrounds[size] { return existing }

        let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 2))
        let image = renderer.image { (context) in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 2))
        }

        let ciimage = CIImage.init(image: image)
        backgrounds[size] = ciimage
        return ciimage
    }
}

extension CGSize: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}
