//
//  Superuser.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import PocketBase

/// Represents a superuser record in the `_superusers` collection.
/// Superusers have full admin access to the PocketBase instance.
@AuthCollection("_superusers")
struct Superuser {
    // @AuthCollection macro automatically provides:
    // - id: String
    // - created: Date
    // - updated: Date
    // - collectionId: String
    // - collectionName: String
    // - username: String?
    // - email: String
    // - verified: Bool
    // - emailVisibility: Bool

    // Add any custom fields here if needed
}
