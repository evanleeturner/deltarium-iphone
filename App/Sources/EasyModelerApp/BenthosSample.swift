/// One sampled day of an open benthos run: the time, the two state variables
/// (nutrient and benthic biomass), and the conditions driving it that day.
/// `Identifiable` by day so Swift Charts can key the marks.
struct BenthosSample: Identifiable {
  let day: Double
  let nutrient: Double
  let benthos: Double
  let temperature: Double
  let salinity: Double

  var id: Double { day }
}
