import SwiftUI

/// The only spacing and radius values in the app. A literal in a view is a bug — if a value here
/// does not fit, the scale is wrong and should be changed here, not bypassed locally.
enum Spacing {
    static let none: CGFloat = 0
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 18
    static let control: CGFloat = 12
    static let chip: CGFloat = 999
}
