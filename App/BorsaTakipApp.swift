
import SwiftUI

@main
struct BorsaTakipApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
//TESTTTTTTTTTTTT
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
            
            Text("Borsa App Sa")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Proje klasör yapısı testttinggggg")
                .foregroundColor(.secondary)
        }
    }
}
