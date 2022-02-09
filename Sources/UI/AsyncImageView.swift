#if canImport(UIKit) && canImport(Combine) && (os(iOS) || os(tvOS) || os(macOS))

import UIKit
import Combine
import CoreGraphics

public struct AssetImage {
    let image: UIImage
    let isCached: Bool
}

@available(iOS 13.0, tvOS 13.0, *)
public protocol AsyncImage {
    func equals(_ image: AsyncImage) -> Bool
    func imagePublisher() -> AnyPublisher<AssetImage, URLError>
    func hash(into hasher: inout Hasher)
}

@available(iOS 13.0, tvOS 13.0, *)
extension AsyncImage where Self: Equatable {
    
    public func equals(_ image: AsyncImage) -> Bool {
        guard let image = image as? Self else {
            return false
        }
        return image == self
    }
    
}

@available(iOS 13.0, tvOS 13.0, *)
extension Optional where Wrapped == AsyncImage {
    
    public func equals(_ image: AsyncImage?) -> Bool {
        if case .none = self, case .none = image {
            return true
        } else if case .some(let lhs) = self,
                  case .some(let rhs) = image {
            return lhs.equals(rhs)
        }
        return false
    }
    
}

@available(iOS 13.0, tvOS 13.0, *)
extension URL: AsyncImage {
    
    public func imagePublisher() -> AnyPublisher<AssetImage, URLError> {
        if let cachedResult = URLCache.shared.cachedResponse(for: URLRequest(url: self)),
           let image = UIImage(data: cachedResult.data) {
            return Just(AssetImage(image: image, isCached: true))
                .setFailureType(to: URLError.self)
                .eraseToAnyPublisher()
        }
        return URLSession.shared.dataTaskPublisher(for: self)
            .tryMap { data, _ in
                guard let image = UIImage(data: data) else {
                    throw URLError(.cannotDecodeRawData)
                }
                return AssetImage(image: image, isCached: false)
            }
            .mapError { $0 as? URLError ?? URLError(.badServerResponse) }
            .eraseToAnyPublisher()
    }
    
}

@available(iOS 13.0, tvOS 13.0, *)
extension UIImage: AsyncImage {
    
    public func imagePublisher() -> AnyPublisher<AssetImage, URLError> {
        Just(AssetImage(image: self, isCached: true))
            .setFailureType(to: URLError.self)
            .eraseToAnyPublisher()
    }
    
}


@available(iOS 13.0, tvOS 13.0, *)
public class AsyncImageView: UIView {
    
    public enum State {
        case idle
        case loading
        case success
        case failed
    }
    
    private var setNeedsFetchImage = false
    /**
     Setting this to true will show the loading animation
     when an image is being fetched to display.
     Defaults to `false`
     */
    public var shouldShowLoadingAnimation = false
    public var image: AsyncImage? {
        didSet {
            if oldValue.equals(image) != true {
                setNeedsFetchImage = true
                fetchImage()
            }
        }
    }
    public var cornerRadius: CornerRadius = .value(0) {
        didSet {
            if oldValue != cornerRadius {
                setNeedsLayout()
            }
        }
    }
    override var bounds: CGRect {
        didSet {
            if oldValue != bounds {
                setNeedsFetchImage = true
                fetchImage()
            }
        }
    }
    
    @Published public private(set) var state = State.idle
    
    private var cancellables = Set<AnyCancellable>()
    private var imageCancellable: AnyCancellable?
    private let imageView = UIImageView()
    private let activityIndicatorView = UIActivityIndicatorView(style: .medium)
    private let resizeQueue = DispatchQueue(label: Bundle.main.bundleIdentifier ?? "" + ".graphics.resize")
    public var shouldAutoResize = true
    
    public override var contentMode: UIView.ContentMode {
        didSet {
            imageView.contentMode = contentMode
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        contentMode = .scaleAspectFill
        setUp(imageView: imageView)
        setUp(activityIndicatorView: activityIndicatorView)
        addSubview(imageView)
        addSubview(activityIndicatorView)
        setUpConstraints()
        bindState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func bindState() {
        $state
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                switch $0 {
                case .loading:
                    showLoadingAnimation()
                default:
                    hideLoadingAnimation()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setUp(imageView: UIImageView) {
        imageView.isUserInteractionEnabled = false
        imageView.contentMode = contentMode
    }
    
    private func setUp(activityIndicatorView: UIActivityIndicatorView) {
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setUpConstraints() {
        imageView.pinConstraints(to: self)
        NSLayoutConstraint.activate([
            activityIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    
    /**
     Should only be called by the instance itself and never by another object. Setting a new url will call this function indirectly.
     */
    private func fetchImage() {
        cancel()
        guard let image = image, window != nil else {
            return
        }
        setNeedsFetchImage = false
        state = .loading
        imageCancellable = image.imagePublisher()
            .flatMap { [unowned self] in
                self.resizeImage($0)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [unowned self] completion in
                switch completion {
                case .finished:
                    state = .success
                case .failure:
                    state = .failed
                }
                imageCancellable = nil
            }, receiveValue: { [unowned self] result in
                imageView.image = result.image
                if result.isCached {
                    imageView.alpha = 1
                } else {
                    UIView.animate(withDuration: 0.3) {
                        imageView.alpha = 1
                    }
                }
            })
    }
    
    public func retry() {
        fetchImage()
    }
    
    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            if imageCancellable != nil {
                cancel()
                setNeedsFetchImage = true
            }
        } else if setNeedsFetchImage {
            fetchImage()
        }
    }
    
    private func cancel() {
        imageCancellable = nil
        imageView.image = nil
        imageView.alpha = 0
        state = .idle
    }
    
    private func showLoadingAnimation() {
        guard shouldShowLoadingAnimation, !activityIndicatorView.isAnimating else { return }
        activityIndicatorView.startAnimating()
    }
    
    private func hideLoadingAnimation() {
        activityIndicatorView.stopAnimating()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if setNeedsFetchImage {
            fetchImage()
        }
        switch cornerRadius {
        case .value(let value):
            layer.cornerRadius = value
        case .percentage(let percentage):
            layer.cornerRadius = (bounds.height / 2) * percentage
        }
    }
    
    private func resizeImage<ImageError: Error>(_ asset: AssetImage) -> AnyPublisher<AssetImage, ImageError> {
        guard shouldAutoResize else {
            return Just(asset).setFailureType(to: ImageError.self).eraseToAnyPublisher()
        }
        return Future { [weak self] completion in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(.success(asset))
                    return
                }
                let size = self.bounds.size
                let image = asset.image
                if image.size.width <= size.width && image.size.height <= size.height {
                    completion(.success(asset))
                } else {
                    self.resizeQueue.async {
                        let resizedImage = self.redrawImage(image, toFit: size)
                        completion(.success(AssetImage(image: resizedImage, isCached: asset.isCached)))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    private func redrawImage(_ image: UIImage, toFit size: CGSize) -> UIImage {
        image.atSize(size)
    }
}

#endif
