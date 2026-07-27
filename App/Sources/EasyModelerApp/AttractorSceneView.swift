import SceneKit
import SwiftUI
import UIKit

/// The Lorenz attractor as a real 3D scene you orbit and pinch (SceneKit's own
/// camera controller). The trajectory is a self-lit line on a dark stage; a
/// bright dot rides it as the transport plays, and the butterfly-effect twin is
/// a second, warmer line with its own dot.
///
/// It rebuilds the line geometry only when the model's `revision` changes (a
/// parameter moved), and otherwise just repositions the marker nodes — so the
/// per-frame playback cost is one node move, not a geometry upload. All points
/// are centred and scaled into a fixed cube so the framing holds as `rho`
/// changes the attractor's size.
///
/// SceneKit is darwin-only; like the rest of `App/`, this never enters the Kit.
struct AttractorSceneView: UIViewRepresentable {
  let samples: [AttractorSample]
  let twinSamples: [AttractorSample]
  /// Position of the travelling dot along the path, `0...1`; `nil` hides it.
  let markerFraction: Double?
  /// Bumped by the model on each re-integration; gates geometry rebuilds.
  let revision: Int

  /// The edge length the attractor is scaled to fill, in scene units.
  private let stageSize: Float = 24

  final class Coordinator {
    var lineNode: SCNNode?
    var twinNode: SCNNode?
    var startNode: SCNNode?
    var markerNode: SCNNode?
    var twinMarkerNode: SCNNode?
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
    // Look straight down the y-axis at the x–z plane — the classic two-winged
    // "butterfly" view (the two lobes sit at ±x, so they read as left and right
    // wings), with z as up. Half the earlier distance frames it about twice as
    // large to start. The user can still orbit and pinch from here.
    cameraNode.position = SCNVector3(0, -1.3 * stageSize, 0)
    cameraNode.look(
      at: SCNVector3Zero, up: SCNVector3(0, 0, 1), localFront: SCNVector3(0, 0, -1))
    scene.rootNode.addChildNode(cameraNode)

    let marker = Self.markerNode(radius: 0.7, color: .white)
    marker.isHidden = true
    scene.rootNode.addChildNode(marker)
    context.coordinator.markerNode = marker

    let twinMarker = Self.markerNode(radius: 0.7, color: UIColor(Palette.twin))
    twinMarker.isHidden = true
    scene.rootNode.addChildNode(twinMarker)
    context.coordinator.twinMarkerNode = twinMarker

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
    coordinator.lineNode?.removeFromParentNode()
    coordinator.twinNode?.removeFromParentNode()
    coordinator.startNode?.removeFromParentNode()
    coordinator.lineNode = nil
    coordinator.twinNode = nil
    coordinator.startNode = nil

    guard let bounds = Bounds(samples, twinSamples) else { return }
    let center = SCNVector3(bounds.centerX, bounds.centerY, bounds.centerZ)
    let scale = bounds.extent > 0 ? stageSize / bounds.extent : 1
    coordinator.center = center
    coordinator.scale = scale

    let line = Self.lineNode(
      from: samples, center: center, scale: scale, color: UIColor(Palette.attractor))
    scene.rootNode.addChildNode(line)
    coordinator.lineNode = line

    if !twinSamples.isEmpty {
      let twin = Self.lineNode(
        from: twinSamples, center: center, scale: scale, color: UIColor(Palette.twin))
      scene.rootNode.addChildNode(twin)
      coordinator.twinNode = twin
    }

    if let first = samples.first {
      let start = Self.markerNode(radius: 0.7, color: UIColor(Palette.prey))
      start.position = Self.transform(first, center: center, scale: scale)
      scene.rootNode.addChildNode(start)
      coordinator.startNode = start
    }
  }

  private func positionMarkers(coordinator: Coordinator) {
    guard let fraction = markerFraction,
      let position = Self.interpolated(
        samples, fraction: fraction, center: coordinator.center, scale: coordinator.scale)
    else {
      coordinator.markerNode?.isHidden = true
      coordinator.twinMarkerNode?.isHidden = true
      return
    }
    coordinator.markerNode?.isHidden = false
    coordinator.markerNode?.position = position

    if let twinPosition = Self.interpolated(
      twinSamples, fraction: fraction, center: coordinator.center, scale: coordinator.scale)
    {
      coordinator.twinMarkerNode?.isHidden = false
      coordinator.twinMarkerNode?.position = twinPosition
    } else {
      coordinator.twinMarkerNode?.isHidden = true
    }
  }

  // MARK: - Builders (pure)

  private static func lineNode(
    from samples: [AttractorSample], center: SCNVector3, scale: Float, color: UIColor
  ) -> SCNNode {
    var vertices = [SCNVector3]()
    vertices.reserveCapacity(samples.count)
    for sample in samples {
      vertices.append(transform(sample, center: center, scale: scale))
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

  private static func transform(_ s: AttractorSample, center: SCNVector3, scale: Float)
    -> SCNVector3
  {
    SCNVector3(
      (Float(s.x) - center.x) * scale,
      (Float(s.y) - center.y) * scale,
      (Float(s.z) - center.z) * scale)
  }

  private static func interpolated(
    _ samples: [AttractorSample], fraction: Double, center: SCNVector3, scale: Float
  ) -> SCNVector3? {
    let count = samples.count
    guard count > 0 else { return nil }
    guard count > 1 else { return transform(samples[0], center: center, scale: scale) }
    let clamped = min(max(fraction, 0), 1)
    let position = clamped * Double(count - 1)
    let index = min(Int(position), count - 2)
    let blend = Float(position - Double(index))
    let a = samples[index]
    let b = samples[index + 1]
    let x = Float(a.x) + (Float(b.x) - Float(a.x)) * blend
    let y = Float(a.y) + (Float(b.y) - Float(a.y)) * blend
    let z = Float(a.z) + (Float(b.z) - Float(a.z)) * blend
    return SCNVector3((x - center.x) * scale, (y - center.y) * scale, (z - center.z) * scale)
  }
}

/// The axis-aligned bounds of one or two trajectories — the centre to translate
/// to the origin and the largest extent to scale into the stage cube.
private struct Bounds {
  let centerX: Float
  let centerY: Float
  let centerZ: Float
  let extent: Float

  init?(_ first: [AttractorSample], _ second: [AttractorSample]) {
    var loX = Float.greatestFiniteMagnitude
    var loY = Float.greatestFiniteMagnitude
    var loZ = Float.greatestFiniteMagnitude
    var hiX = -Float.greatestFiniteMagnitude
    var hiY = -Float.greatestFiniteMagnitude
    var hiZ = -Float.greatestFiniteMagnitude
    var seen = false

    for samples in [first, second] {
      for sample in samples {
        seen = true
        let x = Float(sample.x)
        let y = Float(sample.y)
        let z = Float(sample.z)
        loX = min(loX, x)
        loY = min(loY, y)
        loZ = min(loZ, z)
        hiX = max(hiX, x)
        hiY = max(hiY, y)
        hiZ = max(hiZ, z)
      }
    }
    guard seen else { return nil }

    centerX = (loX + hiX) / 2
    centerY = (loY + hiY) / 2
    centerZ = (loZ + hiZ) / 2
    extent = max(hiX - loX, max(hiY - loY, hiZ - loZ))
  }
}
