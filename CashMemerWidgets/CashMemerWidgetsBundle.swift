import SwiftUI
import WidgetKit

@main
struct CashMemerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodaySummaryWidget()
        if #available(iOS 16.1, *) {
            ScanLiveActivity()
        }
    }
}
