import Foundation

extension Date {
    /// 格式化日期为日记显示格式
    /// - 如果日期是当年：返回 "MM/DD HH:MM"
    /// - 如果日期不是当年：返回 "YYYY/MM/DD"
    func formattedForDiary() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // 判断是否为当年
        let isCurrentYear = calendar.component(.year, from: self) == calendar.component(.year, from: now)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        if isCurrentYear {
            // 当年：MM/DD HH:MM
            formatter.dateFormat = "MM/dd HH:mm"
        } else {
            // 非当年：YYYY/MM/DD
            formatter.dateFormat = "yyyy/MM/dd"
        }
        
        return formatter.string(from: self)
    }
}
