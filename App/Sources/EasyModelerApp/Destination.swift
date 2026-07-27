/// A real destination for the relativistic journey, with its distance in
/// light-years — the video's set, from a neighbour star to the edge of the
/// observable universe.
struct Destination: Identifiable, Equatable {
  let name: String
  let distanceLightYears: Double
  /// A short line for the readout (what makes this target notable).
  let blurb: String

  var id: String { name }

  static let all: [Destination] = [
    Destination(
      name: "Alpha Centauri", distanceLightYears: 4.37,
      blurb: "The nearest star system."),
    Destination(
      name: "Tau Ceti", distanceLightYears: 11.9,
      blurb: "A sun-like star with its own planets."),
    Destination(
      name: "Betelgeuse", distanceLightYears: 548,
      blurb: "The red giant in Orion's shoulder."),
    Destination(
      name: "Center of the galaxy", distanceLightYears: 26_000,
      blurb: "The giant black hole at the Milky Way's heart."),
    Destination(
      name: "Andromeda", distanceLightYears: 2_537_000,
      blurb: "The nearest big galaxy to our own."),
    Destination(
      name: "The Great Attractor", distanceLightYears: 220_000_000,
      blurb: "A hidden mass pulling our whole galaxy toward it."),
    Destination(
      name: "Boötes Void", distanceLightYears: 700_000_000,
      blurb: "A giant empty bubble of almost nothing. The ultimate get away from it all."),
    Destination(
      name: "TON 618", distanceLightYears: 18_200_000_000,
      blurb: "The biggest black hole ever found."),
    Destination(
      name: "Edge of the visible universe", distanceLightYears: 46_500_000_000,
      blurb: "As far as anything can be seen."),
  ]
}
