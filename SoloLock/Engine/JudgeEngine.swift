import Foundation

/// Lightweight, deterministic-but-varied PRNG so a session has its own
/// "voice." Avoids `random()` which would give different results per call —
/// we want reproducibility for tests, but huge variation across sessions.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEFCAFEBABE : seed }

    /// xorshift64* — fast, fine quality for this purpose.
    mutating func next() -> UInt64 {
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 0x2545F4914F6CDD1D
    }

    mutating func pick<T>(_ array: [T]) -> T {
        precondition(!array.isEmpty)
        return array[Int(next() % UInt64(array.count))]
    }

    mutating func chance(_ p: Double) -> Bool {
        Double(next() & 0xFFFFFFFF) / Double(UInt32.max) < p
    }
}

/// Snapshot of session state passed to the judge so replies can reference
/// elapsed/remaining time, current phase, etc. — no hidden global state.
struct JudgeContext {
    var minutesElapsed: Int
    var minutesRemaining: Int
    var sessionSeed: UInt64
    /// Recently produced replies in this session, used to dampen repetition.
    var recentHashes: Set<Int>
}

struct JudgeReply {
    let text: String
    let intent: JudgeIntent
}

/// Composes algorithmic replies. No network, no LLM. Pure data + RNG.
final class JudgeEngine {

    /// Compose a reply for `userText` given session context.
    /// Picks 1–3 sentences and stitches them with slot fills.
    func reply(to userText: String, context: inout JudgeContext) -> JudgeReply {
        let intent = JudgeClassifier.classify(userText)
        var rng = SeededRNG(seed: mixSeed(context.sessionSeed, userText))

        // Try a few candidates and prefer one we haven't said this session.
        var best: String = ""
        var bestHash: Int = 0
        for _ in 0..<5 {
            let candidate = compose(intent: intent, rng: &rng, ctx: context)
            let h = candidate.hashValue
            if !context.recentHashes.contains(h) {
                best = candidate
                bestHash = h
                break
            } else if best.isEmpty {
                best = candidate
                bestHash = h
            }
        }
        // Update memo so callers don't have to do it themselves.
        context.recentHashes.insert(bestHash)
        // Set has no insertion order, so "drop oldest" isn't meaningful. Once
        // we've accumulated enough memory to dampen short-term repetition,
        // wipe and start over. The next ~32 replies will repopulate it.
        if context.recentHashes.count > 32 {
            context.recentHashes.removeAll(keepingCapacity: true)
        }
        return JudgeReply(text: best, intent: intent)
    }

    // MARK: - Greeting on session start (proactive, not in response to text)
    func openingMessage(seed: UInt64, plannedMinutes: Int) -> ChatMessage {
        var rng = SeededRNG(seed: seed ^ 0xA5A5_5A5A_A5A5_5A5A)
        let opener = rng.pick(Vocab.greetings)
        let body: String
        switch plannedMinutes {
        case 0..<60:
            body = "the timer holds \(plannedMinutes) minutes. so do we."
        case 60..<240:
            let h = plannedMinutes / 60, m = plannedMinutes % 60
            body = "the docket reads \(h)h\(m == 0 ? "" : " \(m)m"). well held in advance."
        default:
            body = "this is a long one. the lock is built for it. so are you."
        }
        return ChatMessage(role: .judge, text: "\(opener) \(body)")
    }

    // MARK: - Composition

    private func compose(intent: JudgeIntent, rng: inout SeededRNG, ctx: JudgeContext) -> String {
        let templates = JudgeTemplates.templates(for: intent)
        let template = rng.pick(templates)
        var line = fill(template: template, rng: &rng, ctx: ctx)

        // 35% chance to add a second sentence, 8% chance to add a third —
        // tuned to feel like a person who occasionally elaborates.
        if rng.chance(0.35) {
            let extra = rng.pick(JudgeTemplates.templates(for: intent))
            let extraLine = fill(template: extra, rng: &rng, ctx: ctx)
            if !extraLine.isEmpty {
                line += " " + extraLine
            }
        }
        if rng.chance(0.08) {
            let close = rng.pick(Vocab.closers)
            if !line.hasSuffix(close) {
                line += " " + close
            }
        }
        // De-doublespace, ensure first letter lowercased intentionally to
        // match the notarial-but-quiet tone in UI.md.
        return normalize(line)
    }

    private func fill(template: String, rng: inout SeededRNG, ctx: JudgeContext) -> String {
        var out = template
        let pairs: [(String, String)] = [
            ("{open}",     rng.pick(Vocab.coldOpens)),
            ("{soft}",     rng.pick(Vocab.softOpens)),
            ("{deny}",     rng.pick(Vocab.denials)),
            ("{reason}",   rng.pick(Vocab.reasons)),
            ("{subject}",  rng.pick(Vocab.subjects)),
            ("{verb}",     rng.pick(Vocab.subjectVerbs)),
            ("{time}",     rng.pick(Vocab.timeFramings)),
            ("{close}",    rng.pick(Vocab.closers)),
            ("{alt}",      rng.pick(Vocab.alternatives)),
            ("{boredom}",  rng.pick(Vocab.boredomReframes)),
            ("{angerAck}", rng.pick(Vocab.angerAcks)),
            ("{anxiety}",  rng.pick(Vocab.anxietyLines)),
            ("{exist}",    rng.pick(Vocab.existentialLines)),
            ("{greet}",    rng.pick(Vocab.greetings)),
            ("{quiet}",    rng.pick(Vocab.quietAcks)),
            ("{minutes}",  "\(ctx.minutesRemaining)"),
            ("{progress}", phaseLine(elapsed: ctx.minutesElapsed, remaining: ctx.minutesRemaining))
        ]
        for (key, val) in pairs {
            out = out.replacingOccurrences(of: key, with: val)
        }
        return out
    }

    private func phaseLine(elapsed: Int, remaining: Int) -> String {
        let total = max(1, elapsed + remaining)
        let pct = Double(elapsed) / Double(total)
        switch pct {
        case ..<0.10: return "clean slate."
        case ..<0.40: return "settling in."
        case ..<0.70: return "midway. holding."
        case ..<0.95: return "the long stretch — almost there."
        default:      return "last ten percent. don't crack now."
        }
    }

    private func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        // Collapse double spaces from empty slot fills.
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        // Remove space-before-period from chained pieces.
        t = t.replacingOccurrences(of: " ,", with: ",")
        t = t.replacingOccurrences(of: " .", with: ".")
        return t
    }

    private func mixSeed(_ base: UInt64, _ text: String) -> UInt64 {
        var h = base ^ 0x9E37_79B9_7F4A_7C15
        for u in text.unicodeScalars {
            h = (h ^ UInt64(u.value)) &* 0x100000001B3
        }
        return h
    }
}
