import SwiftUI
import UIKit

/// 支持 GIF 动图、WebP 动图和静态图片的 Emoji 视图
/// 优先使用 GIF 格式以获得更好的兼容性和动画效果
/// 如果图片资源不存在，会回退到显示文本 emoji
struct AnimatedEmojiView: View {
    let emoji: String  // 文本 emoji，作为回退
    let imageName: String?  // 图片资源名称（不含扩展名）
    let size: CGFloat
    let animated: Bool  // 是否启用动画
    
    @State private var uiImage: UIImage?
    @State private var isAnimated: Bool = false
    
    init(emoji: String, imageName: String? = nil, size: CGFloat = 20, animated: Bool = true) {
        self.emoji = emoji
        self.imageName = imageName
        self.size = size
        self.animated = animated
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                if isAnimated && animated {
                    // 使用 UIViewRepresentable 来播放动画
                    AnimatedImageView(image: uiImage, size: size)
                        .frame(width: size, height: size)
                } else {
                    // 静态图片使用 SwiftUI Image（禁用动画或非动画图片）
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                }
            } else {
                // 回退到文本 emoji
                Text(emoji)
                    .font(.system(size: size))
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let imageName = imageName else {
            return
        }
        
        // 优先尝试加载 GIF 动图（iOS 原生支持更好，帧延迟时间更准确）
        // 尝试多种路径：img 子目录、Resources/img、直接查找
        var gifURL: URL?
        
        // 方式1: 从 img 子目录加载（Xcode 可能将 img 文件夹直接放在 bundle 根目录）
        if let url = Bundle.main.url(forResource: imageName, withExtension: "gif", subdirectory: "img") {
            gifURL = url
        }
        // 方式2: 从 Resources/img 子目录加载
        else if let url = Bundle.main.url(forResource: imageName, withExtension: "gif", subdirectory: "Resources/img") {
            gifURL = url
        }
        // 方式3: 直接查找（不带子目录）
        else if let url = Bundle.main.url(forResource: imageName, withExtension: "gif") {
            gifURL = url
        }
        
        if let gifURL = gifURL, let gifData = try? Data(contentsOf: gifURL) {
            let (gifImage, animated) = loadGIFAnimatedImage(data: gifData)
            if let gifImage = gifImage {
                self.uiImage = gifImage
                self.isAnimated = animated
                return
            }
        }
        
        // 备选：尝试加载 WebP 动图（iOS 对 WebP 动图支持有限）
        var webpURL: URL?
        if let url = Bundle.main.url(forResource: imageName, withExtension: "webp", subdirectory: "img") {
            webpURL = url
        } else if let url = Bundle.main.url(forResource: imageName, withExtension: "webp", subdirectory: "Resources/img") {
            webpURL = url
        } else if let url = Bundle.main.url(forResource: imageName, withExtension: "webp") {
            webpURL = url
        }
        
        if let webpURL = webpURL, let webpData = try? Data(contentsOf: webpURL) {
            let (webpImage, animated) = loadWebPAnimatedImage(data: webpData)
            if let webpImage = webpImage {
                self.uiImage = webpImage
                self.isAnimated = animated
                return
            }
        }
        
        // 尝试加载静态图片（PNG/JPEG）
        var pngURL: URL?
        if let url = Bundle.main.url(forResource: imageName, withExtension: "png", subdirectory: "img") {
            pngURL = url
        } else if let url = Bundle.main.url(forResource: imageName, withExtension: "png", subdirectory: "Resources/img") {
            pngURL = url
        } else if let url = Bundle.main.url(forResource: imageName, withExtension: "png") {
            pngURL = url
        }
        
        if let pngURL = pngURL, let staticImage = UIImage(contentsOfFile: pngURL.path) {
            self.uiImage = staticImage
            self.isAnimated = false
            return
        }
        
        // 尝试加载 JPEG 格式的静态图片
        var jpegURL: URL?
        if let url = Bundle.main.url(forResource: imageName, withExtension: "jpg", subdirectory: "img") {
            jpegURL = url
        } else if let url = Bundle.main.url(forResource: imageName, withExtension: "jpg", subdirectory: "Resources/img") {
            jpegURL = url
        } else if let url = Bundle.main.url(forResource: imageName, withExtension: "jpg") {
            jpegURL = url
        }
        
        if let jpegURL = jpegURL, let staticImage = UIImage(contentsOfFile: jpegURL.path) {
            self.uiImage = staticImage
            self.isAnimated = false
            return
        }
    }
    
