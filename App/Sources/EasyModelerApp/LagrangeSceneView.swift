import EasyModelerKit
import SceneKit
import SwiftUI
import UIKit
import simd

/// The Earth–Moon Lagrange stage as a real 3D scene you orbit and pinch. Earth and
/// the Moon are lit, textured globes fixed on the x-axis (the rotating frame); the
/// five Lagrange points can be overlaid as colour-coded target rings; and five
/// satellites — one launched from each point, drawn as little spacecraft — trace
/// coloured trails, a spacecraft riding each as the transport plays. The camera
/// starts looking straight down onto the orbital plane; spin to lift the
/// out-of-plane motion into view.
///
/// The globes spin on their axes (a toggle) so the scene has life even when nothing
/// is drifting. The frame is *fixed* on the Earth–Moon system (not fit to the
/// trajectories), so a satellite that escapes flies out of view rather than
/// shrinking the stable ones. Trail geometry rebuilds only when `revision` changes;
/// playback just moves the spacecraft. SceneKit is darwin-only; like the rest of
/// `App/`, this never enters the Kit.
struct LagrangeSceneView: UIViewRepresentable {
  let samples: [LagrangeSample]
  /// Position of the travelling spacecraft along the trails, `0...1`; `nil` hides them.
  let markerFraction: Double?
  /// Bumped by the model on each re-integration; gates geometry rebuilds.
  let revision: Int
  /// Whether Earth and the Moon spin on their axes (constant movement).
  let spinning: Bool
  /// Whether the colour-coded Lagrange-point target rings are shown.
  let showTargets: Bool

  /// Scene units per non-dimensional distance unit — a fixed scale that frames the
  /// Earth–Moon system (its Lagrange points span roughly ±1.2).
  private let scale: Float = 9.0

  private static let satelliteColors = Palette.satellites.map { UIColor($0) }

  final class Coordinator {
    var trails: [SCNNode] = []
    var spacecraft: [SCNNode] = []
    var targetRings: [SCNNode] = []
    var earth: SCNNode?
    var moon: SCNNode?
    var spinApplied = false
    var lastRevision = Int.min
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> SCNView {
    let scnView = SCNView()
    let scene = SCNScene()
    scnView.scene = scene
    scnView.allowsCameraControl = true
    scnView.autoenablesDefaultLighting = false
    scnView.backgroundColor = .black
    scnView.antialiasingMode = .multisampling4X

    scene.rootNode.addChildNode(Self.cameraNode())
    scene.rootNode.addChildNode(
      Self.lightNode(type: .omni, intensity: 1000, at: SCNVector3(30, 30, 60)))
    scene.rootNode.addChildNode(Self.lightNode(type: .ambient, intensity: 350, at: .init()))

    let coordinator = context.coordinator

    let earth = Self.globeNode(
      radius: 1.1, texture: Self.earthTexture(), specular: true)
    earth.position = transform(EarthMoonSystem.earthPosition)
    scene.rootNode.addChildNode(earth)
    coordinator.earth = earth

    let moon = Self.globeNode(radius: 0.6, texture: Self.moonTexture(), specular: false)
    moon.position = transform(EarthMoonSystem.moonPosition)
    scene.rootNode.addChildNode(moon)
    coordinator.moon = moon

    for (index, point) in EarthMoonSystem.lagrangePoints.enumerated() {
      let ring = Self.targetRing(color: Self.satelliteColors[index])
      ring.position = transform(point.position)
      scene.rootNode.addChildNode(ring)
      coordinator.targetRings.append(ring)

      let craft = Self.spacecraftNode(color: Self.satelliteColors[index])
      craft.isHidden = true
      scene.rootNode.addChildNode(craft)
      coordinator.spacecraft.append(craft)
    }

    return scnView
  }

  func updateUIView(_ scnView: SCNView, context: Context) {
    guard let scene = scnView.scene else { return }
    let coordinator = context.coordinator

    if coordinator.lastRevision != revision {
      coordinator.lastRevision = revision
      rebuildTrails(in: scene, coordinator: coordinator)
    }
    positionSpacecraft(coordinator: coordinator)

    for ring in coordinator.targetRings { ring.isHidden = !showTargets }
    applySpin(coordinator: coordinator, on: scnView)
  }

  // MARK: - Spin

