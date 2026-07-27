/// The "The Science" note for a model: a plain-language paragraph on the science and
/// why it matters, a sentence on who devised the method, and the APA reference(s).
///
/// The summary paragraphs are written in the outward / de-AI register (EVANS_OUTWARD)
/// for kids and lay readers: open with the reader's problem, explain every term, keep
/// the prose warm and human, and stay clear of the AI tells (dash chains, antithesis,
/// theatre, stock phrases, inside jargon). Citations are verified against their
/// original sources.
struct ScienceNote {
  let summary: String
  let author: String
  let references: [String]

  static let lotkaVolterra = ScienceNote(
    summary:
      "Foxes eat rabbits, and that one fact ties their numbers together. When rabbits "
      + "are everywhere the foxes do well and multiply, but all those extra foxes eat "
      + "the rabbits down, and then the hungry foxes die back, which lets the rabbits "
      + "recover. So the two populations rise and fall in endless cycles, always a little "
      + "out of step. The surprise was that you don't need bad weather or bad luck to get "
      + "these swings. The chase by itself is enough. The same two equations still show "
      + "up wherever one living thing feeds on another, from wildlife to the spread of "
      + "disease.",
    author:
      "The equations came, independently, from Alfred Lotka in 1925 and Vito Volterra "
      + "in 1926. Volterra worked his out to explain why predatory fish had suddenly "
      + "become more common in the Adriatic Sea just after the First World War.",
    references: [
      "Lotka, A. J. (1925). Elements of physical biology. Williams & Wilkins.",
      "Volterra, V. (1926). Fluctuations in the abundance of a species considered "
        + "mathematically. Nature, 118, 558–560.",
    ])

  static let lorenz = ScienceNote(
    summary:
      "Weather is famously hard to predict, and this little model helped explain why. "
      + "Edward Lorenz was running a simple simulation of rolling air when he noticed "
      + "something odd: start it again with the tiniest change, and before long the two "
      + "runs looked nothing alike. That's the butterfly effect, the idea that something "
      + "as small as a butterfly flapping its wings could tip the weather days later. The "
      + "system follows exact rules, yet it never repeats and can't be predicted far "
      + "ahead, because tiny errors grow fast. That discovery grew into what we now call "
      + "chaos theory, and it's why forecasts get shaky past a week or so.",
    author:
      "Edward Lorenz, a mathematician and weather scientist at MIT, published the system "
      + "in 1963 after spotting the effect on an early computer.",
    references: [
      "Lorenz, E. N. (1963). Deterministic nonperiodic flow. Journal of the Atmospheric "
        + "Sciences, 20(2), 130–141."
    ])

  static let benthos = ScienceNote(
    summary:
      "An estuary is where a river meets the sea, a rich, half-salty nursery for all "
      + "sorts of life. As the seasons change the water's warmth, its saltiness, and how "
      + "much food is around, the creatures living there boom and then crash, over and "
      + "over. A model like this one feeds nutrients into the water and follows how that "
      + "community grows and fades across the year. Getting it right matters, because "
      + "people have to decide how much river water to let reach a bay, and that choice "
      + "can make or break the life inside it. Estuaries are some of the most crowded, "
      + "productive places on Earth, and also some of the easiest to harm.",
    author:
      "This one draws on the coastal-lagoon research of Evan Turner and his colleagues "
      + "(2014), who tested five different ways of modeling the life in Texas lagoons to "
      + "see which one worked best.",
    references: [
      "Turner, E. L., Bruesewitz, D. A., Mooney, R. F., Montagna, P. A., McClelland, "
        + "J. W., Sadovski, A., & Buskey, E. J. (2014). Comparing performance of five "
        + "nutrient phytoplankton zooplankton (NPZ) models in coastal lagoons. Ecological "
        + "Modelling, 277, 13–26."
    ])

  static let threeBody = ScienceNote(
    summary:
      "Two objects circling each other under gravity are easy to predict. Add a third, "
      + "and the neat math falls apart. There's no general formula for how three bodies "
      + "will move, and more than a century ago Henri Poincaré showed the motion is "
      + "usually chaotic. Even so, a few perfect patterns hide inside that chaos. In one "
      + "of them, the figure eight, three equal stars chase one another forever around a "
      + "single looping path. That orbit was first found on a computer in 1993 and proven "
      + "to be real in 2000.",
    author:
      "The figure-eight orbit was first spotted on a computer by Cristopher Moore in "
      + "1993 and later proven to exist by the mathematicians Alain Chenciner and Richard "
      + "Montgomery in 2000.",
    references: [
      "Chenciner, A., & Montgomery, R. (2000). A remarkable periodic solution of the "
        + "three-body problem in the case of equal masses. Annals of Mathematics, 152(3), "
        + "881–901."
    ])

