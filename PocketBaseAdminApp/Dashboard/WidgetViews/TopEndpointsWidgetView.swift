//
//  TopEndpointsWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import Charts

/// Top endpoints widget showing most accessed API routes
struct TopEndpointsWidgetView: View {
    let data: TopEndpointsData

    private let methodColors: [String: Color] = [
        "GET": .blue,
        "POST": .green,
        "PUT": .orange,
        "PATCH": .yellow,
        "DELETE": .red
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Endpoints")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(data.totalRequests)")
                            .font(.title2.bold())
                        Text("requests")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.arrow.down")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if data.endpoints.isEmpty {
                ContentUnavailableView {
                    Label("No Data", systemImage: "chart.bar")
                } description: {
                    Text("No endpoint data available")
                }
                .frame(height: 100)
            } else {
                // Bar chart
                Chart(data.endpoints) { endpoint in
                    BarMark(
                        x: .value("Count", endpoint.count),
                        y: .value("Endpoint", endpoint.path)
                    )
                    .foregroundStyle(methodColors[endpoint.method] ?? .gray)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(endpoint.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let path = value.as(String.self) {
                                Text(shortenPath(path))
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(data.endpoints.count * 28))

                // Legend
                HStack(spacing: 12) {
                    ForEach(["GET", "POST", "DELETE"], id: \.self) { method in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(methodColors[method] ?? .gray)
                                .frame(width: 6, height: 6)
                            Text(method)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func shortenPath(_ path: String) -> String {
        // Show last two path components
        let components = path.split(separator: "/").suffix(2)
        return "/" + components.joined(separator: "/")
    }
}

#Preview {
    TopEndpointsWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
