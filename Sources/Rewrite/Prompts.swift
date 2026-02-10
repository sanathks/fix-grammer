enum Prompts {
    static func grammar(text: String) -> String {
        """
        Fix any grammar, spelling, and punctuation errors in the following text. \
        Preserve the original meaning, tone, and formatting. \
        Return ONLY the corrected text. \
        Do NOT wrap output in quotes or markdown formatting. \
        Do NOT add any explanations or comments.

        \(text)
        """
    }

    static func rewrite(mode: RewriteMode, text: String) -> String {
        let instruction: String
        if mode.name == "My Tone" {
            instruction = "Rewrite the following text to match this tone: \(mode.prompt). " +
                "Fix any grammar, spelling, and punctuation errors in the process. " +
                "Preserve the original meaning and key information."
        } else {
            instruction = mode.prompt
        }

        return """
        \(instruction) \
        Never use em dashes or semicolons. Use commas or periods instead. \
        Return ONLY the rewritten text. \
        Do NOT wrap output in quotes or markdown formatting. \
        Do NOT add any explanations or comments.

        \(text)
        """
    }
}
