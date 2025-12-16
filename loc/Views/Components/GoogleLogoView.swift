//
//  GoogleLogoView.swift
//  loc
//
//  Custom Google "G" logo matching official branding colors
//

import SwiftUI

struct GoogleLogoView: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // Multicolor G arc segments
                GoogleArcSegment(
                    startAngle: -35,
                    endAngle: 55,
                    color: Color(red: 66/255, green: 133/255, blue: 244/255) // Blue
                )
                
                GoogleArcSegment(
                    startAngle: 55,
                    endAngle: 145,
                    color: Color(red: 52/255, green: 168/255, blue: 83/255) // Green
                )
                
                GoogleArcSegment(
                    startAngle: 145,
                    endAngle: 235,
                    color: Color(red: 251/255, green: 188/255, blue: 5/255) // Yellow
                )
                
                GoogleArcSegment(
                    startAngle: 235,
                    endAngle: 325,
                    color: Color(red: 234/255, green: 67/255, blue: 53/255) // Red
                )
                
                // Inner white circle to create the "G" shape
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.5, height: size * 0.5)
                
                // Blue horizontal bar (the crossbar of the G)
                Rectangle()
                    .fill(Color(red: 66/255, green: 133/255, blue: 244/255))
                    .frame(width: size * 0.45, height: size * 0.18)
                    .offset(x: size * 0.08)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct GoogleArcSegment: View {
    let startAngle: Double
    let endAngle: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            Path { path in
                let center = CGPoint(x: size / 2, y: size / 2)
                let radius = size / 2
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GoogleLogoView()
            .frame(width: 48, height: 48)
        
        GoogleLogoView()
            .frame(width: 24, height: 24)
        
        GoogleLogoView()
            .frame(width: 16, height: 16)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