    /// 加载 WebP 动图
    /// 注意：iOS 14+ 原生支持 WebP 静态图片，但 WebP 动图支持有限
    /// 对于 WebP 动图，建议转换为 GIF 格式以获得更好的兼容性
    /// 返回: (UIImage?, Bool) - (图片, 是否为动画)
    private func loadWebPAnimatedImage(data: Data) -> (UIImage?, Bool) {
        // iOS 14+ 原生支持 WebP 静态图片
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return (nil, false)
        }
        
        let count = CGImageSourceGetCount(imageSource)
        guard count > 1 else {
            // 单帧图片，直接加载
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return (nil, false)
            }
            return (UIImage(cgImage: cgImage), false)
        }
        
        // 多帧 WebP 动图处理
        // 注意：iOS 原生对 WebP 动图支持有限，可能需要使用第三方库
        // 这里尝试提取所有帧并创建动画图片
        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0
        
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) else {
                continue
            }
            
            let image = UIImage(cgImage: cgImage)
            images.append(image)
            
            // 获取帧延迟时间
            // 注意：iOS 原生对 WebP 动图的帧延迟时间支持有限
            // 这里使用默认值，如果需要精确控制，建议使用 GIF 格式
            var delayTime: Double = 0.1  // 默认 100ms
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as? [String: Any] {
                // 尝试从 GIF 字典获取（某些工具可能将 WebP 动图信息存储在 GIF 字典中）
                if let gifDict = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                   let gifDelay = gifDict[kCGImagePropertyGIFDelayTime as String] as? Double {
                    delayTime = max(gifDelay, 0.01)  // 确保至少 10ms
                }
            }
            
            totalDuration += delayTime
        }
        
        guard !images.isEmpty else {
            return (nil, false)
        }
        
        // 如果只有一帧，返回静态图片
        if images.count == 1 {
            return (images.first, false)
        }
        
        // 创建动画图片
        let animatedImage = UIImage.animatedImage(with: images, duration: max(totalDuration, 0.1))
        return (animatedImage, true)
    }
    
    /// 加载 GIF 动图
    /// 返回: (UIImage?, Bool) - (图片, 是否为动画)
    private func loadGIFAnimatedImage(data: Data) -> (UIImage?, Bool) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return (nil, false)
        }
        
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            // 单帧，直接加载
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                return (nil, false)
            }
            return (UIImage(cgImage: cgImage), false)
        }
        
        // 多帧，创建动画图片
        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0
        
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }
            
            let image = UIImage(cgImage: cgImage)
            images.append(image)
            
            // 获取帧延迟时间
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
               let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                totalDuration += delayTime
            } else {
                totalDuration += 0.1  // 默认延迟
            }
        }
        
        guard !images.isEmpty else {
            return (nil, false)
        }
        
        // 创建动画图片
        let animatedImage = UIImage.animatedImage(with: images, duration: totalDuration)
        return (animatedImage, true)
    }
}

/// 使用 UIViewRepresentable 包装 UIImageView 以支持动画播放
struct AnimatedImageView: UIViewRepresentable {
    let image: UIImage
    let size: CGFloat
    
    func makeUIView(context: Context) -> UIView {
        // 使用容器视图来让 SwiftUI 完全控制大小
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        // 让 imageView 填充整个 containerView
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 如果是动画图片，开始播放
        if image.images != nil {
            imageView.startAnimating()
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 找到 imageView
        guard let imageView = uiView.subviews.first as? UIImageView else {
            return
        }
        
        // 更新图片
        if imageView.image !== image {
            imageView.image = image
        }
        
        // 确保动画持续播放
        if image.images != nil {
            if !imageView.isAnimating {
                imageView.startAnimating()
            }
        } else {
            imageView.stopAnimating()
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        if let imageView = uiView.subviews.first as? UIImageView {
            imageView.stopAnimating()
        }
    }
}