  static let lagrange = ScienceNote(
    summary:
      "Out in space, where do you park a telescope so it stays put? When two big bodies "
      + "orbit each other, like the Earth and the Moon, it turns out there are five sweet "
      + "spots, called the Lagrange points, where a smaller object can ride along without "
      + "drifting off. Gravity and the swing of the orbit cancel out at those spots. Two "
      + "of them are steady enough to gather drifting dust and asteroids, and the others "
      + "make handy, if slippery, parking places. Real missions use them all the time. "
      + "The James Webb Space Telescope rides one of the Sun and Earth's points, a "
      + "million miles out, with the Sun always at its back.",
    author:
      "The idea goes back to Leonhard Euler, who found three of the points in 1765, and "
      + "Joseph-Louis Lagrange, who found the other two in 1772.",
    references: [
      "Lagrange, J.-L. (1772). Essai sur le problème des trois corps [Essay on the "
        + "three-body problem]. Œuvres de Lagrange, 6, 229–331."
    ])

  static let radioactivity = ScienceNote(
    summary:
      "How long does fallout stay dangerous? That depends on what it's made of, and on a "
      + "strange but steady kind of clock. Radioactive atoms are unstable, and each kind "
      + "breaks apart at its own fixed pace, set by its half-life, the time it takes for "
      + "half of them to go. The twist is that whatever an atom turns into is often "
      + "radioactive too, so it keeps decaying down a chain until it finally lands on "
      + "something stable. That's why the danger doesn't simply disappear. Figuring out "
      + "how it fades matters for dating ancient bones, storing nuclear waste, treating "
      + "cancer, and cleaning up after an accident.",
    author:
      "The decay law was worked out by Ernest Rutherford and Frederick Soddy in 1902, "
      + "and Harry Bateman solved the math for a full decay chain in 1910.",
    references: [
      "Rutherford, E., & Soddy, F. (1902). The cause and nature of radioactivity. "
        + "Philosophical Magazine, 4(21), 370–396.",
      "Bateman, H. (1910). The solution of a system of differential equations occurring "
        + "in the theory of radioactive transformations. Proceedings of the Cambridge "
        + "Philosophical Society, 15, 423–427.",
    ])

  static let buildYourOwn = ScienceNote(
    summary:
      "Every model in this app is really a set of rules for how things change from one "
      + "moment to the next. Rabbits breed and foxes eat them. Warmth and salt push the "
      + "life in a marsh up or down. Write those rules down as equations and the app takes "
      + "over, stepping them forward in tiny slices of time and drawing what happens. This "
      + "screen hands you the pen. Start from the estuary model already loaded here, change "
      + "a number, add a box, or write an equation of your own, and watch the idea play out "
      + "on the chart. It is the same kind of math working scientists use to study "
      + "populations, chemistry, and the climate, shrunk down small enough to hold in your "
      + "hand.",
    author:
      "The trick for following an equation forward in time was worked out around the year "
      + "1900 by the German mathematicians Carl Runge and Martin Wilhelm Kutta. Their idea, "
      + "refined by John Dormand and Peter Prince in 1980, is the exact method running "
      + "inside this app, and versions of it still steer spacecraft and forecast the weather.",
    references: [
      "Runge, C. (1895). Über die numerische Auflösung von Differentialgleichungen. "
        + "Mathematische Annalen, 46(2), 167–178.",
      "Kutta, W. (1901). Beitrag zur näherungsweisen Integration totaler "
        + "Differentialgleichungen. Zeitschrift für Mathematik und Physik, 46, 435–453.",
      "Dormand, J. R., & Prince, P. J. (1980). A family of embedded Runge-Kutta formulae. "
        + "Journal of Computational and Applied Mathematics, 6(1), 19–26.",
    ])

  static let relativity = ScienceNote(
    summary:
      "The faster you move, the slower your own clock runs. It sounds impossible, but it "
      + "is real and measured every day. Einstein worked out that nothing can outrun light, "
      + "and that the closer you get to that speed, the more your own time slows compared to "
      + "the people you left behind. So a crew on a fast enough ship could cross to a distant "
      + "star in a few years of their own lives while centuries, or even millions of years, "
      + "pass back on Earth. They arrive in the future. The catch is fuel. Getting near light "
      + "speed takes a staggering amount of it, far more than the mass of the ship itself, "
      + "which is the real reason starflight is so hard.",
    author:
      "Time dilation comes from Albert Einstein's special theory of relativity, published in "
      + "1905 while he was working in a patent office. The astrophage fuel here is borrowed "
      + "from Andy Weir's novel Project Hail Mary, an invented microbe that turns almost all "
      + "of its mass into light, the kind of near-perfect fuel a real starship would need.",
    references: [
      "Einstein, A. (1905). Zur Elektrodynamik bewegter Körper [On the electrodynamics of "
        + "moving bodies]. Annalen der Physik, 17(10), 891–921.",
      "Weir, A. (2021). Project Hail Mary. Ballantine Books.",
    ])
}