  private func applySpin(coordinator: Coordinator, on scnView: SCNView) {
    guard coordinator.spinApplied != spinning else { return }
    coordinator.spinApplied = spinning
    scnView.rendersContinuously = spinning
    if spinning {
      coordinator.earth?.runAction(Self.spinAction(duration: 12), forKey: "spin")
      coordinator.moon?.runAction(Self.spinAction(duration: 18), forKey: "spin")
    } else {
      coordinator.earth?.removeAction(forKey: "spin")
      coordinator.moon?.removeAction(forKey: "spin")
    }
  }

  // MARK: - Trails and spacecraft

  private func rebuildTrails(in scene: SCNScene, coordinator: Coordinator) {
    for node in coordinator.trails { node.removeFromParentNode() }
    coordinator.trails = []
    guard !samples.isEmpty else { return }
    for satellite in 0..<Self.satelliteColors.count {
      let trail = trailNode(satellite: satellite, color: Self.satelliteColors[satellite])
      scene.rootNode.addChildNode(trail)
      coordinator.trails.append(trail)
    }
  }

  private func positionSpacecraft(coordinator: Coordinator) {
    guard let fraction = markerFraction, !samples.isEmpty else {
      for craft in coordinator.spacecraft { craft.isHidden = true }
      return
    }
    for satellite in 0..<coordinator.spacecraft.count {
      coordinator.spacecraft[satellite].isHidden = false
      coordinator.spacecraft[satellite].position = interpolated(
        satellite: satellite, fraction: fraction)
    }
  }

  private func trailNode(satellite: Int, color: UIColor) -> SCNNode {
    var vertices = [SCNVector3]()
    vertices.reserveCapacity(samples.count)
    for sample in samples {
      vertices.append(transform(sample.positions[satellite]))
    }
    let source = SCNGeometrySource(vertices: vertices)
    var indices = [Int32]()
    indices.reserveCapacity(max(0, vertices.count - 1) * 2)
    var i = 0
    while i < vertices.count - 1 {
      indices.append(Int32(i))
      indices.append(Int32(i + 1))
      i += 1
    }
    let element = SCNGeometryElement(indices: indices, primitiveType: .line)
    let geometry = SCNGeometry(sources: [source], elements: [element])
    geometry.materials = [Self.glowMaterial(color)]
    return SCNNode(geometry: geometry)
  }

  // MARK: - Builders (pure)

  private static func cameraNode() -> SCNNode {
    let node = SCNNode()
    let camera = SCNCamera()
    camera.zNear = 0.1
    camera.zFar = 1000
    node.camera = camera
    // Look straight down the z-axis onto the orbital plane — the classic top-down
    // Lagrange diagram, Earth and Moon left-to-right. Orbit to see the out-of-plane
    // motion.
    node.position = SCNVector3(0, 0, 26)
    node.look(at: SCNVector3Zero, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    return node
  }

  private static func lightNode(
    type: SCNLight.LightType, intensity: CGFloat, at position: SCNVector3
  )
    -> SCNNode
  {
    let node = SCNNode()
    let light = SCNLight()
    light.type = type
    light.intensity = intensity
    node.light = light
    node.position = position
    return node
  }

  private static func spinAction(duration: TimeInterval) -> SCNAction {
    SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: duration))
  }

  /// A lit globe: a shaded sphere carrying an equirectangular texture, so it reads
  /// as a real 3D body rather than a flat disc.
  private static func globeNode(radius: CGFloat, texture: UIImage, specular: Bool) -> SCNNode {
    let sphere = SCNSphere(radius: radius)
    sphere.segmentCount = 48
    let material = SCNMaterial()
    material.lightingModel = .blinn
    material.diffuse.contents = texture
    if specular {
      material.specular.contents = UIColor(white: 0.5, alpha: 1)
      material.shininess = 0.2
    }
    sphere.materials = [material]
    return SCNNode(geometry: sphere)
  }

  /// A little spacecraft: a foil-wrapped body, two solar-panel wings in the
  /// satellite's colour (the big surfaces you read from above), and a dish.
  private static func spacecraftNode(color: UIColor) -> SCNNode {
    let node = SCNNode()

    let body = SCNNode(geometry: SCNBox(width: 0.5, height: 0.5, length: 0.7, chamferRadius: 0.08))
    body.geometry?.materials = [litMaterial(UIColor(white: 0.75, alpha: 1), emission: 0)]
    node.addChildNode(body)

    let panelGeometry = SCNBox(width: 0.9, height: 0.55, length: 0.04, chamferRadius: 0)
    for side in [-1.0, 1.0] {
      let panel = SCNNode(geometry: panelGeometry.copy() as? SCNGeometry)
      panel.geometry?.materials = [litMaterial(color, emission: 0.35)]
      panel.position = SCNVector3(Float(side) * 0.8, 0, 0)
      node.addChildNode(panel)
    }

    let dish = SCNNode(geometry: SCNCylinder(radius: 0.22, height: 0.06))
    dish.geometry?.materials = [litMaterial(UIColor(white: 0.85, alpha: 1), emission: 0)]
    dish.position = SCNVector3(0, 0, 0.42)
    dish.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
    node.addChildNode(dish)

    return node
  }

