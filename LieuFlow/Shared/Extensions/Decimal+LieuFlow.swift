import Foundation

extension Decimal {
    func rounded(_ mode: Decimal.RoundingMode = .plain, scale: Int) -> Decimal {
        var source = self
        var result = Decimal.zero
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }
}
