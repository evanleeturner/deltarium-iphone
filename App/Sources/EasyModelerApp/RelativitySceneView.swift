import EasyModelerKit
import SceneKit
import SwiftUI
import UIKit

/// The journey drawn as a 3D **worldtube** through spacetime, on a black stage you
/// orbit and pinch. It *grows out of the Sun as the ship flies*: a solid orange
/// tube, widest where the ship is slow and pinching to a thin waist where it is
/// fastest (the radius tracks 1/γ, so the pinch itself is the relativity), ribbed
/// at equal ticks of the ship's own clock (the ribs appear one by one as the ship
/// passes them, bunched at the slow ends and stretched across the fast middle).
/// The spacecraft rides the leading tip.
///
/// The tube is built from stacked frustum segments so it can be revealed up to the
/// playhead by toggling visibility — cheap every frame, no mesh rebuild. Inspired
/// by The Overview Effekt's "Time Dilation Visualized," on the app's dark ground.
/// SceneKit is darwin-only; like the rest of `App/`, this never enters the Kit.
struct RelativitySceneView: UIViewRepresentable {
  let samples: [RelativitySample]
  let destinationName: String
  /// How much of the tube to draw, `0...1` — grows with the ship while playing,
  /// full when idle before a first play.
  let revealFraction: Double
  /// Position of the travelling spacecraft, `0...1`; `nil` hides it.
  let markerFraction: Double?
  /// Bumped by the model on each re-integration; gates the tube rebuild.
  let revision: Int

  /// Half the tube's fixed on-screen length (scene units) — the tube always spans
  /// the stage regardless of the real distance, so the *shape* is what reads.
  private let half: Float = 11
  /// The tube's widest radius (at rest, at the two ends).
  private let maxRadius: Float = 2.4
  /// A floor so an extreme trip's waist stays a visible thread, not nothing.
  private let minRadius: Float = 0.06

  final class Coordinator {
    var segments: [(node: SCNNode, start: Int)] = []
    var ribs: [(node: SCNNode, index: Int)] = []
    var spacecraft: SCNNode?
    var destinationLabel: SCNNode?
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
      Self.lightNode(type: .omni, intensity: 950, at: SCNVector3(-6, 22, 34)))
    scene.rootNode.addChildNode(Self.lightNode(type: .ambient, intensity: 420, at: .init()))

    let coordinator = context.coordinator

    let sun = SCNNode(geometry: SCNSphere(radius: 0.72))
    sun.geometry?.materials = [
      Self.glowMaterial(UIColor(red: 0.98, green: 0.94, blue: 0.82, alpha: 1), intensity: 1)
    ]
    sun.position = SCNVector3(-half, 0, 0)
    scene.rootNode.addChildNode(sun)
    scene.rootNode.addChildNode(
      Self.label("Sol", color: UIColor(white: 0.96, alpha: 1), at: SCNVector3(-half, 3.2, 0)))

    let target = SCNNode(geometry: SCNSphere(radius: 0.5))
    target.geometry?.materials = [Self.glowMaterial(UIColor(white: 0.62, alpha: 1), intensity: 0.9)]
    target.position = SCNVector3(half, 0, 0)
    scene.rootNode.addChildNode(target)
    let destLabel = Self.label(
      destinationName, color: UIColor(Palette.relativity), at: SCNVector3(half, 3.2, 0))
    scene.rootNode.addChildNode(destLabel)
    coordinator.destinationLabel = destLabel

    let craft = Self.rocketNode()
    craft.isHidden = true
    scene.rootNode.addChildNode(craft)
    coordinator.spacecraft = craft

