import Foundation
import CoreData

struct PressureAlertPayload: Codable {
    let alertLevel: String
    let suggestedMessage: String
    let pressureDelta: Double
    let triggerTime: String
    
    enum CodingKeys: String, CodingKey {
        case alertLevel = "alert_level"
        case suggestedMessage = "suggested_message"
        case pressureDelta = "pressure_delta"
        case triggerTime = "trigger_time"
    }
    
    var triggerDate: Date? {
        ISO8601DateFormatter().date(from: triggerTime)
    }
}

struct SymptomEntryPayload: Codable {
    let timestamp: String
    let symptom_type: String
    let severity: Int
}

struct WeatherSnapshotPayload: Codable {
    let timestamp: String
    let temperature: Double
    let humidity: Double
    let pressure: Double
    let wind: Double
}

struct WeeklyInsightDay: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let detail: String
}

struct CorrelationRequest: Codable {
    let symptoms: [SymptomEntryPayload]
    let weather: [WeatherSnapshotPayload]
    let hourly_forecast: [WeatherSnapshotPayload]?
    let weekly_forecast: [WeatherSnapshotPayload]?
    let user_id: String?
    let diagnoses: [String]?
    
    init(symptoms: [SymptomEntryPayload], weather: [WeatherSnapshotPayload], hourly_forecast: [WeatherSnapshotPayload]? = nil, weekly_forecast: [WeatherSnapshotPayload]? = nil, user_id: String? = nil, diagnoses: [String]? = nil) {
        self.symptoms = symptoms
        self.weather = weather
        self.hourly_forecast = hourly_forecast
        self.weekly_forecast = weekly_forecast
        self.user_id = user_id
        self.diagnoses = diagnoses
    }
}

struct InsightResponse: Codable {
    let correlation_summary: String
    let strongest_factors: [String: Double]
    let ai_message: String
    let citations: [String]?  // Optional list of source filenames from RAG
    let risk: String?  // LOW, MODERATE, or HIGH
    let forecast: String?  // 1-sentence forecast message
    let why: String?  // Plain-language explanation for the risk
    let weekly_forecast_insight: String?  // Weekly forecast preview insight
    let weekly_insight_sources: [String]?  // Sources backing the weekly preview
    let support_note: String?  // Optional emotional encouragement for moderate/high risk
    let pressure_alert: PressureAlertPayload?  // Optional short-term pressure alert
    let alert_severity: String?  // low, moderate, sharp
    let personalization_score: Int?
    let personal_anecdote: String?
    let behavior_prompt: String?
}

struct FeedbackRequestPayload: Codable {
    let was_helpful: Bool
    let analysis_id: String?
    let analysis_hash: String?
    let user_id: String?
    let risk: String?
    let forecast: String?
    let why: String?
    let support_note: String?
    let citations: [String]
    let diagnoses: [String]?
    let location: String?
    let app_version: String?
    let pressure_alert: PressureAlertPayload?
    let alert_severity: String?
    let personalization_score: Int?
    let personal_anecdote: String?
    let behavior_prompt: String?
}

struct FeedbackResponsePayload: Codable {
    let status: String
    let feedback_id: String
}

@MainActor
final class AIInsightsService: ObservableObject {
    @Published var insightMessage: String = "Analyzing your week…"
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var citations: [String] = []
    @Published var lastAnalysisTime: Date? = nil
    @Published var risk: String? = nil  // LOW, MODERATE, or HIGH
    @Published var forecast: String? = nil  // 1-sentence forecast
    @Published var why: String? = nil  // Explanation
    @Published var weeklyForecastInsight: String? = nil  // Weekly forecast preview
    @Published var weeklyInsightSources: [String] = []  // Weekly insight references
    @Published var weeklyInsightSummary: String? = nil
    @Published var weeklyInsightDays: [WeeklyInsightDay] = []
    @Published var supportNote: String? = nil  // Emotional encouragement when risk elevated
    @Published var pressureAlert: PressureAlertPayload? = nil  // Short-term pressure alert payload
    @Published var alertSeverity: String? = nil  // Severity tag from backend
    @Published var personalizationScore: Int? = nil  // Personalization score 1-5
    @Published var personalAnecdote: String? = nil
    @Published var behaviorPrompt: String? = nil
    
    // MARK: - Formatting Helpers
    // Sanitize insight text to strictly follow UI rules:
    // - No technical numbers or units (e.g. "hPa", "mb", "%", temperatures, pressures).
    // - No stray markdown, HTML, bullets, or formatting.
    // - No medical claims or advice.
    private func sanitizeInsightText(_ text: String?) -> String? {
        guard var text = text, !text.isEmpty else { return text }
        
        // Strip HTML/markdown artifacts
        text = text.replacingOccurrences(of: "<br>", with: " ")
        text = text.replacingOccurrences(of: "<br/>", with: " ")
        text = text.replacingOccurrences(of: "<br />", with: " ")
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "*", with: "")
        text = text.replacingOccurrences(of: "_", with: "")
        text = text.replacingOccurrences(of: "- ", with: "") // Remove bullet-style dashes
        text = text.replacingOccurrences(of: "•", with: "")
        text = text.replacingOccurrences(of: "  ", with: " ") // Collapse double spaces
        
        // Remove technical units and numbers with units
        let forbiddenPatterns = [
            "\\d+\\s*(°c|°f|hpa|mb|kpa|mmhg|%|percent|degrees|inches|mm|cm)",
            "\\d+\\s*(hpa|mb|kpa|mmhg)",
            "atmospheric pressure at \\d+",
            "pressure at \\d+",
            "temperature.*\\d+",
            "\\d+\\s*c(elsius)?",
            "\\d+\\s*f(ahrenheit)?",
            "\\d+\\s*%"
        ]
        
        for pattern in forbiddenPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Remove forbidden technical terms
        let forbiddenTerms = [
            "hpa", "mb", "kpa", "mmhg", "dew point", "trough", "pressure gradient",
            "atmospheric pressure", "barometric", "millibars", "hectopascals",
            "you should", "try to", "good day for", "keeps things gentle",
            "conditions stay stable", "high/low sensitivity"
        ]
        
        for term in forbiddenTerms {
            text = text.replacingOccurrences(of: term, with: "", options: [.caseInsensitive])
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ") // Final cleanup
    }
    
