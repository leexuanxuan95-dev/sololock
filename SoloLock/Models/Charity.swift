import Foundation

struct Charity: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String

    static let directory: [Charity] = [
        .init(id: "givewell",  name: "GiveWell Top Charities Fund", blurb: "Evidence-backed global health"),
        .init(id: "ms",        name: "Doctors Without Borders",      blurb: "Emergency medical aid worldwide"),
        .init(id: "amf",       name: "Against Malaria Foundation",   blurb: "Bed nets, sub-Saharan Africa"),
        .init(id: "uw",        name: "World Food Programme USA",     blurb: "Hunger relief"),
        .init(id: "rainforest",name: "Rainforest Trust",             blurb: "Tropical forest preservation"),
        .init(id: "aclu",      name: "ACLU Foundation",              blurb: "Civil liberties legal work")
    ]
}

/// Charity-Lock dollar amount per failed session, $1–$25.
struct CharityCommitment: Codable, Hashable {
    var charity: Charity
    var amountDollars: Int   // clamp UI to 1...25
}
