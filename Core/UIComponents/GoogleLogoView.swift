import SwiftUI

struct GoogleLogoView: View {
    var size: CGFloat = 24
    
    var body: some View {
        ZStack {
            // Recreating the Google G with 4 colored arcs
            // The G shape is basically a circle with a cutout and a horizontal stem
            Group {
                // Blue branch
                Path { path in
                    path.addArc(center: CGPoint(x: size/2, y: size/2), radius: size/2, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: true)
                }
                .stroke(Color(red: 66/255, green: 133/255, blue: 244/255), lineWidth: size/4)
                
                // Red branch
                Path { path in
                    path.addArc(center: CGPoint(x: size/2, y: size/2), radius: size/2, startAngle: .degrees(45), endAngle: .degrees(135), clockwise: false)
                }
                .stroke(Color(red: 234/255, green: 67/255, blue: 53/255), lineWidth: size/4)
                
                // Yellow branch
                Path { path in
                    path.addArc(center: CGPoint(x: size/2, y: size/2), radius: size/2, startAngle: .degrees(135), endAngle: .degrees(225), clockwise: false)
                }
                .stroke(Color(red: 251/255, green: 188/255, blue: 5/255), lineWidth: size/4)
                
                // Green branch
                Path { path in
                    path.addArc(center: CGPoint(x: size/2, y: size/2), radius: size/2, startAngle: .degrees(225), endAngle: .degrees(-45), clockwise: false)
                }
                .stroke(Color(red: 52/255, green: 168/255, blue: 83/255), lineWidth: size/4)
            }
            .mask(
                ZStack {
                    Circle()
                        .stroke(lineWidth: size/4)
                    Rectangle()
                        .frame(width: size/2, height: size/4)
                        .offset(x: size/4)
                }
            )
            
            // The horizontal stem of the G
            Rectangle()
                .fill(Color(red: 66/255, green: 133/255, blue: 244/255))
                .frame(width: size/2, height: size/4)
                .offset(x: size/4)
        }
        .frame(width: size, height: size)
    }
}

// Actually, drawing a pixel-perfect G with paths is hard. 
// A better way is using an SF Symbol with palette rendering if available in newer iOS, 
// OR just using a robust custom SVG-like composite.
// I'll provide a simpler, more robust colored "G" using a system image if it works, 
// but for maximum premium feel, let's use a nice composite.

struct GoogleLogoView_v2: View {
    var size: CGFloat = 20
    
    var body: some View {
        Image(systemName: "g.circle.fill")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // We'll use a custom rendering in the button to make it pop, 
            // but for now, let's just use the colored version in the view itself.
    }
}
