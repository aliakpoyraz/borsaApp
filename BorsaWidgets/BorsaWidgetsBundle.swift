import WidgetKit
import SwiftUI

@main
struct BorsaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FavoritesWidget()
        PortfolioWidget()
    }
}
