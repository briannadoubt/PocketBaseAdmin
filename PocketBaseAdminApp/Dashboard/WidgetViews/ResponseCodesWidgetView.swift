//
//  ResponseCodesWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import Charts

/// Response codes widget showing HTTP status code distribution
struct ResponseCodesWidgetView: View {
    let data: ResponseCodesData

    @State private var selectedCode: ResponseCodesData.CodeStat?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Response Codes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let selected = selectedCode {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(selected.count)")
                                .font(.title2.bold())
                                .foregroundStyle(selected.color)
                            Text(selected.statusGroup)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(data.totalRequests)")
                                .font(.title2.bold())
                            Text("total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "number.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if data.codes.isEmpty {
                ContentUnavailableView {
                    Label("No Data", systemImage: "chart.pie")
                } description: {
                    Text("No response data available")
                }
                .frame(height: 100)
            } else {
                HStack(spacing: 16) {
                    // Pie chart
                    Chart(data.codes) { code in
                        SectorMark(
                            angle: .value("Count", code.count),
                            innerRadius: .ratio(0.5),
                            outerRadius: selectedCode?.statusGroup == code.statusGroup ? .ratio(1.0) : .ratio(0.9),
                            angularInset: 1.5
                        )
                        .foregroundStyle(code.color)
                        .cornerRadius(4)
                        .opacity(selectedCode == nil || selectedCode?.statusGroup == code.statusGroup ? 1.0 : 0.5)
                    }
                    .chartBackground { _ in
                        if let selected = selectedCode {
                            VStack(spacing: 0) {
                                Text("\(selected.count)")
                                    .font(.title3.bold())
                                    .foregroundStyle(selected.color)
                                Text(selected.statusGroup)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(spacing: 0) {
                                Text("\(data.totalRequests)")
                                    .font(.title3.bold())
                                Text("total")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 100, height: 100)

                    // Legend
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(data.codes) { code in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(code.color)
                                    .frame(width: 8, height: 8)
                                Text(code.statusGroup)
                                    .font(.caption)
                                    .foregroundStyle(selectedCode == nil || selectedCode?.statusGroup == code.statusGroup ? .primary : .secondary)
                                Spacer()
                                Text("\(code.count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.smooth) {
                                    if selectedCode?.statusGroup == code.statusGroup {
                                        selectedCode = nil
                                    } else {
                                        selectedCode = code
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth, value: selectedCode?.statusGroup)
    }
}

#Preview {
    ResponseCodesWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