    return scnView
  }

  func updateUIView(_ scnView: SCNView, context: Context) {
    guard let scene = scnView.scene else { return }
    let coordinator = context.coordinator

    if coordinator.lastRevision != revision {
      coordinator.lastRevision = revision
      rebuildTube(in: scene, coordinator: coordinator)
      (coordinator.destinationLabel?.geometry as? SCNText)?.string = destinationName
    }
    reveal(coordinator: coordinator)
    positionSpacecraft(coordinator: coordinator)
  }

  // MARK: - Build

  private func worldX(_ sample: RelativitySample, total: Double) -> Float {
    -half + Float(sample.distanceLightYears / total) * 2 * half
  }

  private func radius(_ sample: RelativitySample) -> Float {
    max(minRadius, maxRadius * Float((1 - sample.beta * sample.beta).squareRoot()))  // 1/γ
  }

  private func rebuildTube(in scene: SCNScene, coordinator: Coordinator) {
    for segment in coordinator.segments { segment.node.removeFromParentNode() }
    for rib in coordinator.ribs { rib.node.removeFromParentNode() }
    coordinator.segments = []
    coordinator.ribs = []
    guard let total = samples.last?.distanceLightYears, total > 0, samples.count > 2 else { return }

    // Subsample to a set of profile points; a frustum between each consecutive pair.
    let profileCount = min(90, samples.count)
    let step = max(1, (samples.count - 1) / (profileCount - 1))
    var profile: [Int] = stride(from: 0, to: samples.count, by: step).map { $0 }
    if profile.last != samples.count - 1 { profile.append(samples.count - 1) }

    let material = Self.litMaterial(UIColor(Palette.worldline), emission: 0.12)
    for k in 0..<(profile.count - 1) {
      let a = profile[k]
      let b = profile[k + 1]
      let xA = worldX(samples[a], total: total)
      let xB = worldX(samples[b], total: total)
      let height = max(0.001, xB - xA)
      let cone = SCNCone(
        topRadius: CGFloat(radius(samples[b])), bottomRadius: CGFloat(radius(samples[a])),
        height: CGFloat(height))
      cone.radialSegmentCount = 24
      cone.materials = [material]
      let node = SCNNode(geometry: cone)
      node.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)  // cone axis y → x, bottom at −x
      node.position = SCNVector3((xA + xB) / 2, 0, 0)
      scene.rootNode.addChildNode(node)
      coordinator.segments.append((node, a))
    }

    // Ribs at equal ship-time ticks (one per ship-year, capped): the clock ticks.
    let ribMaterial = Self.litMaterial(UIColor(white: 0.32, alpha: 1), emission: 0)
    let shipYears = samples.last?.shipYears ?? 0
    let ribCount = min(40, max(6, Int(shipYears.rounded())))
    let ribStride = max(1, samples.count / ribCount)
    var index = ribStride
    while index < samples.count - 1 {
      let sample = samples[index]
      let rib = SCNNode(
        geometry: SCNTorus(ringRadius: CGFloat(radius(sample)) + 0.02, pipeRadius: 0.055))
      rib.geometry?.materials = [ribMaterial]
      rib.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
      rib.position = SCNVector3(worldX(sample, total: total), 0, 0)
      scene.rootNode.addChildNode(rib)
      coordinator.ribs.append((rib, index))
      index += ribStride
    }
  }

  // MARK: - Reveal + spacecraft

  private func reveal(coordinator: Coordinator) {
    guard samples.count > 1 else { return }
    let head = min(max(revealFraction, 0), 1) * Double(samples.count - 1)
    for segment in coordinator.segments { segment.node.isHidden = Double(segment.start) > head }
    for rib in coordinator.ribs { rib.node.isHidden = Double(rib.index) > head }
  }

  private func positionSpacecraft(coordinator: Coordinator) {
    guard let fraction = markerFraction, let craft = coordinator.spacecraft,
      let total = samples.last?.distanceLightYears, total > 0, samples.count > 1
    else {
      coordinator.spacecraft?.isHidden = true
      return
    }
    craft.isHidden = false
    let clamped = min(max(fraction, 0), 1)
    let position = clamped * Double(samples.count - 1)
    let index = min(Int(position), samples.count - 2)
    let blend = position - Double(index)
    let distance =
      samples[index].distanceLightYears
      + (samples[index + 1].distanceLightYears - samples[index].distanceLightYears) * blend
    // Ride just ahead of the tube's leading tip so the rocket clears it rather than
    // sitting buried inside; ease off the lead as it parks at the destination.
    let tipX = -half + Float(distance / total) * 2 * half
    craft.position = SCNVector3(min(tipX + 1.1, half), 0, 0)
    // Flip at the midpoint: turn the engine around to brake for the second half.
    craft.eulerAngles = SCNVector3(0, clamped > 0.5 ? Float.pi : 0, 0)
  }

  // MARK: - Builders (pure)

  private static func cameraNode() -> SCNNode {
    let node = SCNNode()
    let camera = SCNCamera()
    camera.zNear = 0.1
    camera.zFar = 1000
    node.camera = camera
    node.position = SCNVector3(-1, 5, 25)
    node.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    return node
  }

  private static func lightNode(
    type: SCNLight.LightType, intensity: CGFloat, at position: SCNVector3
  ) -> SCNNode {
    let node = SCNNode()
    let light = SCNLight()
    light.type = type
    light.intensity = intensity
    node.light = light
    node.position = position
    return node
  }

  private static func label(_ string: String, color: UIColor, at position: SCNVector3) -> SCNNode {
    let text = SCNText(string: string, extrusionDepth: 0.5)
    text.font = .systemFont(ofSize: 4, weight: .semibold)
    text.flatness = 0.1
    text.materials = [glowMaterial(color, intensity: 1)]
    let node = SCNNode(geometry: text)
    node.scale = SCNVector3(0.3, 0.3, 0.3)
    let (minB, maxB) = text.boundingBox
    node.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2, minB.y, 0)
    node.position = position
    node.constraints = [SCNBillboardConstraint()]
    return node
  }

  /// A little rocket ship: a pale fuselage, a coloured nose cone, three fins, a
  /// nozzle, and an engine flame. Built pointing along +x (the direction of
  /// travel) inside a container the flip yaws 180° at the midpoint, so the same
  /// model reads as thrusting forward, then braking.
  private static func rocketNode() -> SCNNode {
    let craft = SCNNode()
    let rocket = SCNNode()
    rocket.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)  // built along +y, turned to point +x

    let fuselage = SCNNode(geometry: SCNCylinder(radius: 0.16, height: 0.9))
    fuselage.geometry?.materials = [litMaterial(UIColor(white: 0.87, alpha: 1), emission: 0)]
    rocket.addChildNode(fuselage)

    let nose = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.16, height: 0.42))
    nose.position = SCNVector3(0, 0.66, 0)
    nose.geometry?.materials = [litMaterial(UIColor(Palette.relativity), emission: 0.25)]
    rocket.addChildNode(nose)

    for i in 0..<3 {
      let holder = SCNNode()
      holder.eulerAngles = SCNVector3(0, Float(i) / 3 * 2 * .pi, 0)
      let fin = SCNNode(
        geometry: SCNBox(width: 0.22, height: 0.3, length: 0.03, chamferRadius: 0.01))
      fin.position = SCNVector3(0.17, -0.3, 0)
      fin.geometry?.materials = [litMaterial(UIColor(Palette.relativity), emission: 0.2)]
      holder.addChildNode(fin)
      rocket.addChildNode(holder)
    }

    let nozzle = SCNNode(geometry: SCNCone(topRadius: 0.16, bottomRadius: 0.1, height: 0.16))
    nozzle.position = SCNVector3(0, -0.53, 0)
    nozzle.geometry?.materials = [litMaterial(UIColor(white: 0.4, alpha: 1), emission: 0)]
    rocket.addChildNode(nozzle)

    let flame = SCNNode(geometry: SCNCone(topRadius: 0.09, bottomRadius: 0, height: 0.34))
    flame.position = SCNVector3(0, -0.77, 0)
    flame.geometry?.materials = [glowMaterial(UIColor(Palette.worldline), intensity: 1)]
    rocket.addChildNode(flame)

    craft.addChildNode(rocket)
    return craft
  }

  private static func litMaterial(_ color: UIColor, emission: CGFloat) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .blinn
    material.diffuse.contents = color
    if emission > 0 { material.emission.contents = color.withAlphaComponent(emission) }
    return material
  }

  private static func glowMaterial(_ color: UIColor, intensity: CGFloat) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .constant
    material.diffuse.contents = color
    material.emission.contents = color.withAlphaComponent(intensity)
    return material
  }
}
