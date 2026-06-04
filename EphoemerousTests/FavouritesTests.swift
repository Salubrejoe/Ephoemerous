//
//  FavouritesTests.swift
//  EphoemerousTests
//
//  Favourites toggle / predicate / type-filter logic. (Persistence is a
//  benign local key-value write in the didSet; the assertions here only
//  read the in-memory list.)
//

import Testing
import Foundation
@testable import Ephoemerous

struct FavouritesTests {

    @Test func toggleAddsThenRemoves() {
        let s = EAppState()
        #expect(!s.isFavourite(.sun))

        s.toggleFavourite(.sun)
        #expect(s.isFavourite(.sun))
        #expect(s.favourites.count == 1)

        s.toggleFavourite(.sun)
        #expect(!s.isFavourite(.sun))
        #expect(s.favourites.isEmpty)
    }

    @Test func isFavouriteKeysOnIdentity() {
        let s = EAppState()
        s.toggleFavourite(.moon)
        #expect(s.isFavourite(.moon))
        #expect(!s.isFavourite(.sun))
    }

    /// `favouriteStars` / `favouriteConstellations` slice the mixed list
    /// by object type.
    @Test func filtersByType() {
        let s = EAppState()
        let cons = EConstellation.allCases.first { $0 != .none }!
        s.favourites = [.sun, .constellation(cons)]

        #expect(s.favouriteConstellations == [cons])
        #expect(s.favouriteStars.isEmpty)
    }
}