  /// A colour-coded ring marking a Lagrange point — the spot to shoot for — laid
  /// flat in the orbital plane so it reads as a target from the top-down view.
  private static func targetRing(color: UIColor) -> SCNNode {
    let torus = SCNTorus(ringRadius: 1.0, pipeRadius: 0.09)
    torus.materials = [glowMaterial(color)]
    let node = SCNNode(geometry: torus)
    node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)  // from x–z plane into x–y
    return node
  }

  private static func litMaterial(_ color: UIColor, emission: CGFloat) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .blinn
    material.diffuse.contents = color
    if emission > 0 { material.emission.contents = color.withAlphaComponent(emission) }
    return material
  }

  private static func glowMaterial(_ color: UIColor) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .constant
    material.diffuse.contents = color
    material.emission.contents = color
    return material
  }

  // MARK: - Textures

  private static func earthTexture() -> UIImage {
    let size = CGSize(width: 512, height: 256)
    return UIGraphicsImageRenderer(size: size).image { context in
      let cg = context.cgContext
      UIColor(red: 0.06, green: 0.24, blue: 0.45, alpha: 1).setFill()
      cg.fill(CGRect(origin: .zero, size: size))
      let land = UIColor(red: 0.16, green: 0.42, blue: 0.22, alpha: 1)
      land.setFill()
      let blobs = [
        CGRect(x: 60, y: 70, width: 90, height: 120), CGRect(x: 130, y: 150, width: 70, height: 90),
        CGRect(x: 250, y: 60, width: 130, height: 80),
        CGRect(x: 300, y: 130, width: 150, height: 100),
        CGRect(x: 420, y: 80, width: 70, height: 70),
      ]
      for blob in blobs { cg.fillEllipse(in: blob) }
      UIColor(white: 0.92, alpha: 1).setFill()
      cg.fill(CGRect(x: 0, y: 0, width: size.width, height: 16))
      cg.fill(CGRect(x: 0, y: size.height - 16, width: size.width, height: 16))
    }
  }

  private static func moonTexture() -> UIImage {
    let size = CGSize(width: 256, height: 128)
    return UIGraphicsImageRenderer(size: size).image { context in
      let cg = context.cgContext
      UIColor(white: 0.58, alpha: 1).setFill()
      cg.fill(CGRect(origin: .zero, size: size))
      UIColor(white: 0.44, alpha: 1).setFill()
      for maria in [
        CGRect(x: 40, y: 30, width: 60, height: 45), CGRect(x: 150, y: 60, width: 55, height: 40),
      ] {
        cg.fillEllipse(in: maria)
      }
      UIColor(white: 0.72, alpha: 1).setFill()
      let craters = [
        CGRect(x: 90, y: 80, width: 18, height: 18), CGRect(x: 200, y: 25, width: 14, height: 14),
        CGRect(x: 30, y: 95, width: 12, height: 12), CGRect(x: 130, y: 20, width: 16, height: 16),
        CGRect(x: 210, y: 95, width: 10, height: 10),
      ]
      for crater in craters { cg.fillEllipse(in: crater) }
    }
  }

  // MARK: - Transforms

  private func transform(_ p: SIMD3<Float>) -> SCNVector3 {
    SCNVector3(p.x * scale, p.y * scale, p.z * scale)
  }

  private func transform(_ p: [Double]) -> SCNVector3 {
    SCNVector3(Float(p[0]) * scale, Float(p[1]) * scale, Float(p[2]) * scale)
  }

  private func interpolated(satellite: Int, fraction: Double) -> SCNVector3 {
    let count = samples.count
    guard count > 1 else { return transform(samples[0].positions[satellite]) }
    let clamped = min(max(fraction, 0), 1)
    let position = clamped * Double(count - 1)
    let index = min(Int(position), count - 2)
    let blend = Float(position - Double(index))
    let a = samples[index].positions[satellite]
    let b = samples[index + 1].positions[satellite]
    return transform(a + (b - a) * blend)
  }
}
