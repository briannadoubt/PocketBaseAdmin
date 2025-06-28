//
//  RemoteImage.swift
//  AdminUI
//
//  Created by Brianna Zamora on 3/23/25.
//

import SwiftUI
import SDWebImageSwiftUI
import PocketBase

struct RemoteImage<T: Record>: View {
    let url: URL?
    init(_ url: URL?) {
        self.url = url
    }
    var body: some View {
        WebImage(url: url)
    }
}
