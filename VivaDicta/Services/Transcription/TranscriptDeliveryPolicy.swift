//
//  TranscriptDeliveryPolicy.swift
//  VivaDicta
//
//  Keeps the keyboard flow usable when AI Polish fails or returns an empty
//  response. The raw ASR result is always the final fallback.
//

import Foundation

enum TranscriptDeliveryPolicy {
    /// Returns a usable value for insertion and sharing.
    ///
    /// An enhancement provider can technically return an empty successful
    /// response. Treat that the same as a failed enhancement so users never
    /// lose a valid raw transcript merely because Polish was enabled.
    static func preferredText(rawTranscript: String, enhancedText: String?) -> String {
        guard let enhancedText,
              !enhancedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return rawTranscript
        }

        return enhancedText
    }
}
