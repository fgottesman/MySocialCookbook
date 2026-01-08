import Foundation

enum MeasurementSystem: String, CaseIterable, Identifiable {
    case us = "US"
    case metric = "Metric"
    
    var id: String { self.rawValue }
}

class MeasurementConverter {
    static let shared = MeasurementConverter()
    
    private let fractionMap: [String: Double] = [
        "½": 0.5, "⅓": 0.333, "⅔": 0.666, "¼": 0.25, "¾": 0.75,
        "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8,
        "⅙": 0.166, "⅚": 0.833, "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
    ]
    
    // Normalize unit names to a standard key
    private let unitMap: [String: String] = [
        // Volume
        "tsp": "tsp", "teaspoon": "tsp", "teaspoons": "tsp", "t": "tsp",
        "tbsp": "tbsp", "tablespoon": "tbsp", "tablespoons": "tbsp", "T": "tbsp",
        "c": "cup", "cup": "cup", "cups": "cup",
        "pt": "pt", "pint": "pt", "pints": "pt",
        "qt": "qt", "quart": "qt", "quarts": "qt",
        "gal": "gal", "gallon": "gal", "gallons": "gal",
        "fl oz": "fl oz", "fluid ounce": "fl oz", "fluid ounces": "fl oz",
        "ml": "ml", "milliliter": "ml", "milliliters": "ml",
        "l": "l", "liter": "l", "liters": "l",
        
        // Weight
        "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb",
        "oz": "oz", "ounce": "oz", "ounces": "oz",
        "mg": "mg", "milligram": "mg", "milligrams": "mg",
        "g": "g", "gram": "g", "grams": "g",
        "kg": "kg", "kilogram": "kg", "kilograms": "kg"
    ]
    
    func convert(amount: String, unit: String, to targetSystem: MeasurementSystem) -> (amount: String, unit: String) {
        // 1. Parse amount
        guard let value = parseAmount(amount) else {
            return (amount, unit)
        }
        
        // 2. Normalize unit
        let normalizedUnitKey = unitMap[unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: "")] ?? unit.lowercased()
        
        // 3. Determine type and current system, then convert
        // We will convert everything to a base unit first (ml for volume, g for weight)
        // Then convert to target system
        
        if let baseMl = toBaseVolume(value: value, unit: normalizedUnitKey) {
            // It's a volume
            if targetSystem == .metric {
                if baseMl >= 1000 {
                    return (format(baseMl / 1000), "L")
                } else {
                    return (format(baseMl), "ml")
                }
            } else {
                // To US
                return fromBaseVolumeToUS(ml: baseMl)
            }
        } else if let baseG = toBaseWeight(value: value, unit: normalizedUnitKey) {
            // It's a weight
            if targetSystem == .metric {
                if baseG >= 1000 {
                    return (format(baseG / 1000), "kg")
                } else {
                    return (format(baseG), "g")
                }
            } else {
                // To US
                return fromBaseWeightToUS(g: baseG)
            }
        }
        
        // Unknown unit type, return as is
        return (amount, unit)
    }
    
    // MARK: - Parsing
    
    private func parseAmount(_ amountString: String) -> Double? {
        let cleaned = amountString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return nil }
        
        // Handle ranges like "1-2" -> return average? or just nil?
        // Current requirement: simple conversion. Let's return nil for ranges to be safe/simple, or just first number.
        if cleaned.contains("-") {
            // e.g. "1-2"
            let parts = cleaned.components(separatedBy: "-")
            if let first = Double(parts[0]) {
                return first
            }
            return nil
        }
        
        // Handle fraction characters
        for (char, val) in fractionMap {
            if cleaned.contains(char) {
                // If like "1½", split
                let parts = cleaned.components(separatedBy: char)
                var total = val
                if let prefix = parts.first, let preVal = Double(prefix) {
                    total += preVal
                }
                return total
            }
        }
        
        // Handle "1/2" or "1 1/2"
        if cleaned.contains("/") {
            let parts = cleaned.components(separatedBy: " ")
            var total: Double = 0
            
            for part in parts {
                if part.contains("/") {
                    let fractionParts = part.components(separatedBy: "/")
                    if fractionParts.count == 2,
                       let num = Double(fractionParts[0]),
                       let den = Double(fractionParts[1]),
                       den != 0 {
                        total += num / den
                    }
                } else if let val = Double(part) {
                    total += val
                }
            }
            return total > 0 ? total : nil
        }
        
        return Double(cleaned)
    }
    
    // MARK: - Volume Conversion
    
    private func toBaseVolume(value: Double, unit: String) -> Double? {
        switch unit {
        case "ml": return value
        case "l": return value * 1000
        case "tsp": return value * 4.92892
        case "tbsp": return value * 14.7868
        case "fl oz": return value * 29.5735
        case "cup": return value * 236.588
        case "pt": return value * 473.176
        case "qt": return value * 946.353
        case "gal": return value * 3785.41
        default: return nil
        }
    }
    
    private func fromBaseVolumeToUS(ml: Double) -> (String, String) {
        // Heuristics for best unit
        if ml < 15 {
            let tsp = ml / 4.92892
            return (format(tsp), "tsp")
        } else if ml < 45 {
            let tbsp = ml / 14.7868
            return (format(tbsp), "tbsp")
        } else if ml < 240 {
            // Maybe oz or cups? 
            // 240ml is 1 cup.
            // Let's use fl oz if it's not a nice fraction of a cup
            // But cups are standard.
            let cups = ml / 236.588
            return (format(cups), "cup")
        } else {
            let cups = ml / 236.588
            return (format(cups), "cups")
        }
    }
    
    // MARK: - Weight Conversion
    
    private func toBaseWeight(value: Double, unit: String) -> Double? {
        switch unit {
        case "g": return value
        case "kg": return value * 1000
        case "mg": return value / 1000
        case "oz": return value * 28.3495
        case "lb": return value * 453.592
        default: return nil
        }
    }
    
    private func fromBaseWeightToUS(g: Double) -> (String, String) {
        let lbs = g / 453.592
        if lbs >= 1.0 {
            return (format(lbs), "lbs")
        } else {
            let oz = g / 28.3495
            return (format(oz), "oz")
        }
    }
    
    // MARK: - Formatting
    
    private func format(_ value: Double) -> String {
        // Round to reasonable significant digits
        // If it's close to a whole number or simple fraction, format nicely?
        // For simplicity, 1 decimal place if < 10, else no decimals if whole.
        
        // Check for common fractions tolerance
        let remainder = value.truncatingRemainder(dividingBy: 1)
        if abs(remainder) < 0.1 || abs(remainder) > 0.9 {
            return String(format: "%.0f", value)
        } else if abs(remainder - 0.5) < 0.1 {
            let floor = floor(value)
            return floor == 0 ? "1/2" : "\(Int(floor)) 1/2"
        } else if abs(remainder - 0.25) < 0.1 {
            let floor = floor(value)
            return floor == 0 ? "1/4" : "\(Int(floor)) 1/4"
        } else if abs(remainder - 0.75) < 0.1 {
            let floor = floor(value)
            return floor == 0 ? "3/4" : "\(Int(floor)) 3/4"
        } else if abs(remainder - 0.33) < 0.1 {
            let floor = floor(value)
            return floor == 0 ? "1/3" : "\(Int(floor)) 1/3"
        } else if abs(remainder - 0.66) < 0.1 {
             let floor = floor(value)
             return floor == 0 ? "2/3" : "\(Int(floor)) 2/3"
        }
        
        if value < 10 {
            // Max 1 decimal
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }
}
