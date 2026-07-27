import SceneKit
import SwiftUI
import UIKit
import simd

/// The three-body dance as a real 3D scene you orbit and pinch (SceneKit's own
/// camera controller). Each star traces a self-lit trail in its own colour on a
/// dark stage; a bright body marker rides each trail as the transport plays. The
/// figure-8 is planar, so the camera starts looking straight down onto it — spin
/// to lift it into space, which is where the chaotic arrangements live.
///
/// Like the Lorenz stage, it rebuilds the trail geometry only when `revision`
/// changes (a parameter moved) and otherwise just repositions the markers, so the
/// per-frame playback cost is three node moves, not a geometry upload. All points
/// are centred and scaled into a fixed cube so the framing holds as the run
/// changes size. SceneKit is darwin-only; like the rest of `App/`, this never
/// enters the Kit.
struct OrbitsSceneView: UIViewRepresentable {
  let samples: [OrbitSample]
  let twinSamples: [OrbitSample]
  /// Position of the travelling markers along the trails, `0...1`; `nil` hides them.
  let markerFraction: Double?
  /// Bumped by the model on each re-integration; gates geometry rebuilds.
  let revision: Int

  /// The edge length the dance is scaled to fill, in scene units.
  private let stageSize: Float = 24

  private static let bodyColors: [UIColor] = [
    UIColor(Palette.starA), UIColor(Palette.starB), UIColor(Palette.starC),
  ]
  private static let ghostColor = UIColor.white.withAlphaComponent(0.35)

  final class Coordinator {
    var bodyLines: [SCNNode] = []
    var twinLines: [SCNNode] = []
    var bodyMarkers: [SCNNode] = []
    var twinMarkers: [SCNNode] = []
    var center = SCNVector3Zero
    var scale: Float = 1
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

    let cameraNode = SCNNode()
    let camera = SCNCamera()
    camera.zNear = 0.1
    camera.zFar = 1000
    cameraNode.camera = camera
    // Look straight down the z-axis onto the x–y plane, where the figure-8 lives,
    // so it reads as the classic flat 8 to start; the user can orbit to lift it.
    cameraNode.position = SCNVector3(0, 0, 1.8 * stageSize)
    cameraNode.look(
      at: SCNVector3Zero, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    scene.rootNode.addChildNode(cameraNode)

    for color in Self.bodyColors {
      let marker = Self.markerNode(radius: 0.7, color: color)
      marker.isHidden = true
      scene.rootNode.addChildNode(marker)
      context.coordinator.bodyMarkers.append(marker)
    }
    for _ in Self.bodyColors {
      let marker = Self.markerNode(radius: 0.45, color: Self.ghostColor)
      marker.isHidden = true
      scene.rootNode.addChildNode(marker)
      context.coordinator.twinMarkers.append(marker)
    }

    return scnView
  }

  func updateUIView(_ scnView: SCNView, context: Context) {
    guard let scene = scnView.scene else { return }
    let coordinator = context.coordinator
    if coordinator.lastRevision != revision {
      coordinator.lastRevision = revision
      rebuild(in: scene, coordinator: coordinator)
    }
    positionMarkers(coordinator: coordinator)
  }

  // MARK: - Geometry

  private func rebuild(in scene: SCNScene, coordinator: Coordinator) {
    for node in coordinator.bodyLines { node.removeFromParentNode() }
    for node in coordinator.twinLines { node.removeFromParentNode() }
    coordinator.bodyLines = []
    coordinator.twinLines = []

    guard let bounds = Bounds(samples, twinSamples) else { return }
    let center = SCNVector3(bounds.centerX, bounds.centerY, bounds.centerZ)
    let scale = bounds.extent > 0 ? stageSize / bounds.extent : 1
    coordinator.center = center
    coordinator.scale = scale

    for body in 0..<3 {
      let line = Self.trailNode(
        samples, body: body, center: center, scale: scale, color: Self.bodyColors[body])
      scene.rootNode.addChildNode(line)
      coordinator.bodyLines.append(line)
    }
    if !twinSamples.isEmpty {
      for body in 0..<3 {
        let line = Self.trailNode(
          twinSamples, body: body, center: center, scale: scale, color: Self.ghostColor)
        scene.rootNode.addChildNode(line)
        coordinator.twinLines.append(line)
      }
    }
  }

  private func positionMarkers(coordinator: Coordinator) {
    place(coordinator.bodyMarkers, along: samples, coordinator: coordinator)
    place(coordinator.twinMarkers, along: twinSamples, coordinator: coordinator)
  }

  private func place(_ markers: [SCNNode], along samples: [OrbitSample], coordinator: Coordinator) {
    guard let fraction = markerFraction, !samples.isEmpty else {
      for marker in markers { marker.isHidden = true }
      return
    }
    for body in 0..<min(3, markers.count) {
      markers[body].isHidden = false
      markers[body].position = Self.interpolated(
        samples, body: body, fraction: fraction, center: coordinator.center,
        scale: coordinator.scale)
    }
  }

  // MARK: - Builders (pure)

  private static func trailNode(
    _ samples: [OrbitSample], body: Int, center: SCNVector3, scale: Float, color: UIColor
  ) -> SCNNode {
    var vertices = [SCNVector3]()
    vertices.reserveCapacity(samples.count)
    for sample in samples {
      vertices.append(transform(sample.positions[body], center: center, scale: scale))
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
    let material = SCNMaterial()
    material.lightingModel = .constant
    material.diffuse.contents = color
    material.emission.contents = color
    geometry.materials = [material]
    return SCNNode(geometry: geometry)
  }

  private static func markerNode(radius: CGFloat, color: UIColor) -> SCNNode {
    let sphere = SCNSphere(radius: radius)
    let material = SCNMaterial()
    material.lightingModel = .constant
    material.diffuse.contents = color
    material.emission.contents = color
    sphere.materials = [material]
    return SCNNode(geometry: sphere)
  }

  private static func transform(_ p: SIMD3<Float>, center: SCNVector3, scale: Float) -> SCNVector3 {
    SCNVector3((p.x - center.x) * scale, (p.y - center.y) * scale, (p.z - center.z) * scale)
  }

  private static func interpolated(
    _ samples: [OrbitSample], body: Int, fraction: Double, center: SCNVector3, scale: Float
  ) -> SCNVector3 {
    let count = samples.count
    guard count > 1 else {
      return transform(samples[0].positions[body], center: center, scale: scale)
    }
    let clamped = min(max(fraction, 0), 1)
    let position = clamped * Double(count - 1)
    let index = min(Int(position), count - 2)
    let blend = Float(position - Double(index))
    let a = samples[index].positions[body]
    let b = samples[index + 1].positions[body]
    return transform(a + (b - a) * blend, center: center, scale: scale)
  }
}

/// The axis-aligned bounds of every body's trail (and the twin's) — the centre to
/// translate to the origin and the largest extent to scale into the stage cube, so
/// the whole system frames consistently as it changes.
private struct Bounds {
  let centerX: Float
  let centerY: Float
  let centerZ: Float
  let extent: Float

  init?(_ first: [OrbitSample], _ second: [OrbitSample]) {
    var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    var seen = false

    for samples in [first, second] {
      for sample in samples {
        for position in sample.positions {
          seen = true
          lo = simd_min(lo, position)
          hi = simd_max(hi, position)
        }
      }
    }
    guard seen else { return nil }

    centerX = (lo.x + hi.x) / 2
    centerY = (lo.y + hi.y) / 2
    centerZ = (lo.z + hi.z) / 2
    extent = max(hi.x - lo.x, max(hi.y - lo.y, hi.z - lo.z))
  }
}
