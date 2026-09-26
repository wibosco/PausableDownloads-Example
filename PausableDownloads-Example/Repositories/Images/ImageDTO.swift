//
//  ImageDTO.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

struct ImageDTO: Decodable, Equatable {
    let id: String
    let url: URL
    let width: Int
    let height: Int
    let mimeType: String?
    let breeds: [BreedDTO]?
    let categories: [CategoryDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case width
        case height
        case mimeType = "mime_type"
        case breeds
        case categories
    }
    
    struct BreedDTO: Decodable, Equatable {
        let id: String
        let name: String
        let altNames: String?
        let description: String
        let temperament: String
        let origin: String
        let countryCode: String?
        let countryCodes: String?

        let weight: WeightDTO?
        let lifeSpan: String?

        let referenceImageID: String?
        let wikipediaURL: String?
        let cfaURL: String?
        let vetstreetURL: String?
        let vcahospitalsURL: String?

        // Ratings, 1 - 5
        let adaptability: Int?
        let affectionLevel: Int?
        let childFriendly: Int?
        let catFriendly: Int?
        let dogFriendly: Int?
        let strangerFriendly: Int?
        let energyLevel: Int?
        let grooming: Int?
        let healthIssues: Int?
        let intelligence: Int?
        let sheddingLevel: Int?
        let socialNeeds: Int?
        let vocalisation: Int?

        // Flags, 0 or 1
        let experimental: Int?
        let hairless: Int?
        let natural: Int?
        let rare: Int?
        let rex: Int?
        let suppressedTail: Int?
        let shortLegs: Int?
        let hypoallergenic: Int?
        let indoor: Int?
        let lap: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case altNames = "alt_names"
            case description
            case temperament
            case origin
            case countryCode = "country_code"
            case countryCodes = "country_codes"
            case weight
            case lifeSpan = "life_span"
            case referenceImageID = "reference_image_id"
            case wikipediaURL = "wikipedia_url"
            case cfaURL = "cfa_url"
            case vetstreetURL = "vetstreet_url"
            case vcahospitalsURL = "vcahospitals_url"
            case adaptability
            case affectionLevel = "affection_level"
            case childFriendly = "child_friendly"
            case catFriendly = "cat_friendly"
            case dogFriendly = "dog_friendly"
            case strangerFriendly = "stranger_friendly"
            case energyLevel = "energy_level"
            case grooming
            case healthIssues = "health_issues"
            case intelligence
            case sheddingLevel = "shedding_level"
            case socialNeeds = "social_needs"
            case vocalisation
            case experimental
            case hairless
            case natural
            case rare
            case rex
            case suppressedTail = "suppressed_tail"
            case shortLegs = "short_legs"
            case hypoallergenic
            case indoor
            case lap
        }
    }

    struct WeightDTO: Decodable, Equatable {
        let imperial: String
        let metric: String
    }

    struct CategoryDTO: Decodable, Equatable {
        let id: Int
        let name: String
    }
}
