import EasyModelerKit
import SwiftUI
import UIKit

/// The "Build your own system" playground — where the app earns its keep for
/// learning. A student opens onto the Benthic Ecology Model already wired up,
/// then remixes it: drag the coefficient and input sliders, retype an equation,
/// add a box or a coefficient, or load a different starter model. Every change
/// re-integrates live on the chart; a typo holds the last good run and names the
/// problem in plain language.
///
/// A 2D chart screen on the shared transport (like predator–prey and
/// radioactivity), pushed by `HomeScreen`. Sliders drag instantly; presets,
/// adds, and removes spring and tick, nil under Reduce Motion.
struct BuildScreen: View {
  @State private var model = BuildModel()
  @State private var playback = PlaybackModel(horizon: 365, sweepDuration: 10)
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var springAnimation: Animation? {
    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.85)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        presetRow
        chartCard
        timeSpanCard
        equationsCard
        inputsCard
        coefficientsCard
        helpersCard
        functionsFootnote
        ScienceCard(note: .buildYourOwn)
      }
      .padding()
    }
    .background { backgroundWash }
    .navigationTitle("Build Your Own")
    .navigationBarTitleDisplayMode(.inline)
    .fontDesign(.rounded)
    .tint(Palette.brand)
    .onAppear { playback.horizon = model.horizon }
    .onChange(of: model.horizon) { playback.horizon = model.horizon }
    .sensoryFeedback(.selection, trigger: playback.isPlaying)
    .sensoryFeedback(.selection, trigger: playback.speedIndex)
    .sensoryFeedback(.selection, trigger: model.showingHelpers)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: model.discreteEventCount)
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 16) {
      Image(systemName: "function")
        .font(.title)
        .foregroundStyle(Palette.builder)
        .frame(width: 52, height: 52)
        .background(Palette.builder.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 4) {
        Text("Build Your Own")
          .font(.title2.bold())
        Text("Write the rules for how things change, then watch them play out.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Presets

  private var presetRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        presetPill("Estuary", "drop.fill") { model.loadBenthos() }
        presetPill("Predator & Prey", "hare.fill") { model.loadPredatorPrey() }
        presetPill("Lorenz", "tornado") { model.loadLorenz() }
        presetPill("Scratch", "square.dashed") { model.loadScratch() }
      }
      .padding(.horizontal, 2)
      .padding(.trailing, 18)  // clear space under the "more" chevron cue
    }
    // Fade the edges so a pill dissolving off the side reads as "there is more",
    // and pin a chevron on the right so it is unmistakable that the row scrolls.
    .mask(
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: .black, location: 0.02),
          .init(color: .black, location: 0.86),
          .init(color: .clear, location: 1.0),
        ],
        startPoint: .leading, endPoint: .trailing)
    )
    .overlay(alignment: .trailing) {
      Image(systemName: "chevron.compact.right")
        .font(.title2.weight(.semibold))
        .foregroundStyle(Palette.builder)
        .allowsHitTesting(false)
    }
  }

  private func presetPill(_ title: String, _ symbol: String, _ action: @escaping () -> Void)
    -> some View
  {
    Button {
      withAnimation(springAnimation) {
        action()
        playback.horizon = model.horizon
      }
    } label: {
      Label(title, systemImage: symbol)
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Chart

  private var chartCard: some View {
    VStack(spacing: 12) {
      if model.hasHelpers {
        Picker("View", selection: chartModeBinding) {
          Text("States").tag(false)
          Text("Helpers").tag(true)
        }
        .pickerStyle(.segmented)
      }
      chartArea.frame(height: 260)
      TransportBar(playback: playback, tint: Palette.builder)

      if let error = model.parseError {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.footnote)
          .foregroundStyle(.orange)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Label(model.insight, systemImage: "waveform.path.ecg")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
  }

  private var chartArea: some View {
    Group {
      if playback.isPlaying {
        TimelineView(.animation) { context in
          SystemChart(
            samples: model.chartSamples, seriesNames: model.chartNames,
            now: model.chartSample(at: playback.playhead(at: context.date)))
        }
      } else {
        SystemChart(
          samples: model.chartSamples, seriesNames: model.chartNames,
          now: playback.restingHead.map { model.chartSample(at: $0) })
      }
    }
  }

  private var chartModeBinding: Binding<Bool> {
    Binding(
      get: { model.showingHelpers },
      set: { newValue in
        withAnimation(springAnimation) { model.showingHelpers = newValue }
      })
  }

  // MARK: - Time span

  private var timeSpanCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Time span", systemImage: "clock")
          .font(.subheadline)
        Spacer()
        Text("\(Int(model.horizon)) steps")
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(.quaternary, in: Capsule())
      }
      Slider(value: horizonBinding(), in: model.horizonRange)
        .tint(Palette.builder)
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Equations

  private var equationsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Equations", systemImage: "function")
          .font(.headline)
        Spacer()
        Text("\(model.boxCount) / \(BuildModel.maxBoxes) boxes")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      ForEach(model.equations) { equation in
        equationRow(equation)
      }

      addButton("Add equation", enabled: model.canAddBox) { model.addEquation() }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private func equationRow(_ equation: Equation) -> some View {
    let tint = Palette.seriesColor(colorIndex(equation))
    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Circle().fill(tint).frame(width: 10, height: 10)
        TextField("name", text: equationText(equation.id, \.name))
          .font(.subheadline.bold())
          .frame(width: 76)
          .textFieldStyle(.roundedBorder)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
        Spacer()
        if model.canRemoveEquation {
          removeButton { model.removeEquation(equation.id) }
        }
      }
      HStack(alignment: .top, spacing: 6) {
        Text("d\(equation.name)/dt =")
          .font(.subheadline.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .padding(.top, 7)
        expressionField("expression", equationText(equation.id, \.derivative))
      }
      ParameterSlider(
        title: "start", symbol: "smallcircle.filled.circle", tint: tint,
        range: equation.initialRange, value: equationValue(equation.id, \.initial))
    }
    .padding(.vertical, 6)
  }

  // MARK: - Inputs

  private var inputsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Inputs", systemImage: "slider.horizontal.3")
          .font(.headline)
        Spacer()
        Text("dial these; the equations read them")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      ForEach(model.inputs) { input in
        namedValueRow(
          name: inputName(input.id), value: inputValue(input.id),
          range: input.range, tint: Palette.salinity
        ) { model.removeInput(input.id) }
      }
      if model.inputs.isEmpty {
        Text("This system has no inputs. Add one for a value you want to dial.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      addButton("Add input", enabled: model.canAddBox) { model.addInput() }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Coefficients

  private var coefficientsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Coefficients", systemImage: "dial.medium")
          .font(.headline)
        Spacer()
        Text("\(model.coefficients.count) / \(BuildModel.maxCoefficients)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      ForEach(model.coefficients) { coefficient in
        namedValueRow(
          name: coefficientName(coefficient.id),
          value: coefficientValue(coefficient.id),
          range: coefficient.range, tint: Palette.builder
        ) {
          model.removeCoefficient(coefficient.id)
        }
      }

      addButton("Add coefficient", enabled: model.canAddCoefficient) { model.addCoefficient() }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Helpers

  private var helpersCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Helpers", systemImage: "text.append")
          .font(.headline)
        Spacer()
        Text("named steps the equations reuse")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      ForEach(model.helpers) { helper in
        helperRow(helper)
      }
      if model.helpers.isEmpty {
        Text("Helpers are optional. Use one to name a piece an equation repeats.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      addButton("Add helper", enabled: model.canAddHelper) { model.addHelper() }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private func helperRow(_ helper: HelperEq) -> some View {
    HStack(alignment: .top, spacing: 8) {
      TextField("name", text: helperText(helper.id, \.name))
        .font(.subheadline.monospaced())
        .frame(width: 76)
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
      Text("=")
        .font(.subheadline.monospaced())
        .foregroundStyle(.secondary)
        .padding(.top, 7)
      expressionField("expression", helperText(helper.id, \.expression))
      removeButton { model.removeHelper(helper.id) }
        .padding(.top, 4)
    }
  }

  /// A monospaced expression editor that grows to fit the whole equation as you
  /// type, so a long right-hand side is never clipped mid-edit. A manual bordered
  /// box rather than `.roundedBorder`, because that style stays single-line and
  /// ignores the vertical axis.
  private func expressionField(_ placeholder: String, _ text: Binding<String>) -> some View {
    TextField(placeholder, text: text, axis: .vertical)
      .font(.subheadline.monospaced())
      .lineLimit(1...8)
      .autocorrectionDisabled()
      .textInputAutocapitalization(.never)
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 7)
          .fill(Color(uiColor: .tertiarySystemFill))
          .overlay(
            RoundedRectangle(cornerRadius: 7)
              .stroke(Color(uiColor: .separator), lineWidth: 0.5))
      )
  }

  // MARK: - Footnote

  private var functionsFootnote: some View {
    Text(
      "You can use + - * / and ^ for powers, brackets, and the functions exp, ln, log, "
        + "log10, sqrt, abs, pow, sin, cos, tan, min, and max. Time is t."
    )
    .font(.caption2)
    .foregroundStyle(.tertiary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 4)
  }

  // MARK: - Reusable rows

  private func namedValueRow(
    name: Binding<String>, value: Binding<Double>, range: ClosedRange<Double>,
    tint: Color, onRemove: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 8) {
      TextField("name", text: name)
        .font(.subheadline.monospaced())
        .frame(width: 64)
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
      Slider(value: value, in: range)
        .tint(tint)
      TextField("value", value: value, format: .number.precision(.fractionLength(2)))
        .font(.subheadline.monospacedDigit())
        .frame(width: 60)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.numbersAndPunctuation)
        .multilineTextAlignment(.trailing)
      removeButton(action: onRemove)
    }
  }

  private func addButton(_ title: String, enabled: Bool, _ action: @escaping () -> Void)
    -> some View
  {
    Button {
      withAnimation(springAnimation) { action() }
    } label: {
      Label(title, systemImage: "plus.circle.fill")
        .font(.subheadline)
    }
    .buttonStyle(.bordered)
    .tint(Palette.builder)
    .disabled(!enabled)
  }

  private func removeButton(action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(springAnimation) { action() }
    } label: {
      Image(systemName: "minus.circle.fill")
        .foregroundStyle(.tertiary)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Remove")
  }

  private func colorIndex(_ equation: Equation) -> Int {
    model.equations.firstIndex { $0.id == equation.id } ?? 0
  }

  // MARK: - Editing bindings (locate by id so they survive add / remove)

  private func equationText(_ id: UUID, _ field: WritableKeyPath<Equation, String>) -> Binding<
    String
  > {
    Binding(
      get: { model.equations.first { $0.id == id }?[keyPath: field] ?? "" },
      set: {
        guard let i = model.equations.firstIndex(where: { $0.id == id }) else { return }
        model.equations[i][keyPath: field] = $0
        model.recompute()
      })
  }

  private func equationValue(_ id: UUID, _ field: WritableKeyPath<Equation, Double>) -> Binding<
    Double
  > {
    Binding(
      get: { model.equations.first { $0.id == id }?[keyPath: field] ?? 0 },
      set: {
        guard let i = model.equations.firstIndex(where: { $0.id == id }) else { return }
        model.equations[i][keyPath: field] = $0
        model.recompute()
      })
  }

  private func inputName(_ id: UUID) -> Binding<String> {
    Binding(
      get: { model.inputs.first { $0.id == id }?.name ?? "" },
      set: {
        guard let i = model.inputs.firstIndex(where: { $0.id == id }) else { return }
        model.inputs[i].name = $0
        model.recompute()
      })
  }

  private func inputValue(_ id: UUID) -> Binding<Double> {
    Binding(
      get: { model.inputs.first { $0.id == id }?.value ?? 0 },
      set: {
        guard let i = model.inputs.firstIndex(where: { $0.id == id }) else { return }
        model.inputs[i].value = $0
        model.recompute()
      })
  }

  private func coefficientName(_ id: UUID) -> Binding<String> {
    Binding(
      get: { model.coefficients.first { $0.id == id }?.name ?? "" },
      set: {
        guard let i = model.coefficients.firstIndex(where: { $0.id == id }) else { return }
        model.coefficients[i].name = $0
        model.recompute()
      })
  }

  private func coefficientValue(_ id: UUID) -> Binding<Double> {
    Binding(
      get: { model.coefficients.first { $0.id == id }?.value ?? 0 },
      set: {
        guard let i = model.coefficients.firstIndex(where: { $0.id == id }) else { return }
        model.coefficients[i].value = $0
        model.recompute()
      })
  }

  private func helperText(_ id: UUID, _ field: WritableKeyPath<HelperEq, String>) -> Binding<String>
  {
    Binding(
      get: { model.helpers.first { $0.id == id }?[keyPath: field] ?? "" },
      set: {
        guard let i = model.helpers.firstIndex(where: { $0.id == id }) else { return }
        model.helpers[i][keyPath: field] = $0
        model.recompute()
      })
  }

  private func horizonBinding() -> Binding<Double> {
    Binding(
      get: { model.horizon },
      set: {
        model.horizon = $0
        model.recompute()
      })
  }

  private var backgroundWash: some View {
    ZStack(alignment: .top) {
      Color(uiColor: .systemGroupedBackground)
      LinearGradient(
        colors: [Palette.builder.opacity(0.12), .clear],
        startPoint: .top, endPoint: .bottom
      )
      .frame(height: 340)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .ignoresSafeArea()
  }
}
