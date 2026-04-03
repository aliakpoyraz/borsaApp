import SwiftUI
import Charts

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let price: Double
}

struct ChartView: View {
    let dataPoints: [Double]
    let lineColor: Color
    
    var body: some View {
        let chartData: [ChartDataPoint] = dataPoints.enumerated().map { index, price in
            // Sahte zaman verisi (Geçmişe doğru)
            let time = Calendar.current.date(byAdding: .hour, value: -dataPoints.count + index, to: Date()) ?? Date()
            return ChartDataPoint(time: time, price: price)
        }
        
        let minPrice = dataPoints.min() ?? 0
        let maxPrice = dataPoints.max() ?? 100
        let padding = (maxPrice - minPrice) * 0.1
        
        Chart(chartData) { point in
            LineMark(
                x: .value("Zaman", point.time),
                y: .value("Fiyat", point.price)
            )
            .foregroundStyle(lineColor)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            
            AreaMark(
                x: .value("Zaman", point.time),
                yStart: .value("Min", minPrice - padding),
                yEnd: .value("Fiyat", point.price)
            )
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [lineColor.opacity(0.4), lineColor.opacity(0.01)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick().foregroundStyle(.clear)
                AxisValueLabel(format: .dateTime.hour().minute(), anchor: .top)
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(Color.gray.opacity(0.3))
                if let price = value.as(Double.self) {
                    AxisValueLabel {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: (minPrice - padding)...(maxPrice + padding))
    }
}