    /// Fix broken weekly summary templates caused by missing/null values
    /// Removes template placeholders, incomplete phrases, and numeric weather data
    /// STRICT: Weekly summaries must be fully AI-generated, no numeric values, no templates
    /// SAFE, NON-DESTRUCTIVE: Only fixes formatting, doesn't change valid AI-generated content
    private func fixBrokenWeeklySummaryTemplate(_ text: String?) -> String? {
        guard var text = text, !text.isEmpty else { return text }
        
        let lowerText = text.lowercased()
        
        // CRITICAL: Remove the specific broken template text pattern
        // "The upcoming week presents a consistent weather pattern with stable temperatures around to , steady at , and humidity around."
        let brokenTemplatePatterns = [
            "the upcoming week presents.*temperatures around to.*steady at.*humidity around",
            "consistent weather pattern.*temperatures around to",
            "stable temperatures around to",
            "steady at\\s*,\\s*and",
            "humidity around\\s*\\.?\\s*$"
        ]
        
        for pattern in brokenTemplatePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    // If this broken template pattern is found, replace with safe fallback
                    return "A steady week ahead with consistent conditions."
                }
            }
        }
        
        // Remove template placeholders like {min_temp}, {max_temp}, etc.
        let placeholderPatterns = [
            "\\{min_temp\\}",
            "\\{max_temp\\}",
            "\\{mid_temp\\}",
            "\\{humidity_min\\}",
            "\\{humidity_max\\}",
            "\\{pressure_min\\}",
            "\\{pressure_max\\}",
            "\\{[^}]*temp[^}]*\\}",
            "\\{[^}]*humidity[^}]*\\}",
            "\\{[^}]*pressure[^}]*\\}"
        ]
        
        for pattern in placeholderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Remove numeric weather ranges (e.g., "temps from 50 to 70", "50-70°F")
        let numericRangePatterns = [
            "\\d+\\s*-\\s*\\d+\\s*(°|degrees|f|c|hpa|mb|%)",
            "from\\s+\\d+\\s+to\\s+\\d+",
            "between\\s+\\d+\\s+and\\s+\\d+",
            "ranging from\\s+\\d+",
            "around\\s+\\d+",
            "near\\s+\\d+",
            "at\\s+\\d+",
            "steady at\\s+\\d+"
        ]
        
        for pattern in numericRangePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Remove percentages (e.g., "humidity around 60%")
        if let regex = try? NSRegularExpression(pattern: "\\d+\\s*%", options: []) {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        
        // Pattern 1: "ranging from to" or "from to" (missing min/max values)
        // Also catch phrases with "around to", "near to", etc.
        let brokenRangePatterns = [
            "ranging from\\s+to\\s+",
            "from\\s+to\\s+",
            "between\\s+and\\s+",
            "from\\s+to\\s+and",
            "ranging from\\s+to\\s+and",
            "around\\s+to\\s+",
            "near\\s+to\\s+",
            "temperatures around to",
            "humidity around to",
            "pressure around to"
        ]
        
        for pattern in brokenRangePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Pattern 2: "steady at" or "at" without a number following
        // Match "steady at " or "at " followed by non-numeric text (like "and", "with", punctuation, or end of string)
        // Use a simpler approach: match "at/around/near" followed by whitespace and then a word that's not a number
        let brokenAtPatterns = [
            "steady at\\s+(and|with|,|$)",
            "at\\s+(and|with|,|$)",
            "around\\s+(and|with|,|$)",
            "near\\s+(and|with|,|$)"
        ]
        
        for pattern in brokenAtPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Also remove "steady at" or "at" at end of string (no value following)
        let endPatterns = [
            "\\s+steady at\\s*$",
            "\\s+at\\s*$",
            "\\s+around\\s*$",
            "\\s+near\\s*$"
        ]
        
        for pattern in endPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Pattern 3: Remove incomplete temperature phrases
        // "temps ranging", "temperatures ranging", "temps from", etc. without values
        let incompleteTempPhrases = [
            "temps ranging\\s*$",
            "temperatures ranging\\s*$",
            "temps from\\s*$",
            "temperatures from\\s*$",
            "temps between\\s*$",
            "temperatures between\\s*$"
        ]
        
        for pattern in incompleteTempPhrases {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Pattern 4: Remove incomplete pressure/humidity phrases
        let incompleteOtherPhrases = [
            "pressure ranging\\s*$",
            "humidity ranging\\s*$",
            "pressure from\\s*$",
            "humidity from\\s*$"
        ]
        
        for pattern in incompleteOtherPhrases {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Pattern 5: Remove phrases with "around", "near", "at" followed by nothing or comma
        // This catches cases like "stable temperatures around ," or "humidity around ."
        let emptyAroundPatterns = [
            "around\\s*,\\s*",
            "near\\s*,\\s*",
            "at\\s*,\\s*",
            "around\\s*\\.\\s*",
            "near\\s*\\.\\s*",
            "at\\s*\\.\\s*"
        ]
        
        for pattern in emptyAroundPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }
        
        // Clean up: remove extra spaces, "and" at start/end, trailing commas
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "^and\\s+", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "\\s+and\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: ",\\s*$", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: ",\\s*,", with: ",", options: .regularExpression) // Remove double commas
        text = text.replacingOccurrences(of: "\\s+,\\s+", with: ", ", options: .regularExpression)
        
        // If the text is now empty or too short after cleanup, provide a safe fallback
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.isEmpty || cleanedText.count < 10 {
            // Build a safe fallback based on what we can detect
            if lowerText.contains("steady") || lowerText.contains("stable") {
                return "A steady week ahead with consistent conditions."
            } else if lowerText.contains("cool") || lowerText.contains("cooler") {
                return "A mostly stable pattern with slightly cooler conditions."
            } else if lowerText.contains("warm") || lowerText.contains("warmer") {
                return "A mostly stable pattern with mild temperatures."
            } else {
                return "Weather stays fairly consistent through the week."
            }
        }
        
        // Ensure sentence ends properly
        if !cleanedText.hasSuffix(".") && !cleanedText.hasSuffix("!") && !cleanedText.hasSuffix("?") {
            text = cleanedText + "."
        } else {
            text = cleanedText
        }
        
        return text
    }
    
    /// Get weekday abbreviations starting from tomorrow (7 days total)
    private func getNextSevenWeekdays() -> [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // Sat, Sun, Mon...
        
        var weekdays: [String] = []
        for offset in 1...7 {
            if let date = calendar.date(byAdding: .day, value: offset, to: Date()) {
                weekdays.append(formatter.string(from: date))
            }
        }
        return weekdays
    }
    
    /// Helper to capitalize first letter of string
    private func capitalizeFirstLetter(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.prefix(1).uppercased() + text.dropFirst()
    }
    
    /// Check if two strings are too similar (identical or nearly identical)
    /// Returns true if they should be considered duplicates
    private func areTextsTooSimilar(_ text1: String, _ text2: String) -> Bool {
        let normalized1 = text1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = text2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match
        if normalized1 == normalized2 {
            return true
        }
        
        // Check if one contains the other (more than 80% overlap)
        if normalized1.count > 0 && normalized2.count > 0 {
            let longer = normalized1.count > normalized2.count ? normalized1 : normalized2
            let shorter = normalized1.count > normalized2.count ? normalized2 : normalized1
            
            if longer.contains(shorter) && Double(shorter.count) / Double(longer.count) > 0.8 {
                return true
            }
        }
        
        // Check word overlap (if more than 70% of words match, consider too similar)
        let words1 = Set(normalized1.components(separatedBy: .whitespaces).filter { $0.count > 2 })
        let words2 = Set(normalized2.components(separatedBy: .whitespaces).filter { $0.count > 2 })
        
        guard !words1.isEmpty && !words2.isEmpty else { return false }
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        let similarity = Double(intersection.count) / Double(union.count)
        
        return similarity > 0.7
    }
    
    /// Check if "why" text contains vague, non-specific language
    /// Returns true if the text should be rewritten to use specific body sensations
    /// STRICT: Weather never "feels" - only the body does. Only physical body sensations allowed.
    private func containsVagueLanguage(_ text: String) -> Bool {
        let lowerText = text.lowercased()
        
        // Forbidden vague phrases - comprehensive list
        let vaguePhrases = [
            // Forbidden from user spec
            "supportive",
            "gentle",
            "gentler",
            "conditions remain stable",
            "keeps things steady",
            "may feel different",
            "may feel off",
            "feels heavier",
            "might impact comfort",
            "could feel easier",
            // Additional forbidden phrases
            "feels off",
            "keeps things gentle",
            "you may notice changes",
            "can impact your comfort",
            "affects the body",
            "might feel different",
            "keeps things calm",
            "noticeable shifts",
            "feels different",
            "can feel different",
            "feels unusual",
            "stays stable",
            "remains calm",
            "feels gentle",
            "feels calm",
            "feels steady",
            "can affect",
            "may impact",
            "could affect",
            "might impact",
            // Check for weather "feeling" - only body should feel
            "pressure feels",
            "humid feels",
            "temperature feels",
            "wind feels",
            "air feels",
            "weather feels",
            "conditions feel"
        ]
        
        for phrase in vaguePhrases {
            if lowerText.contains(phrase) {
                return true
            }
        }
        
        // Check for "lighter" unless tied to muscles/joints
        if lowerText.contains("lighter") {
            let lighterInContext = lowerText.contains("muscles") || lowerText.contains("joints") || lowerText.contains("tightness")
            if !lighterInContext {
                return true // "lighter" without muscle/joint context is forbidden
            }
        }
        
        return false
    }
    
    /// Rewrite vague "why" language to use specific, concrete body sensations
    /// Maps weather factors to specific physical feelings
    private func rewriteVagueWhy(_ whyText: String, weatherFactor: String) -> String {
        let lowerText = whyText.lowercased()
        
        // Detect weather factor from why text if not provided
        var detectedFactor = weatherFactor
        if lowerText.contains("pressure") || lowerText.contains("barometric") {
            detectedFactor = "pressure"
        } else if lowerText.contains("humid") || lowerText.contains("moisture") {
            detectedFactor = "humidity"
        } else if lowerText.contains("temperat") || lowerText.contains("cool") || lowerText.contains("warm") || lowerText.contains("heat") {
            detectedFactor = "temperature"
        } else if lowerText.contains("wind") || lowerText.contains("breeze") {
            detectedFactor = "wind"
        }
        
        // Generate specific body-sensation explanations based on weather factor
        // STRICT RULE: Weather NEVER "feels" - only the BODY does
        // Each links ONE weather factor → ONE physical body sensation using ONLY approved vocabulary
        // Allowed: sluggish, draining, tiring, slow, effortful, stiff, tense, sensitive, heavy to move,
        //          thick air, dense air, loosen tightness, ease tension, muscles may loosen, joints may feel easier, may ease stiffness
        let whyVariants: [String: [String]] = [
            "pressure": [
                "Pressure drops can make the body feel heavy or slow.",
                "Stable pressure can ease tension in sensitive joints.",
                "Rapid pressure changes can make muscles feel stiff or tense.",
                "Gradual pressure shifts can feel draining on sensitive systems.",
                "Low pressure can make movement feel more effortful and tiring.",
                "Steady pressure may ease stiffness in joints."
            ],
            "humidity": [
                "Thick air can make the body feel tiring.",
                "Humid conditions can make movement feel more effortful.",
                "Heavy humidity can drain energy and make the body feel sluggish.",
                "Dense air can make breathing feel more effortful.",
                "Rising humidity can make joints feel stiff.",
                "Moist air can increase sensitivity in the body."
            ],
            "temperature": [
                "Heat can drain energy and make the body feel sluggish.",
                "Cool air can stiffen muscles and increase sensitivity.",
                "Warm temperatures can make movement feel tiring and effortful.",
                "Cooler air may make joints feel stiff or tense.",
                "High heat can feel draining and make the body feel heavy.",
                "Stable temperatures may ease tension in tight muscles."
            ],
            "wind": [
                "Calm air can ease tension in sensitive systems.",
                "Gusty winds can feel draining and tiring on the body.",
                "Stable air may make movement feel less effortful.",
                "Light breezes may help ease stagnant, heavy feelings."
            ]
        ]
        
        let variants = whyVariants[detectedFactor] ?? whyVariants["pressure"]!
        
        // Return a random variant that uses specific body-sensation language
        // Filter to avoid any that still contain vague language
        let specificVariants = variants.filter { !containsVagueLanguage($0) }
        return specificVariants.randomElement() ?? variants[0]
    }
    
    /// Generate a distinct "why" explanation when the provided one is too similar to summary
    /// This creates a cause-and-effect explanation focusing on ONE weather factor
    /// Uses CLEAR, SPECIFIC, BODY-SENSATION language (no vague phrases)
    private func generateDistinctWhy(from summary: String, originalWhy: String?, weatherFactor: String = "pressure") -> String {
        let lowerSummary = summary.lowercased()
        
        // Detect which weather factor is mentioned in summary
        var detectedFactor = weatherFactor
        if lowerSummary.contains("pressure") || lowerSummary.contains("barometric") {
            detectedFactor = "pressure"
        } else if lowerSummary.contains("humid") {
            detectedFactor = "humidity"
        } else if lowerSummary.contains("temperat") || lowerSummary.contains("cool") || lowerSummary.contains("warm") || lowerSummary.contains("heat") {
            detectedFactor = "temperature"
        } else if lowerSummary.contains("wind") || lowerSummary.contains("breeze") {
            detectedFactor = "wind"
        }
        
        // Generate cause-and-effect explanations using SPECIFIC body-sensation vocabulary
        // STRICT RULE: Weather NEVER "feels" - only the BODY does
        // Each links ONE weather factor → ONE physical body sensation using ONLY approved vocabulary
        let whyVariants: [String: [String]] = [
            "pressure": [
                "Pressure drops can make the body feel heavy or slow.",
                "Stable pressure can ease tension in sensitive joints.",
                "Rapid pressure changes can make muscles feel stiff or tense.",
                "Gradual pressure shifts can feel draining on sensitive systems.",
                "Low pressure can make movement feel more effortful and tiring.",
                "Steady pressure may ease stiffness in joints."
            ],
            "humidity": [
                "Thick air can make the body feel tiring.",
                "Humid conditions can make movement feel more effortful.",
                "Heavy humidity can drain energy and make the body feel sluggish.",
                "Dense air can make breathing feel more effortful.",
                "Rising humidity can make joints feel stiff.",
                "Moist air can increase sensitivity in the body."
            ],
            "temperature": [
                "Heat can drain energy and make the body feel sluggish.",
                "Cool air can stiffen muscles and increase sensitivity.",
                "Warm temperatures can make movement feel tiring and effortful.",
                "Cooler air may make joints feel stiff or tense.",
                "High heat can feel draining and make the body feel heavy.",
                "Stable temperatures may ease tension in tight muscles."
            ],
            "wind": [
                "Calm air can ease tension in sensitive systems.",
                "Gusty winds can feel draining and tiring on the body.",
                "Stable air may make movement feel less effortful.",
                "Light breezes may help ease stagnant, heavy feelings."
            ]
        ]
        
        let variants = whyVariants[detectedFactor] ?? whyVariants["pressure"]!
        
        // Find a variant that's different from the summary AND uses specific language
        let specificVariants = variants.filter { !containsVagueLanguage($0) && !areTextsTooSimilar(summary, $0) }
        
        if let variant = specificVariants.first {
            return variant
        }
        
        // Fallback: use first variant that's not too similar to summary
        for variant in variants {
            if !areTextsTooSimilar(summary, variant) {
                return variant
            }
        }
        
        // Final fallback with specific body-sensation language
        // STRICT: No vague phrases, only physical body sensations
        return "Weather changes can make the body feel more effortful or tiring."
    }
    
    /// Build a strict Daily Insight string from JSON fields if present, otherwise
    /// fall back to the server-formatted message while enforcing basic sanitization.
    ///
    /// Expected JSON shapes:
    /// {
    ///   "summary": "...",
    ///   "why": "...",
    ///   "comfort_tip": "...",
    ///   "sign_off": "..."
    /// }
    /// or:
    /// {
    ///   "daily_insight": {
    ///     "summary_sentence": "...",
    ///     "why_line": "...",
    ///     "comfort_tip": "...",
    ///     "sign_off": "..."
    ///   }
    /// }
    /// 
    /// - Parameter whyField: The top-level "why" field from InsightResponse (weather explanation, not sign-off)
    private func formattedDailyInsight(from raw: String?, whyField: String? = nil) -> String {
        guard let raw = raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Default, safe daily insight if backend is unavailable
            // Note: Card title already includes "Daily Insight" header, so we don't include it in the body
            // Uses SPECIFIC body-sensation language (no vague phrases)
            // STRICT: Weather never "feels" - only body does
            return """
Weather feels gentle and steady today.

Why: Stable pressure can ease tension in sensitive joints.

Comfort tip: Keep your day flexible.

Move at a pace that feels kind to you.
"""
        }
        
        // Try to interpret the string as JSON carrying structured fields
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            var summary: String?
            var whyLine: String?
            var comfortTip: String?
            var signOff: String?
            
            if let daily = json["daily_insight"] as? [String: Any] {
                summary = daily["summary_sentence"] as? String
                whyLine = daily["why_line"] as? String
                comfortTip = daily["comfort_tip"] as? String
                signOff = daily["sign_off"] as? String
            } else {
                summary = json["summary"] as? String
                whyLine = json["why"] as? String
                comfortTip = json["comfort_tip"] as? String
                signOff = json["sign_off"] as? String
            }
            
            let summaryText = (sanitizeInsightText(filterAppMessages(summary)) ?? summary)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Weather feels gentle and steady today."
            
            // Prioritize whyField (from top-level InsightResponse.why) - this is the weather explanation
            // Fall back to whyLine from JSON if whyField not available
            var whyText: String
            if let whyField = whyField, !whyField.isEmpty {
                whyText = (sanitizeInsightText(filterAppMessages(whyField)) ?? whyField).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                whyText = (sanitizeInsightText(filterAppMessages(whyLine)) ?? whyLine)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "Stable pressure can ease tension in sensitive joints."
            }
            
            // CRITICAL: Detect weather factor for rewriting logic
            let lowerSummary = summaryText.lowercased()
            var weatherFactor = "pressure"
            if lowerSummary.contains("pressure") || lowerSummary.contains("barometric") {
                weatherFactor = "pressure"
            } else if lowerSummary.contains("humid") {
                weatherFactor = "humidity"
            } else if lowerSummary.contains("temperat") || lowerSummary.contains("cool") || lowerSummary.contains("warm") || lowerSummary.contains("heat") {
                weatherFactor = "temperature"
            } else if lowerSummary.contains("wind") || lowerSummary.contains("breeze") {
                weatherFactor = "wind"
            }
            
            // CRITICAL: Validate and rewrite vague "Why" language
            // Replace vague phrases with specific, concrete body sensations
            if containsVagueLanguage(whyText) {
                whyText = rewriteVagueWhy(whyText, weatherFactor: weatherFactor)
            }
            
            // CRITICAL: Ensure summary and why are DISTINCT
            // If they're too similar, generate a distinct why that explains ONE weather factor
            if areTextsTooSimilar(summaryText, whyText) {
                whyText = generateDistinctWhy(from: summaryText, originalWhy: whyText, weatherFactor: weatherFactor)
                
                // Double-check: if still too similar, use a generic distinct explanation with specific language
                if areTextsTooSimilar(summaryText, whyText) {
                    whyText = "The weather pattern today may make the body feel more effortful or tiring."
                }
            }
            
            // Final validation: ensure no vague language made it through
            if containsVagueLanguage(whyText) {
                whyText = rewriteVagueWhy(whyText, weatherFactor: weatherFactor)
            }
            
            var comfortText = (sanitizeInsightText(filterAppMessages(comfortTip)) ?? comfortTip)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var signOffText = (sanitizeInsightText(filterAppMessages(signOff)) ?? signOff)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Move at a pace that feels kind to you."
            
            // Clean text for comparison (remove punctuation, trim whitespace)
            let cleanComfort = comfortText.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
            let cleanSignOff = signOffText.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
            
            // Prevent duplicate: if sign-off is the same as comfort tip, don't add it
            var shouldSkipSignOff = false
            
            if !cleanComfort.isEmpty && !cleanSignOff.isEmpty {
                // Check if they're exactly the same
                if cleanComfort == cleanSignOff {
                    shouldSkipSignOff = true
                }
                // Also check if one contains the other substantially
                else {
                    let shorter = min(cleanComfort.count, cleanSignOff.count)
                    if shorter > 0 {
                        if cleanComfort.contains(cleanSignOff) || cleanSignOff.contains(cleanComfort) {
                            let matchLength = cleanComfort.contains(cleanSignOff) ? cleanSignOff.count : cleanComfort.count
                            // If match is >80% of shorter text, consider it duplicate
                            if Double(matchLength) / Double(shorter) > 0.8 {
                                shouldSkipSignOff = true
                            }
                        }
                    }
                }
            }
            
            // If comfort tip contains the sign-off text, remove it from comfort tip
            if !shouldSkipSignOff {
                let signOffLower = signOffText.lowercased()
                if comfortText.lowercased().contains(signOffLower) {
                    // Remove sign-off text from comfort tip
                    comfortText = comfortText.replacingOccurrences(of: signOffText, with: "", options: [.caseInsensitive])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                }
            }
            
            // If comfort tip is now empty after removing sign-off, restore original
            if comfortText.isEmpty && comfortTip != nil && !comfortTip!.isEmpty && !shouldSkipSignOff {
                comfortText = (sanitizeInsightText(filterAppMessages(comfortTip)) ?? comfortTip)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                // Re-check for duplicates after restoring
                let restoredClean = comfortText.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                if restoredClean == cleanSignOff {
                    shouldSkipSignOff = true
                }
            }
            
            // Build formatted message following exact template:
            // summary
            // 
            // Why: <why>
            // 
            // Comfort tip: <comfort_tip> (if present)
            // 
            // <closing_line> (only if different from comfort tip)
            var lines: [String] = [
                summaryText,
                "",
                "Why: \(whyText)"
            ]
            
            if !comfortText.isEmpty {
                lines.append("")
                lines.append("Comfort tip: \(comfortText)")
            }
            
            // Only add sign-off if it's different from comfort tip AND summary
            if !shouldSkipSignOff && !signOffText.isEmpty {
                let cleanSignOff = signOffText.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                let cleanSummary = summaryText.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                
                // Don't add sign-off if it matches summary
                if cleanSignOff != cleanSummary && !cleanSignOff.contains(cleanSummary) && !cleanSummary.contains(cleanSignOff) {
                    lines.append("")
                    lines.append(signOffText)
                }
            }
            
            return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // If backend returned a plain paragraph (legacy format), reshape it into the locked card layout.
        let baseText = sanitizeInsightText(filterAppMessages(raw) ?? raw) ?? raw
        
        // Naive sentence splitting – good enough for reshaping legacy messages.
        let separators = CharacterSet(charactersIn: ".!?")
        let rawParts = baseText.components(separatedBy: separators)
        let parts = rawParts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let summaryText = (parts.first ?? "Weather feels gentle and steady today.") + "."
        
        // CRITICAL: Detect weather factor for rewriting logic
        let lowerSummary = summaryText.lowercased()
        var weatherFactor = "pressure"
        if lowerSummary.contains("pressure") || lowerSummary.contains("barometric") {
            weatherFactor = "pressure"
        } else if lowerSummary.contains("humid") {
            weatherFactor = "humidity"
        } else if lowerSummary.contains("temperat") || lowerSummary.contains("cool") || lowerSummary.contains("warm") || lowerSummary.contains("heat") {
            weatherFactor = "temperature"
        } else if lowerSummary.contains("wind") || lowerSummary.contains("breeze") {
            weatherFactor = "wind"
        }
        
        // Use whyField if available (weather explanation), otherwise extract from text
        var whyText: String
        if let whyField = whyField, !whyField.isEmpty {
            whyText = (sanitizeInsightText(filterAppMessages(whyField)) ?? whyField).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Extract second sentence as why, but ensure it's different from summary
            let candidateWhy = parts.dropFirst().first ?? "Stable pressure can ease tension in sensitive joints."
            whyText = candidateWhy + "."
            
            // If candidate why is too similar to summary, generate a distinct one
            if areTextsTooSimilar(summaryText, whyText) {
                whyText = generateDistinctWhy(from: summaryText, originalWhy: candidateWhy, weatherFactor: weatherFactor)
            }
        }
        
        // CRITICAL: Validate and rewrite vague "Why" language
        // Replace vague phrases with specific, concrete body sensations
        if containsVagueLanguage(whyText) {
            whyText = rewriteVagueWhy(whyText, weatherFactor: weatherFactor)
        }
        
        // CRITICAL: Final check - ensure summary and why are DISTINCT
        // If still too similar after all processing, force a distinct why
        if areTextsTooSimilar(summaryText, whyText) {
            whyText = generateDistinctWhy(from: summaryText, originalWhy: whyText, weatherFactor: weatherFactor)
            
            // Final fallback if still too similar - use specific body-sensation language
            if areTextsTooSimilar(summaryText, whyText) {
                whyText = "The weather pattern today may make the body feel more effortful or tiring."
            }
        }
        
        // Final validation: ensure no vague language made it through
        if containsVagueLanguage(whyText) {
            whyText = rewriteVagueWhy(whyText, weatherFactor: weatherFactor)
        }
        
        // For legacy text we skip comfort tip and keep a soft, fixed sign-off.
        // But only if it's different from the summary
        let defaultSignOff = "Move at a pace that feels kind to you."
        let signOffText = defaultSignOff
        
        // Build formatted message following exact template:
        // summary
        // 
        // Why: <why>
        // 
        // <closing_line> (only if different from summary)
        var lines: [String] = [
            summaryText,
            "",
            "Why: \(whyText)"
        ]
        
        // Only add sign-off if it's not the same as the summary (avoid duplicates)
        if summaryText.lowercased() != signOffText.lowercased() {
            lines.append("")
            lines.append(signOffText)
        }
        
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Helper function to filter app-specific messages
    private func filterAppMessages(_ text: String?) -> String? {
        guard let text = text, !text.isEmpty else { return text }
        
        var cleaned = text
        
        // Remove emoji and "Daily Insight" header (card title already includes this)
        // Patterns like "☀️ Daily Insight", "Daily Insight:", "☀️ Daily Insight:", etc.
        let headerPatterns = [
            "(?i)☀️\\s*Daily\\s+Insight\\s*:?\\s*",
            "(?i)☀\\s*Daily\\s+Insight\\s*:?\\s*",
            "(?i)Daily\\s+Insight\\s*:?\\s*",
            "(?i)^☀️\\s*",
            "(?i)^☀\\s*"
        ]
        
        for pattern in headerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        let lowercased = cleaned.lowercased()
        
        // Check for app-specific message indicators
        let filterPhrases = [
            "take one minute",
            "jot how you feel",
            "jot down",
            "update in Flare",
            "update Flare",
            "drop a quick update",
            "teach the app",
            "what matters most",
            "those notes teach",
            "so the guidance stays personal",
            "log how you feel",
            "log your symptoms",
            "logging symptoms"
        ]
        
        // Check if text contains any filter phrases
        for phrase in filterPhrases {
            if lowercased.contains(phrase) {
                // Check if it's combined with app references
                if lowercased.contains("flare") || lowercased.contains("app") || lowercased.contains("the app") {
                    // Filter out this text
                    return nil
                }
            }
        }
        
        // Also check for keyword combinations
        let hasJot = lowercased.contains("jot")
        let hasTeach = lowercased.contains("teach") || lowercased.contains("notes teach") || lowercased.contains("those notes")
        let hasAppReference = lowercased.contains("flare") || lowercased.contains("app") || lowercased.contains("the app")
        let hasMattersMost = lowercased.contains("matters most")
        let hasOneMinute = lowercased.contains("one minute") || lowercased.contains("one minute later")
        let hasLog = lowercased.contains("log") || lowercased.contains("logging")
        
        // If text contains app usage instructions, filter it
        // More aggressive: if any combination of these keywords appears together, filter it
        if hasJot && hasAppReference {
            return nil
        }
        if hasTeach && hasAppReference {
            return nil
        }
        if hasMattersMost && hasAppReference {
            return nil
        }
        if hasOneMinute && hasAppReference {
            return nil
        }
        if hasOneMinute && hasJot {
            return nil
        }
        if hasLog && hasAppReference {
            return nil
        }
        
        return text
    }
    
    /// Remove source citations from text (e.g., "Source: ...", "Sources: ...")
    /// Sources should be displayed separately at the bottom of the card, not in the summary text
    private func removeSourceCitations(_ text: String?) -> String? {
        guard let text = text, !text.isEmpty else { return text }
        
        var cleaned = text
        
        // Remove common source citation patterns
        // Match patterns like "Source:", "Sources:", "Source -", "Sources -", etc.
        let sourcePatterns = [
            "(?i)\\s*Source:\\s*[^\\n]*",
            "(?i)\\s*Sources:\\s*[^\\n]*",
            "(?i)\\s*Source\\s+-\\s*[^\\n]*",
            "(?i)\\s*Sources\\s+-\\s*[^\\n]*",
            "(?i)\\s*\\[Source:[^\\]]*\\]",
            "(?i)\\s*\\(Source:[^\\)]*\\)"
        ]
        
        for pattern in sourcePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        // Also remove if source appears at the end of the text (common pattern)
        let lines = cleaned.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                let lowerLine = line.lowercased()
                return !lowerLine.hasPrefix("source") && !lowerLine.isEmpty
            }
        
        cleaned = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? text : cleaned // Return original if we removed everything
    }
    
    /// Apply and format weekly insight according to strict requirements:
    /// - One short summary paragraph (no numbers, jargon, medical claims)
    /// - Exactly 7 weekday lines starting from tomorrow: `<Weekday> — <weather> — <body feel>`
    /// - Strip all markdown, bullets, HTML, numbers, technical terms
    private func applyWeeklyInsight(_ insight: String?) {
        guard let insight = insight, !insight.isEmpty else {
            weeklyInsightSummary = nil
            weeklyInsightDays = []
            weeklyForecastInsight = nil
            return
        }
        
        // Try to parse as JSON first
        if let data = insight.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // Parse weekly summary
            let summaryRaw = json["weekly_summary"] as? String
            let filteredSummary = filterAppMessages(summaryRaw) ?? summaryRaw
            // Remove source citations from summary - sources are displayed separately at the bottom
            let summaryWithoutSources = removeSourceCitations(filteredSummary) ?? filteredSummary
            // Fix broken templates caused by missing/null values (e.g., "temps ranging from to")
            let fixedSummary = fixBrokenWeeklySummaryTemplate(summaryWithoutSources) ?? summaryWithoutSources
            let sanitizedSummary = sanitizeInsightText(fixedSummary) ?? fixedSummary ?? ""
            
            // Ensure summary is a single SHORT paragraph (first sentence only, no truncation)
            var finalSummary = sanitizedSummary
            let sentences = finalSummary.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            if !sentences.isEmpty {
                // Use first sentence only for brevity - show the complete sentence, no truncation
                finalSummary = sentences.first! + "."
            }
            
            weeklyInsightSummary = finalSummary.isEmpty ? nil : finalSummary
            weeklyForecastInsight = finalSummary.isEmpty ? nil : finalSummary
            
            // Parse daily breakdown
            var parsedDays: [WeeklyInsightDay] = []
            let weekdayLabels = getNextSevenWeekdays()
            
            if let list = json["daily_breakdown"] as? [[String: Any]] {
                // Array format: [{"label": "Sat", "insight": "pattern — body feel"}]
                for (index, item) in list.enumerated() {
                    guard index < 7 else { break }
                    
                    let label = item["label"] as? String ?? (index < weekdayLabels.count ? weekdayLabels[index] : "")
                    let detailRaw = item["insight"] as? String ?? ""
                    let filteredDetail = filterAppMessages(detailRaw) ?? detailRaw
                    let sanitizedDetail = sanitizeInsightText(filteredDetail) ?? filteredDetail
                    
                    // Ensure format is exactly: <weather> — <body feel> (two em-dashes)
                    let formattedDetail = formatWeeklyDayDetail(sanitizedDetail)
                    
                    if !label.isEmpty && !formattedDetail.isEmpty {
                        parsedDays.append(WeeklyInsightDay(label: label, detail: formattedDetail))
                    }
                }
            } else if let dict = json["daily_breakdown"] as? [String: Any] {
                // Dictionary format: {"Sat": "pattern — body feel", ...}
                for weekdayLabel in weekdayLabels {
                    if let detailRaw = dict[weekdayLabel] as? String {
                        let filteredDetail = filterAppMessages(detailRaw) ?? detailRaw
                        let sanitizedDetail = sanitizeInsightText(filteredDetail) ?? filteredDetail
                        let formattedDetail = formatWeeklyDayDetail(sanitizedDetail)
                        
                        if !formattedDetail.isEmpty {
                            parsedDays.append(WeeklyInsightDay(label: weekdayLabel, detail: formattedDetail))
                        }
                    }
                }
            }
            
            // Ensure exactly 7 days, using default placeholders if needed
            while parsedDays.count < 7 {
                let index = parsedDays.count
                if index < weekdayLabels.count {
                    parsedDays.append(WeeklyInsightDay(
                        label: weekdayLabels[index],
                        detail: "low flare risk"
                    ))
                } else {
                    break
                }
            }
            
            weeklyInsightDays = Array(parsedDays.prefix(7))
            return
        }
        
        // Legacy string format: extract summary and generate weekday bullets
        let filtered = filterAppMessages(insight) ?? insight
        // Remove source citations from summary - sources are displayed separately at the bottom
        let filteredWithoutSources = removeSourceCitations(filtered) ?? filtered ?? ""
        // Fix broken templates caused by missing/null values (e.g., "temps ranging from to")
        let fixedSummary = fixBrokenWeeklySummaryTemplate(filteredWithoutSources) ?? filteredWithoutSources
        let sanitized = sanitizeInsightText(fixedSummary) ?? fixedSummary
        
        // Check if text already has day lines (format: "Sat — ...")
        let lines = sanitized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var summaryLine: String = ""
        var bulletDays: [WeeklyInsightDay] = []
        let weekdayLabels = getNextSevenWeekdays()
        
        if lines.count > 1 {
            // Has multiple lines - first line is summary, rest are day lines
            summaryLine = sanitizeInsightText(lines.first) ?? lines.first ?? ""
            
            // Try to parse existing day lines
            var dayIndex = 0
            for line in lines.dropFirst() {
                guard dayIndex < 7 else { break }
                
                // Try to parse format: "Sat — weather — body feel" or "Sat — combined"
                let parts = line.split(separator: "—", maxSplits: 2, omittingEmptySubsequences: true)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                if parts.count >= 2 {
                    let label = parts[0]
                    let detail = parts.dropFirst().joined(separator: " — ")
                    let formattedDetail = formatWeeklyDayDetail(detail)
                    
                    if !label.isEmpty && !formattedDetail.isEmpty {
                        bulletDays.append(WeeklyInsightDay(label: label, detail: formattedDetail))
                        dayIndex += 1
                    }
                }
            }
        } else {
            // Single paragraph - extract first sentence as SHORT summary
            let sentences = sanitized.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            if let firstSentence = sentences.first {
                // Use first sentence only - show complete sentence, no truncation
                summaryLine = firstSentence + "."
            } else {
                // If no sentence detected, use the whole text as-is (should be short already)
                summaryLine = sanitized
            }
            
            // Try to extract day-specific information from the remaining text
            // Look for patterns like "Tuesday and Thursday", "mid-week", "weekend", etc.
            let remainingText = sentences.count > 1 ? Array(sentences.dropFirst()).joined(separator: ". ") : ""
            
            // Try to split remaining content into chunks for different days
            // or use varied patterns based on content
            var dayPatterns: [String] = []
            
            if !remainingText.isEmpty {
                // Split remaining text by sentences and try to distribute across days
                let _ = remainingText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // Use varied body-feel phrases for different days
                let bodyFeelVariants = [
                    "may feel easier on the body",
                    "can feel steadier",
                    "may feel lighter",
                    "could feel more comfortable",
                    "often feels gentler",
                    "may feel more balanced",
                    "can feel supportive"
                ]
                
                // Distribute sentences across days, or use pattern-based assignment
                for (index, weekday) in weekdayLabels.enumerated() {
                    var weatherPattern = "steady pattern"
                    let bodyFeel = bodyFeelVariants[index % bodyFeelVariants.count]
                    
                    // Try to extract day-specific mentions from text
                    let lowerText = remainingText.lowercased()
                    let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
                    let dayAbbrevs = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
                    
                    // Check if this weekday is mentioned in the text
                    let weekdayName = index < dayNames.count ? dayNames[index] : weekday.lowercased()
                    let weekdayLower = weekdayName.lowercased()
                    let dayAbbrev = index < dayAbbrevs.count ? dayAbbrevs[index] : weekday.lowercased()
                    
                    if lowerText.contains(weekdayLower) || lowerText.contains(dayAbbrev) {
                        // Try to extract context around this day mention
                        if let dayRange = lowerText.range(of: weekdayLower) ?? lowerText.range(of: dayAbbrev) {
                            let contextStart = lowerText.index(max(lowerText.startIndex, dayRange.lowerBound), offsetBy: -50, limitedBy: lowerText.startIndex) ?? lowerText.startIndex
                            let contextEnd = lowerText.index(min(lowerText.endIndex, dayRange.upperBound), offsetBy: 100, limitedBy: lowerText.endIndex) ?? lowerText.endIndex
                            let context = String(lowerText[contextStart..<contextEnd])
                            
                            // Extract weather patterns from context
                            if context.contains("cooler") || context.contains("cool") {
                                weatherPattern = "cooler air"
                            } else if context.contains("warmer") || context.contains("warm") {
                                weatherPattern = "warmer air"
                            } else if context.contains("humid") {
                                weatherPattern = "rising humidity"
                            } else if context.contains("pressure") || context.contains("shift") {
                                weatherPattern = "pressure shift"
                            } else if context.contains("calm") || context.contains("stable") {
                                weatherPattern = "calm pattern"
                            }
                        }
                    }
                    
                    // Create descriptive text that may include em-dash or be plain
                    // Vary the patterns more - don't use the same "gentle and mild air" for every day
                    var variedPattern = weatherPattern
                    
                    // Vary patterns based on day index to avoid repetition
                    let patternVariants = [
                        (0...1): ["cooler air", "mild air", "gentle air"],
                        (2...3): ["steady pressure", "calm conditions", "stable pattern"],
                        (4...5): ["light humidity", "gentle breeze", "mild warmth"],
                        (6...6): ["calm pattern", "steady trend", "stable conditions"]
                    ]
                    
                    for (range, variants) in patternVariants {
                        if range.contains(index) {
                            let variantIndex = index % variants.count
                            if variantIndex < variants.count {
                                variedPattern = variants[variantIndex]
                            }
                            break
                        }
                    }
                    
                    if variedPattern == "steady pattern" || weatherPattern == "steady pattern" {
                        dayPatterns.append("Stable conditions \(bodyFeel).")
                    } else {
                        dayPatterns.append("\(capitalizeFirstLetter(variedPattern)) — \(bodyFeel).")
                    }
                }
            } else {
                // No remaining text - use varied default descriptive patterns
                let defaultDescriptions = [
                    "Stable morning pressure keeps things moderate.",
                    "Humidity rises slightly — watch for light stiffness.",
                    "Calm conditions often feel easier on the body.",
                    "Warmer air may feel lighter.",
                    "Gentle shifts may feel more comfortable.",
                    "Steady pattern keeps things balanced.",
                    "Stable trend feels supportive."
                ]
                
                for (index, _) in weekdayLabels.enumerated() {
                    let description = defaultDescriptions[index % defaultDescriptions.count]
                    dayPatterns.append(description)
                }
            }
            
            // Create weekday bullets with varied patterns
            // Apply formatting to convert low-risk days to "low flare risk"
            for (index, weekday) in weekdayLabels.enumerated() {
                let rawDetail = index < dayPatterns.count ? dayPatterns[index] : "Stable conditions may feel easier on the body."
                let formattedDetail = formatWeeklyDayDetail(rawDetail)
                bulletDays.append(WeeklyInsightDay(label: weekday, detail: formattedDetail))
            }
        }
        
        // Ensure exactly 7 weekday bullets (should already have 7, but safety check)
        // These are all low-risk defaults, so format them as "low flare risk"
        while bulletDays.count < 7 {
            let index = bulletDays.count
            if index < weekdayLabels.count {
                // These are all low-risk defaults, so they'll be formatted to "low flare risk"
                let defaultDescriptions = [
                    "Stable conditions may feel easier on the body.",
                    "Calm conditions can feel steadier.",
                    "Steady pattern may feel lighter.",
                    "Stable trend could feel more comfortable.",
                    "Calm pressure often feels gentler.",
                    "Steady conditions may feel more balanced.",
                    "Stable pattern can feel supportive."
                ]
                let description = defaultDescriptions[index % defaultDescriptions.count]
                let formattedDetail = formatWeeklyDayDetail(description)
                bulletDays.append(WeeklyInsightDay(
                    label: weekdayLabels[index],
                    detail: formattedDetail
                ))
            } else {
                break
            }
        }
        
        weeklyInsightSummary = summaryLine.isEmpty ? nil : summaryLine
        weeklyInsightDays = Array(bulletDays.prefix(7))
        weeklyForecastInsight = summaryLine.isEmpty ? nil : summaryLine
    }
    
    /// Check if a day detail indicates low flare risk
    /// Returns true if the detail suggests low risk (e.g., "steady", "calm", "low risk", "easier on the body")
    private func isLowFlareRisk(_ detail: String) -> Bool {
        let lowerText = detail.lowercased()
        
        // First check for explicit low risk indicators
        let explicitLowRiskPatterns = [
            "low flare risk",
            "low risk",
            "steady pattern",
            "steady conditions",
            "stable pattern",
            "stable conditions",
            "stable trend",
            "calm pattern",
            "calm conditions",
            "calm pressure"
        ]
        
        for pattern in explicitLowRiskPatterns {
            if lowerText.contains(pattern) {
                return true
            }
        }
        
        // Check for moderate/high risk indicators - if found, it's NOT low risk
        let higherRiskPatterns = [
            "moderate",
            "high",
            "increased",
            "rising",
            "pressure shift",
            "pressure drop",
            "pressure rise",
            "humidity rises",
            "humidity increases",
            "temperature shift",
            "wind",
            "storm",
            "front",
            "watch for",
            "stiff",
            "tiring",
            "draining",
            "heavy",
            "sluggish",
            "tense",
            "sensitive",
            "effortful"
        ]
        
        for pattern in higherRiskPatterns {
            if lowerText.contains(pattern) {
                return false
            }
        }
        
        // Check for simple positive/low-risk phrases that indicate low risk
        let positiveLowRiskPhrases = [
            "easier on the body",
            "may feel easier",
            "can feel steadier",
            "may feel lighter",
            "feels supportive",
            "feels balanced",
            "keeps things balanced",
            "keeps things moderate",
            "gentle"
        ]
        
        // Check for "gentle and mild" patterns - these are low risk even with weather detail
        if lowerText.contains("gentle and mild") || (lowerText.contains("gentle") && lowerText.contains("mild")) {
            // If it's just gentle/mild with positive body-feel descriptions, it's low risk
            let hasRiskIndicators = lowerText.contains("moderate") || lowerText.contains("high") || 
                                    lowerText.contains("stiff") || lowerText.contains("tiring") || 
                                    lowerText.contains("draining") || lowerText.contains("heavy") ||
                                    lowerText.contains("tense") || lowerText.contains("effortful")
            if !hasRiskIndicators {
                return true
            }
        }
        
        // Only return true for low risk if the text is SIMPLE and POSITIVE
        // Complex descriptions with weather details suggest moderate/high risk
        // BUT: gentle/mild patterns are OK even with weather detail (handled above)
        let hasWeatherDetail = lowerText.contains("—") || lowerText.contains("-") || lowerText.contains("humidity") || lowerText.contains("temperature") || lowerText.contains("pressure")
        
        for phrase in positiveLowRiskPhrases {
            if lowerText.contains(phrase) && !hasWeatherDetail {
                return true
            }
        }
        
        // Default to showing descriptive text (not low risk) if uncertain
        return false
    }
    
    /// Format a weekly day detail - show "low flare risk" for low risk days, descriptive blurbs for moderate/high risk
    private func formatWeeklyDayDetail(_ detail: String) -> String {
        var text = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any existing bullet markers
        text = text.replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
        
        if text.isEmpty {
            // Default fallback - treat as low risk
            return "low flare risk"
        }
        
        // Check if this indicates low flare risk
        if isLowFlareRisk(text) {
            return "low flare risk"
        }
        
        // For moderate/high risk days, return the descriptive text as-is
        return text
    }
    
    // Backend URL - configurable via environment variable or Info.plist
    // For local testing, use: "http://localhost:8000"
    // For production, use: "https://flareweather-production.up.railway.app"
    private var baseURL: String {
        // First try to get from environment variable (set in Xcode scheme)
        if let url = ProcessInfo.processInfo.environment["BACKEND_URL"], !url.isEmpty {
            print("✅ AIInsightsService: Backend URL found in environment variable: \(url)")
            return url
        }
        
        // Second, try to get from Info.plist
        if let url = Bundle.main.infoDictionary?["BackendURL"] as? String, !url.isEmpty {
            print("✅ AIInsightsService: Backend URL found in Info.plist: \(url)")
            return url
        }
        
        // Default: use production Railway URL
        let defaultURL = "https://flareweather-production.up.railway.app"
        print("✅ AIInsightsService: Using production backend URL: \(defaultURL)")
        return defaultURL
    }
    
    // Request tracking to ignore stale responses
    private var currentRequestId: UUID? = nil
    private var task: Task<Void, Never>? = nil
    
    // Session caching - track analysis inputs to avoid redundant API calls
    private var lastAnalysisInputs: String? = nil
    private var hasAnalysisInSession = false
    private var lastAnalysisId: String? = nil
    private var lastDiagnoses: [String]? = nil
    private var lastLocationName: String? = nil
    private var lastSuccessfulInsightMessage: String? = nil
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    func analyze(symptoms: [SymptomEntryPayload], weather: [WeatherSnapshotPayload], hourlyForecast: [WeatherSnapshotPayload]? = nil, weeklyForecast: [WeatherSnapshotPayload]? = nil, diagnoses: [String]? = nil) async {
        // Cancel any existing request
        task?.cancel()
        
        // Create new request ID
        let requestId = UUID()
        currentRequestId = requestId
        lastAnalysisId = nil
        lastDiagnoses = diagnoses
        
        // Set loading state (but don't clear previous data yet - keep it visible while loading)
        isLoading = true
        // Only clear data if we don't have cached results
        if !hasAnalysisInSession {
            risk = nil
            forecast = nil
            why = nil
            insightMessage = "Analyzing weather patterns…"
            supportNote = nil
            pressureAlert = nil
            alertSeverity = nil
            personalizationScore = nil
            personalAnecdote = nil
            behaviorPrompt = nil
            weeklyInsightSources = []
            lastSuccessfulInsightMessage = nil
        } else {
            // Keep existing data visible while new analysis loads
            insightMessage = "Updating analysis…"
        }
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/analyze") else {
            print("❌ Invalid URL: \(baseURL)/analyze")
            isLoading = false
            return
        }
        
        let requestBody = CorrelationRequest(
            symptoms: symptoms,
            weather: weather,
            hourly_forecast: hourlyForecast,
            weekly_forecast: weeklyForecast,
            user_id: nil,
            diagnoses: diagnoses
        )
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            print("❌ Failed to encode request body")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        // Increase timeout for analyze endpoint since it calls OpenAI API which can take 20-30 seconds
        request.timeoutInterval = 60.0  // 60 second timeout for AI analysis
        
        print("📤 Sending request to: \(url) [Request ID: \(requestId)]")
        
        // Create task to track this request
        task = Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check if this request was cancelled or superseded
                guard !Task.isCancelled, currentRequestId == requestId else {
                    print("⏭️  Request \(requestId) was cancelled or superseded")
                    return
                }
                
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                print("📥 Response status: \(http.statusCode) [Request ID: \(requestId)]")
                
                guard (200..<300).contains(http.statusCode) else {
                    // Try to parse error response for better error messages
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response (\(http.statusCode)): \(responseString)")
                        
                        // Try to extract error detail from JSON response
                        if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorDetail = errorJson["detail"] as? String {
                            print("❌ Error detail: \(errorDetail)")
                            throw NSError(domain: "AIInsightsService", code: http.statusCode, userInfo: [
                                NSLocalizedDescriptionKey: "Backend error: \(errorDetail)"
                            ])
                        }
                    }
                    throw NSError(domain: "AIInsightsService", code: http.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Backend returned status \(http.statusCode)"
                    ])
                }
                
                let decoded = try JSONDecoder().decode(InsightResponse.self, from: data)
                
                // Double-check this is still the current request
                guard currentRequestId == requestId else {
                    print("⏭️  Response for request \(requestId) ignored (newer request in progress)")
                    return
                }
                
                // Update UI only if this is the latest request
                // Filter app-specific messages from all text fields before displaying.
                // Daily insight is always normalized into the locked card format here.
                // Use decoded.why for the "Why" section (weather explanation), not a sign-off
                insightMessage = formattedDailyInsight(from: decoded.ai_message, whyField: decoded.why)
                citations = decoded.citations ?? []
                risk = decoded.risk
                forecast = decoded.forecast
                why = decoded.why
                weeklyInsightSources = decoded.weekly_insight_sources ?? []
                print("📚 Weekly insight sources: \(weeklyInsightSources.count) sources")
                if !weeklyInsightSources.isEmpty {
                    for (index, source) in weeklyInsightSources.enumerated() {
                        print("  [\(index)] \(source)")
                    }
                }
                applyWeeklyInsight(decoded.weekly_forecast_insight)
                
                // Filter app-specific messages from these fields before displaying
                supportNote = filterAppMessages(decoded.support_note)
                personalAnecdote = filterAppMessages(decoded.personal_anecdote)
                behaviorPrompt = filterAppMessages(decoded.behavior_prompt)
                
                pressureAlert = decoded.pressure_alert
                alertSeverity = decoded.alert_severity
                personalizationScore = decoded.personalization_score
                isLoading = false
                lastAnalysisTime = Date()
                lastAnalysisId = requestId.uuidString
                lastSuccessfulInsightMessage = decoded.ai_message
                
                print("✅ Success! Received insight [Request ID: \(requestId)]")
                print("📊 Risk: \(risk ?? "Unknown")")
                print("📋 Forecast: \(forecast ?? "None")")
            } catch {
                // Only update error if this is still the current request
                guard currentRequestId == requestId else {
                    print("⏭️  Error for request \(requestId) ignored (newer request in progress)")
                    return
                }
                
                print("❌ Error: \(error.localizedDescription) [Request ID: \(requestId)]")
                print("❌ Backend URL: \(baseURL)")
                print("❌ Error type: \(type(of: error))")
                if let nsError = error as NSError? {
                    print("❌ Error domain: \(nsError.domain)")
                    print("❌ Error code: \(nsError.code)")
                    print("❌ Error userInfo: \(nsError.userInfo)")
                }
                errorMessage = error.localizedDescription
                
                if let cachedInsight = lastSuccessfulInsightMessage, hasAnalysisInSession, !cachedInsight.isEmpty {
                    // Restore the last successful insight so users keep helpful guidance
                    insightMessage = cachedInsight
                    print("ℹ️  Restoring last successful insight for user experience.")
                    isLoading = false
                } else {
                    // Show a helpful message that indicates the backend is having issues
                    // But make it user-friendly
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("backend error") || errorDescription.contains("500") || errorDescription.contains("internal server error") {
                        insightMessage = "We're having trouble connecting to our analysis service right now. Please try again in a moment."
                    } else if errorDescription.contains("timeout") || errorDescription.contains("timed out") {
                        insightMessage = "The analysis is taking longer than expected. This can happen when our AI service is processing complex weather patterns. Please try again in a moment."
                    } else if errorDescription.contains("network") || errorDescription.contains("connection") {
                        insightMessage = "Please check your internet connection and try again."
                    } else {
                        insightMessage = "Unable to analyze weather patterns at this time. Please try again later."
                    }
                    print("⚠️  No cached insight available. Showing error message: \(insightMessage)")
                    isLoading = false
                }
            }
        }
        
        await task?.value
    }
    
    func analyzeWithRealData(context: NSManagedObjectContext? = nil, weatherService: WeatherService? = nil, userProfile: UserProfile? = nil) async {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var symptoms: [SymptomEntryPayload] = []
        var weather: [WeatherSnapshotPayload] = []
        
        // Try to fetch real symptoms from CoreData
        if let context = context {
            let request: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
            // Get last 30 days of symptoms
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            request.predicate = NSPredicate(format: "timestamp >= %@", thirtyDaysAgo as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.timestamp, ascending: true)]
            
            do {
                let symptomEntries = try context.fetch(request)
                print("📊 Found \(symptomEntries.count) symptom entries in CoreData")
                
                for entry in symptomEntries {
                    if let timestamp = entry.timestamp,
                       let symptomType = entry.symptomType {
                        symptoms.append(SymptomEntryPayload(
                            timestamp: formatter.string(from: timestamp),
                            symptom_type: symptomType,
                            severity: Int(entry.severity)
                        ))
                    }
                }
            } catch {
                print("❌ Error fetching symptoms: \(error)")
            }
        }
        
        // If no real symptoms, use mock data for testing
        if symptoms.isEmpty {
            print("⚠️  No symptoms found in CoreData, using mock data")
            let now = Date()
            symptoms = [
                SymptomEntryPayload(
                    timestamp: formatter.string(from: now.addingTimeInterval(-3600 * 2)),
                    symptom_type: "Headache",
                    severity: 8
                ),
                SymptomEntryPayload(
                    timestamp: formatter.string(from: now.addingTimeInterval(-3600)),
                    symptom_type: "Headache",
                    severity: 6
                )
            ]
        }
        
        // Try to get real weather data
        if let weatherService = weatherService, let weatherData = weatherService.weatherData {
            print("✅ Using real weather data: \(weatherData.temperature)°C, \(weatherData.humidity)% humidity, \(weatherData.pressure) hPa")
            // Use current weather data and create a snapshot for each symptom
            for symptom in symptoms {
                weather.append(WeatherSnapshotPayload(
                    timestamp: symptom.timestamp,
                    temperature: weatherData.temperature,
                    humidity: weatherData.humidity,
                    pressure: weatherData.pressure,
                    wind: weatherData.windSpeed
                ))
            }
            lastLocationName = weatherData.location ?? UserDefaults.standard.string(forKey: "manualLocation")
        } else {
            print("⚠️  WeatherService or weatherData is nil")
            if lastLocationName == nil {
                lastLocationName = UserDefaults.standard.string(forKey: "manualLocation")
            }
        }
        
        // If no weather data, use mock data
        if weather.isEmpty {
            print("⚠️  No weather data available, using mock data")
            for symptom in symptoms {
                weather.append(WeatherSnapshotPayload(
                    timestamp: symptom.timestamp,
                    temperature: 18.5,
                    humidity: 80,
                    pressure: 1007,
                    wind: 15
                ))
            }
        }
        
        print("📤 Sending \(symptoms.count) symptoms and \(weather.count) weather snapshots to backend")
        // Get user diagnoses if available
        let diagnoses: [String]? = {
            if let diagnosesArray = userProfile?.value(forKey: "diagnoses") as? NSArray {
                return diagnosesArray as? [String]
            }
            return nil
        }()
        if let diagnoses = diagnoses, !diagnoses.isEmpty {
            print("🏥 Including diagnoses: \(diagnoses.joined(separator: ", "))")
        }
        
        await analyze(symptoms: symptoms, weather: weather, diagnoses: diagnoses)
        lastAnalysisTime = Date()
    }
    
    // New function for weather-only analysis (no symptoms)
    func analyzeWithWeatherOnly(weatherService: WeatherService? = nil, userProfile: UserProfile? = nil, force: Bool = false) async {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var weather: [WeatherSnapshotPayload] = []
        var hourlyForecast: [WeatherSnapshotPayload] = []
        
        // Get current weather data
        var currentWeatherData: WeatherData? = nil
        if let weatherService = weatherService, let weatherData = weatherService.weatherData {
            print("✅ Using real weather data: \(weatherData.temperature)°C, \(weatherData.humidity)% humidity, \(weatherData.pressure) hPa")
            currentWeatherData = weatherData
            lastLocationName = weatherData.location ?? UserDefaults.standard.string(forKey: "manualLocation")
            // Create a single weather snapshot for current conditions
            weather.append(WeatherSnapshotPayload(
                timestamp: formatter.string(from: Date()),
                temperature: weatherData.temperature,
                humidity: weatherData.humidity,
                pressure: weatherData.pressure,
                wind: weatherData.windSpeed
            ))
        } else {
            print("⚠️  No weather data available, using mock data")
            weather.append(WeatherSnapshotPayload(
                timestamp: formatter.string(from: Date()),
                temperature: 18.5,
                humidity: 80,
                pressure: 1007,
                wind: 15
            ))
            if lastLocationName == nil {
                lastLocationName = UserDefaults.standard.string(forKey: "manualLocation")
            }
        }
        
        // Get hourly forecast data if available
        var forecastData: [HourlyForecast] = []
        if let weatherService = weatherService {
            forecastData = weatherService.hourlyForecast
            for hourForecast in forecastData {
                hourlyForecast.append(WeatherSnapshotPayload(
                    timestamp: formatter.string(from: hourForecast.time),
                    temperature: hourForecast.temperature,
                    humidity: hourForecast.humidity,
                    pressure: hourForecast.pressure,
                    wind: hourForecast.windSpeed
                ))
            }
            print("📊 Prepared \(hourlyForecast.count) hourly forecast points for AI analysis")
        }
        
        // Get weekly forecast data if available
        var weeklyForecast: [WeatherSnapshotPayload] = []
        if let weatherService = weatherService {
            let weeklyForecastData = weatherService.weeklyForecast
            for dayForecast in weeklyForecastData {
                weeklyForecast.append(WeatherSnapshotPayload(
                    timestamp: formatter.string(from: dayForecast.date),
                    temperature: (dayForecast.highTemp + dayForecast.lowTemp) / 2, // Use average temp
                    humidity: dayForecast.humidity,
                    pressure: dayForecast.pressure,
                    wind: 0 // Wind not stored in DailyForecast
                ))
            }
            print("📊 Prepared \(weeklyForecast.count) daily forecast points for weekly insight")
        }
        
        // Get user diagnoses if available
        let diagnoses: [String]? = {
            if let diagnosesArray = userProfile?.value(forKey: "diagnoses") as? NSArray {
                return diagnosesArray as? [String]
            }
            return nil
        }()
        lastDiagnoses = diagnoses
        
        // Create a hash of the analysis inputs to detect changes
        let analysisInputsHash = createAnalysisInputsHash(
            weather: currentWeatherData,
            hourlyForecast: forecastData,
            weeklyForecast: weatherService?.weeklyForecast ?? [],
            diagnoses: diagnoses
        )
        
        // Check if inputs have changed or if this is the first analysis in the session
        if !force, let lastHash = lastAnalysisInputs, lastHash == analysisInputsHash, hasAnalysisInSession {
            print("⏭️  Analysis inputs unchanged, skipping API call")
            print("   Last hash: \(lastHash)")
            print("   Current hash: \(analysisInputsHash)")
            return
        }
        
        print("🔄 Analysis inputs changed or first analysis, triggering new analysis")
        print("   Last hash: \(lastAnalysisInputs ?? "none")")
        print("   Current hash: \(analysisInputsHash)")
        lastAnalysisInputs = analysisInputsHash
        hasAnalysisInSession = true
        
        // Send request with empty symptoms array, hourly forecast, and weekly forecast
        await analyze(
            symptoms: [],
            weather: weather,
            hourlyForecast: hourlyForecast.isEmpty ? nil : hourlyForecast,
            weeklyForecast: weeklyForecast.isEmpty ? nil : weeklyForecast,
            diagnoses: diagnoses
        )
        lastAnalysisTime = Date()
    }
    
    // Create a hash of analysis inputs to detect changes
    private func createAnalysisInputsHash(weather: WeatherData?, hourlyForecast: [HourlyForecast], weeklyForecast: [DailyForecast], diagnoses: [String]?) -> String {
        var components: [String] = []
        
        // Add current weather data (rounded to detect meaningful changes)
        // Use more aggressive rounding to avoid tiny fluctuations triggering new analysis
        if let weather = weather {
            // Round to whole numbers to avoid tiny decimal differences
            let temp = round(weather.temperature)
            let humidity = round(weather.humidity)
            let pressure = round(weather.pressure)
            let wind = round(weather.windSpeed)
            components.append("W:\(String(format: "%.0f", temp))_\(String(format: "%.0f", humidity))_\(String(format: "%.0f", pressure))_\(String(format: "%.0f", wind))")
        } else {
            components.append("W:none")
        }
        
        // Add hourly forecast summary (first 8 hours for key changes)
        // Track pressure changes which are most relevant for symptom triggers
        if hourlyForecast.count > 0 {
            let keyHours = Array(hourlyForecast.prefix(8))
            var forecastString = "F:"
            for hour in keyHours {
                // Round pressure to whole numbers
                let roundedPressure = round(hour.pressure)
                forecastString += "\(String(format: "%.0f", roundedPressure))_"
            }
            components.append(forecastString)
        } else {
            components.append("F:none")
        }
        
        // Add weekly forecast summary (first 3 days for key changes)
        if weeklyForecast.count > 0 {
            let keyDays = Array(weeklyForecast.prefix(3))
            var weeklyString = "WK:"
            for day in keyDays {
                // Round pressure to whole numbers
                let roundedPressure = round(day.pressure)
                weeklyString += "\(String(format: "%.0f", roundedPressure))_"
            }
            components.append(weeklyString)
        } else {
            components.append("WK:none")
        }
        
        // Add diagnoses (sorted for consistent hash)
        if let diagnoses = diagnoses, !diagnoses.isEmpty {
            components.append("D:\(diagnoses.sorted().joined(separator: ","))")
        } else {
            components.append("D:none")
        }
        
        return components.joined(separator: "|")
    }
    
    func submitFeedback(isHelpful: Bool) async {
        guard hasAnalysisInSession else {
            print("ℹ️ Feedback ignored: no analysis in session")
            return
        }
        guard let url = URL(string: "\(baseURL)/feedback") else {
            print("❌ Invalid feedback URL")
            return
        }
        let payload = FeedbackRequestPayload(
            was_helpful: isHelpful,
            analysis_id: lastAnalysisId,
            analysis_hash: lastAnalysisInputs,
            user_id: nil,
            risk: risk,
            forecast: forecast,
            why: why ?? insightMessage,
            support_note: supportNote,
            citations: citations,
            diagnoses: lastDiagnoses,
            location: lastLocationName,
            app_version: appVersion,
            pressure_alert: pressureAlert,
            alert_severity: alertSeverity,
            personalization_score: personalizationScore,
            personal_anecdote: personalAnecdote,
            behavior_prompt: behaviorPrompt
        )
        guard let data = try? JSONEncoder().encode(payload) else {
            print("❌ Failed to encode feedback payload")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: responseData, encoding: .utf8) ?? "<no body>"
                print("❌ Feedback submission failed with status \(http.statusCode): \(body)")
                return
            }
            if let decoded = try? JSONDecoder().decode(FeedbackResponsePayload.self, from: responseData) {
                print("📝 Feedback submitted (id: \(decoded.feedback_id), helpful: \(isHelpful))")
            } else {
                print("ℹ️ Feedback submitted but response decoding failed")
            }
        } catch {
            print("❌ Feedback submission error: \(error.localizedDescription)")
        }
    }
}