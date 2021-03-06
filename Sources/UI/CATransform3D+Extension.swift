#if canImport(UIKit) && (os(iOS) || os(tvOS) || os(macOS))

import UIKit

extension CATransform3D {
    
    public func setPerspective(_ perspective: CGFloat) -> CATransform3D {
        var transform = self
        transform.m34 = perspective
        return transform
    }
    
    public func concatenating(_ transform: CATransform3D) -> CATransform3D {
        CATransform3DConcat(self, transform)
    }
    
}
#endif
