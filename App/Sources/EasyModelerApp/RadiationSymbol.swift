import SwiftUI

/// The radiation trefoil — three blades around a central hub, the universal
/// radioactivity symbol — drawn as vector art so it scales crisply. Blades and hub
/// share one `tint`; the gaps are transparent, so it sits on any background.
struct RadiationSymbol: View {
  var tint: Color = Palette.radiation

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let radius = min(size.width, size.height) / 2
      let inner = radius * 0.20
      let outer = radius * 0.95

      // Three 60°-wide blades, 120° apart (pointing up, lower-right, lower-left),
      // each an annular sector so the centre stays open.
      for blade in 0..<3 {
        let bladeCenter = Angle.degrees(Double(blade) * 120 - 90)
        var path = Path()
        path.addArc(
          center: center, radius: outer,
          startAngle: bladeCenter - .degrees(30), endAngle: bladeCenter + .degrees(30),
          clockwise: false)
        path.addArc(
          center: center, radius: inner,
          startAngle: bladeCenter + .degrees(30), endAngle: bladeCenter - .degrees(30),
          clockwise: true)
        path.closeSubpath()
        context.fill(path, with: .color(tint))
      }

      // The central hub.
      let hub = radius * 0.13
      context.fill(
        Path(
          ellipseIn: CGRect(x: center.x - hub, y: center.y - hub, width: hub * 2, height: hub * 2)),
        with: .color(tint))
    }
    .accessibilityLabel("Radiation symbol")
  }
}
