import SwiftUI

struct AnalyticsView: View {
    @State private var summary: AnalyticsSummary? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PageHeaderView(title: "Analytics", subtitle: "Real telephony metrics from your account") {
                    Button(action: {
                        Task { await loadAnalytics() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.cvPrimaryLight)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                
                if isLoading && summary == nil {
                    Spacer().frame(height: 100)
                    ProgressView().tint(.cvPrimaryLight)
                    Spacer()
                } else if let stats = summary {
                    // Key Metric Cards Grid (2 columns)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetricCard(
                            title: "Total Calls",
                            value: "\(stats.total)",
                            subtitle: "\(stats.answered) answered",
                            icon: "phone.fill",
                            accentColor: .cvPrimaryLight
                        )
                        
                        MetricCard(
                            title: "Answer Rate",
                            value: String(format: "%.1f%%", stats.answerRatePercentage),
                            subtitle: "\(stats.failed) failed/busy",
                            icon: "chart.line.uptrend.xyaxis",
                            accentColor: .cvGreen
                        )
                        
                        MetricCard(
                            title: "Total Minutes",
                            value: String(format: "%.1f min", stats.minutes),
                            subtitle: "Talk time",
                            icon: "clock.fill",
                            accentColor: .cvCyan
                        )
                        
                        MetricCard(
                            title: "Avg Duration",
                            value: DateFormatters.formatDuration(stats.avgSec),
                            subtitle: "Per connected call",
                            icon: "hourglass",
                            accentColor: .cvAmber
                        )
                        
                        MetricCard(
                            title: "Total Spend",
                            value: String(format: "$%.2f", stats.spend),
                            subtitle: "Carrier cost (USD)",
                            icon: "dollarsign.circle.fill",
                            accentColor: .cvGreenLight
                        )
                        
                        MetricCard(
                            title: "Failed / Missed",
                            value: "\(stats.failed)",
                            subtitle: "Unconnected calls",
                            icon: "xmark.circle.fill",
                            accentColor: .cvRed
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // Calls By Country Breakdown
                    if let byCountry = stats.byCountry, !byCountry.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calls By Destination Country")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.cvTextPrimary)
                            
                            VStack(spacing: 8) {
                                ForEach(byCountry) { item in
                                    HStack {
                                        let country = CountryDirectory.country(forCode: item.country)
                                        Text(country?.flag ?? "🌐")
                                            .font(.system(size: 18))
                                        
                                        Text(country?.name ?? item.country)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.cvTextPrimary)
                                        
                                        Spacer()
                                        
                                        Text("\(item.c) calls")
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.cvCyan)
                                        
                                        if let spend = item.s, spend > 0 {
                                            Text(String(format: "($%.2f)", spend))
                                                .font(.system(size: 12))
                                                .foregroundColor(.cvTextMuted)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    
                                    if item.id != byCountry.last?.id {
                                        Divider().background(Color.cvBorder)
                                    }
                                }
                            }
                            .cvCard(padding: 16)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    AttributionFooter()
                } else {
                    EmptyStateView(
                        icon: "chart.bar.xaxis",
                        title: "No Analytics Available",
                        message: "Call activity will generate analytics automatically."
                    )
                }
            }
        }
        .cvBackground()
        .task {
            await loadAnalytics()
        }
        .refreshable {
            await loadAnalytics()
        }
    }
    
    private func loadAnalytics() async {
        isLoading = true
        errorMessage = nil
        do {
            let res: AnalyticsResponse = try await APIClient.shared.get("/api/analytics/summary")
            self.summary = res.summary
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.cvTextSecondary)
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                    .font(.system(size: 14))
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.cvTextPrimary)
            
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.cvTextMuted)
        }
        .cvCard(padding: 14)
    }
}
