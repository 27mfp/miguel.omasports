.pragma library

// ============================================================================
// MATCHDAY MULTI-SPORT DATA ENGINE
// Supports: Football (FotMob), NBA, F1, NFL, MLB, NHL (ESPN / Jolpica)
// ============================================================================

// How long an idle match stays in the notification history past its last poll.
// Six hours covers a full match lifecycle (kickoff → 2h game → 4h buffer for
// late post-game alerts) without retaining unbounded ids in memory.
var NOTIFICATION_TTL_MS = 6 * 3600 * 1000

// Polling intervals offered by the UI picker. The dropdown, the clamp logic
// (parseState / setRefreshMinutes) and the polling timer all derive from this
// single list so a new value only needs to be added once.
function refreshIntervalOptions() {
  return [
    { value: "5", label: "5 min" },
    { value: "10", label: "10 min" },
    { value: "15", label: "15 min" },
    { value: "30", label: "30 min" },
    { value: "45", label: "45 min" },
    { value: "60", label: "60 min" }
  ]
}

function parseMatchTimeMs(match) {
  var t = Date.parse(match && match.time || "")
  return isNaN(t) ? NaN : t
}

var supportedSports = [
  { value: "football", label: "Football", icon: "⚽", description: "100+ Leagues & Cups" },
  { value: "nba", label: "NBA", icon: "🏀", description: "National Basketball Assn" },
  { value: "f1", label: "Formula 1", icon: "🏎", description: "FIA F1 World Championship" },
  { value: "nfl", label: "NFL", icon: "🏈", description: "National Football League" },
  { value: "mlb", label: "MLB", icon: "⚾", description: "Major League Baseball" },
  { value: "nhl", label: "NHL", icon: "🏒", description: "National Hockey League" }
]

// FotMob league catalogue
var supportedLeagues = [
  { value: "47", label: "Premier League", description: "England", region: "Europe" },
  { value: "87", label: "La Liga", description: "Spain", region: "Europe" },
  { value: "54", label: "Bundesliga", description: "Germany", region: "Europe" },
  { value: "146", label: "2. Bundesliga", description: "Germany", region: "Europe" },
  { value: "208", label: "3. Liga", description: "Germany", region: "Europe" },
  { value: "512", label: "Regionalliga", description: "Germany", region: "Europe" },
  { value: "55", label: "Serie A", description: "Italy", region: "Europe" },
  { value: "86", label: "Serie B", description: "Italy", region: "Europe" },
  { value: "53", label: "Ligue 1", description: "France", region: "Europe" },
  { value: "110", label: "Ligue 2", description: "France", region: "Europe" },
  { value: "9227", label: "Women's Super League", description: "England", region: "Europe" },
  { value: "9907", label: "Liga F", description: "Spain", region: "Europe" },
  { value: "9676", label: "Frauen-Bundesliga", description: "Germany", region: "Europe" },
  { value: "10178", label: "Serie A Femminile", description: "Italy", region: "Europe" },
  { value: "9667", label: "Première Ligue Féminine", description: "France", region: "Europe" },
  { value: "67", label: "Allsvenskan", description: "Sweden", region: "Europe" },
  { value: "38", label: "Austrian Bundesliga", description: "Austria", region: "Europe" },
  { value: "40", label: "Belgian First Division", description: "Belgium", region: "Europe" },
  { value: "48", label: "EFL Championship", description: "England", region: "Europe" },
  { value: "108", label: "EFL League One", description: "England", region: "Europe" },
  { value: "109", label: "EFL League Two", description: "England", region: "Europe" },
  { value: "196", label: "Ekstraklasa", description: "Poland", region: "Europe" },
  { value: "57", label: "Eredivisie", description: "Netherlands", region: "Europe" },
  { value: "218", label: "League of Ireland First Division", description: "Ireland", region: "Europe" },
  { value: "126", label: "League of Ireland Premier Division", description: "Ireland", region: "Europe" },
  { value: "61", label: "Primeira Liga", description: "Portugal", region: "Europe" },
  { value: "10215", label: "Primeira Liga Qualification", description: "Portugal", region: "Europe" },
  { value: "185", label: "Liga Portugal 2", description: "Portugal", region: "Europe" },
  { value: "9668", label: "Liga Portugal 2 Qualification", description: "Portugal", region: "Europe" },
  { value: "64", label: "Scottish Premiership", description: "Scotland", region: "Europe" },
  { value: "135", label: "Super League 1", description: "Greece", region: "Europe" },
  { value: "46", label: "Superligaen", description: "Denmark", region: "Europe" },
  { value: "85", label: "1. Division", description: "Denmark", region: "Europe" },
  { value: "59", label: "Eliteserien", description: "Norway", region: "Europe" },
  { value: "203", label: "1. Divisjon", description: "Norway", region: "Europe" },
  { value: "71", label: "Süper Lig", description: "Turkey", region: "Europe" },
  { value: "69", label: "Swiss Super League", description: "Switzerland", region: "Europe" },
  { value: "63", label: "Russian Premier League", description: "Russia", region: "Europe" },
  { value: "441", label: "Ukrainian Premier League", description: "Ukraine", region: "Europe" },
  { value: "42", label: "UEFA Champions League", description: "Europe", region: "Europe" },
  { value: "10216", label: "UEFA Conference League", description: "Europe", region: "Europe" },
  { value: "73", label: "UEFA Europa League", description: "Europe", region: "Europe" },
  { value: "50", label: "UEFA Euro", description: "Europe", region: "Europe" },
  { value: "292", label: "UEFA Women's Euro", description: "Europe", region: "Europe" },
  { value: "9375", label: "Women's UEFA Champions League", description: "Europe", region: "Europe" },
  { value: "138", label: "Copa del Rey", description: "Spain", region: "Europe" },
  { value: "139", label: "Supercopa de España", description: "Spain", region: "Europe" },
  { value: "132", label: "FA Cup", description: "England", region: "Europe" },
  { value: "209", label: "DFB Pokal", description: "Germany", region: "Europe" },
  { value: "10650", label: "Women's DFB Pokal", description: "Germany", region: "Europe" },
  { value: "141", label: "Coppa Italia", description: "Italy", region: "Europe" },
  { value: "134", label: "Coupe de France", description: "France", region: "Europe" },
  { value: "186", label: "Taça de Portugal", description: "Portugal", region: "Europe" },
  { value: "187", label: "Taça da Liga", description: "Portugal", region: "Europe" },
  { value: "188", label: "Supertaça Cândido de Oliveira", description: "Portugal", region: "Europe" },
  { value: "297", label: "CONCACAF Champions Cup", description: "North America", region: "Americas" },
  { value: "298", label: "CONCACAF Gold Cup", description: "North America", region: "Americas" },
  { value: "9821", label: "CONCACAF Nations League", description: "North America", region: "Americas" },
  { value: "268", label: "Brasileirão Série A", description: "Brazil", region: "Americas" },
  { value: "8814", label: "Brasileirão Série B", description: "Brazil", region: "Americas" },
  { value: "9067", label: "Copa do Brasil", description: "Brazil", region: "Americas" },
  { value: "10077", label: "Supercopa do Brasil", description: "Brazil", region: "Americas" },
  { value: "10244", label: "Paulista", description: "Brazil", region: "Americas" },
  { value: "10272", label: "Carioca", description: "Brazil", region: "Americas" },
  { value: "10273", label: "Mineiro", description: "Brazil", region: "Americas" },
  { value: "10274", label: "Gaúcho", description: "Brazil", region: "Americas" },
  { value: "9429", label: "Nordeste", description: "Brazil", region: "Americas" },
  { value: "10291", label: "Goiano", description: "Brazil", region: "Americas" },
  { value: "44", label: "Copa America", description: "South America", region: "Americas" },
  { value: "9490", label: "Copa Colombia", description: "Colombia", region: "Americas" },
  { value: "45", label: "Copa Libertadores", description: "South America", region: "Americas" },
  { value: "299", label: "Copa Sudamericana", description: "South America", region: "Americas" },
  { value: "491", label: "Recopa Sudamericana", description: "South America", region: "Americas" },
  { value: "112", label: "Liga Profesional", description: "Argentina", region: "Americas" },
  { value: "274", label: "Primera A", description: "Colombia", region: "Americas" },
  { value: "9125", label: "Primera B", description: "Colombia", region: "Americas" },
  { value: "161", label: "Primera Division", description: "Uruguay", region: "Americas" },
  { value: "273", label: "Primera Division", description: "Chile", region: "Americas" },
  { value: "131", label: "Liga 1", description: "Peru", region: "Americas" },
  { value: "246", label: "Serie A", description: "Ecuador", region: "Americas" },
  { value: "130", label: "MLS", description: "USA", region: "Americas" },
  { value: "8972", label: "USL Championship", description: "USA", region: "Americas" },
  { value: "9296", label: "USL League One", description: "USA", region: "Americas" },
  { value: "9134", label: "NWSL", description: "USA", region: "Americas" },
  { value: "10699", label: "USL Gainsbridge Super League", description: "USA", region: "Americas" },
  { value: "230", label: "Liga MX", description: "Mexico", region: "Americas" },
  { value: "536", label: "Saudi Pro League", description: "Saudi Arabia", region: "Global" },
  { value: "525", label: "AFC Champions League Elite", description: "Asia", region: "Global" },
  { value: "9469", label: "AFC Champions League Two", description: "Asia", region: "Global" },
  { value: "9478", label: "Indian Super League", description: "India", region: "Global" },
  { value: "223", label: "J. League", description: "Japan", region: "Global" },
  { value: "9080", label: "K League 1", description: "South Korea", region: "Global" },
  { value: "9137", label: "Chinese League One", description: "China", region: "Global" },
  { value: "535", label: "Qatar Stars League", description: "Qatar", region: "Global" },
  { value: "113", label: "A-League", description: "Australia", region: "Global" },
  { value: "526", label: "CAF Champions League", description: "Africa", region: "Global" },
  { value: "519", label: "Egyptian Premier League", description: "Egypt", region: "Global" },
  { value: "537", label: "Premier Soccer League", description: "South Africa", region: "Global" },
  { value: "530", label: "Botola Pro", description: "Morocco", region: "Global" },
  { value: "289", label: "Africa Cup of Nations", description: "International", region: "Global" },
  { value: "77", label: "FIFA World Cup", description: "International", region: "Global" },
  { value: "76", label: "Women's FIFA World Cup", description: "International", region: "Global" },
  { value: "78", label: "FIFA Club World Cup", description: "International", region: "Global" },
  { value: "9806", label: "UEFA Nations League", description: "International", region: "Global" },
  { value: "10304", label: "Finalissima", description: "International", region: "Global" },
  { value: "489", label: "Club Friendlies", description: "International", region: "Global" },
  { value: "114", label: "International Friendlies", description: "International", region: "Global" }
]

// Pre-populated NBA Teams Catalogue
var nbaTeams = [
  { value: "1", label: "Atlanta Hawks", description: "Eastern · Southeast" },
  { value: "2", label: "Boston Celtics", description: "Eastern · Atlantic" },
  { value: "17", label: "Brooklyn Nets", description: "Eastern · Atlantic" },
  { value: "30", label: "Charlotte Hornets", description: "Eastern · Southeast" },
  { value: "4", label: "Chicago Bulls", description: "Eastern · Central" },
  { value: "5", label: "Cleveland Cavaliers", description: "Eastern · Central" },
  { value: "6", label: "Dallas Mavericks", description: "Western · Southwest" },
  { value: "7", label: "Denver Nuggets", description: "Western · Northwest" },
  { value: "8", label: "Detroit Pistons", description: "Eastern · Central" },
  { value: "9", label: "Golden State Warriors", description: "Western · Pacific" },
  { value: "10", label: "Houston Rockets", description: "Western · Southwest" },
  { value: "11", label: "Indiana Pacers", description: "Eastern · Central" },
  { value: "12", label: "LA Clippers", description: "Western · Pacific" },
  { value: "13", label: "Los Angeles Lakers", description: "Western · Pacific" },
  { value: "29", label: "Memphis Grizzlies", description: "Western · Southwest" },
  { value: "14", label: "Miami Heat", description: "Eastern · Southeast" },
  { value: "15", label: "Milwaukee Bucks", description: "Eastern · Central" },
  { value: "16", label: "Minnesota Timberwolves", description: "Western · Northwest" },
  { value: "3", label: "New Orleans Pelicans", description: "Western · Southwest" },
  { value: "18", label: "New York Knicks", description: "Eastern · Atlantic" },
  { value: "25", label: "Oklahoma City Thunder", description: "Western · Northwest" },
  { value: "19", label: "Orlando Magic", description: "Eastern · Southeast" },
  { value: "20", label: "Philadelphia 76ers", description: "Eastern · Atlantic" },
  { value: "21", label: "Phoenix Suns", description: "Western · Pacific" },
  { value: "22", label: "Portland Trail Blazers", description: "Western · Northwest" },
  { value: "23", label: "Sacramento Kings", description: "Western · Pacific" },
  { value: "24", label: "San Antonio Spurs", description: "Western · Southwest" },
  { value: "28", label: "Toronto Raptors", description: "Eastern · Atlantic" },
  { value: "26", label: "Utah Jazz", description: "Western · Northwest" },
  { value: "27", label: "Washington Wizards", description: "Eastern · Southeast" }
]

// Pre-populated Football Clubs Catalogue (Instant search for major clubs)
var popularFootballClubs = [
  // Portugal - Primeira Liga
  { value: "9772", label: "Benfica", description: "Primeira Liga · Portugal" },
  { value: "9768", label: "Sporting CP", description: "Primeira Liga · Portugal" },
  { value: "9773", label: "FC Porto", description: "Primeira Liga · Portugal" },
  { value: "9771", label: "SC Braga", description: "Primeira Liga · Portugal" },
  { value: "9775", label: "Vitória SC", description: "Primeira Liga · Portugal" },
  { value: "9767", label: "Famalicão", description: "Primeira Liga · Portugal" },
  { value: "9774", label: "Boavista", description: "Primeira Liga · Portugal" },
  { value: "9770", label: "Gil Vicente", description: "Primeira Liga · Portugal" },
  { value: "9769", label: "Estoril Praia", description: "Primeira Liga · Portugal" },
  { value: "9776", label: "Rio Ave", description: "Primeira Liga · Portugal" },
  { value: "9781", label: "Moreirense", description: "Primeira Liga · Portugal" },
  { value: "9780", label: "Arouca", description: "Primeira Liga · Portugal" },
  { value: "9778", label: "Santa Clara", description: "Primeira Liga · Portugal" },
  { value: "9779", label: "Farense", description: "Primeira Liga · Portugal" },
  { value: "9782", label: "Nacional", description: "Primeira Liga · Portugal" },
  { value: "9783", label: "AVS Futebol SAD", description: "Primeira Liga · Portugal" },
  { value: "9784", label: "Casa Pia", description: "Primeira Liga · Portugal" },
  { value: "9785", label: "Estrela da Amadora", description: "Primeira Liga · Portugal" },

  // England - Premier League
  { value: "9825", label: "Arsenal", description: "Premier League · England" },
  { value: "9827", label: "Chelsea", description: "Premier League · England" },
  { value: "8650", label: "Liverpool", description: "Premier League · England" },
  { value: "8456", label: "Manchester City", description: "Premier League · England" },
  { value: "10260", label: "Manchester United", description: "Premier League · England" },
  { value: "8586", label: "Tottenham Hotspur", description: "Premier League · England" },
  { value: "10252", label: "Aston Villa", description: "Premier League · England" },
  { value: "10261", label: "Newcastle United", description: "Premier League · England" },
  { value: "10204", label: "Brighton", description: "Premier League · England" },
  { value: "8654", label: "West Ham United", description: "Premier League · England" },
  { value: "8668", label: "Everton", description: "Premier League · England" },
  { value: "9879", label: "Fulham", description: "Premier League · England" },
  { value: "8659", label: "Wolverhampton Wanderers", description: "Premier League · England" },
  { value: "8191", label: "Brentford", description: "Premier League · England" },
  { value: "9826", label: "Crystal Palace", description: "Premier League · England" },
  { value: "10203", label: "Nottingham Forest", description: "Premier League · England" },
  { value: "8678", label: "Bournemouth", description: "Premier League · England" },
  { value: "8658", label: "Leicester City", description: "Premier League · England" },
  { value: "8466", label: "Southampton", description: "Premier League · England" },
  { value: "9817", label: "Ipswich Town", description: "Premier League · England" },

  // Spain - La Liga
  { value: "8633", label: "Real Madrid", description: "La Liga · Spain" },
  { value: "8634", label: "FC Barcelona", description: "La Liga · Spain" },
  { value: "9906", label: "Atlético Madrid", description: "La Liga · Spain" },
  { value: "8315", label: "Athletic Club", description: "La Liga · Spain" },
  { value: "8560", label: "Real Sociedad", description: "La Liga · Spain" },
  { value: "10205", label: "Villarreal", description: "La Liga · Spain" },
  { value: "8603", label: "Real Betis", description: "La Liga · Spain" },
  { value: "8302", label: "Sevilla", description: "La Liga · Spain" },
  { value: "9910", label: "Girona", description: "La Liga · Spain" },
  { value: "10267", label: "Valencia", description: "La Liga · Spain" },
  { value: "8371", label: "Osasuna", description: "La Liga · Spain" },
  { value: "8581", label: "Celta Vigo", description: "La Liga · Spain" },
  { value: "8638", label: "Rayo Vallecano", description: "La Liga · Spain" },
  { value: "8558", label: "Espanyol", description: "La Liga · Spain" },
  { value: "9864", label: "Mallorca", description: "La Liga · Spain" },
  { value: "8582", label: "Alavés", description: "La Liga · Spain" },
  { value: "8370", label: "Las Palmas", description: "La Liga · Spain" },
  { value: "8696", label: "Getafe", description: "La Liga · Spain" },
  { value: "9907", label: "Leganés", description: "La Liga · Spain" },
  { value: "8388", label: "Real Valladolid", description: "La Liga · Spain" },

  // Italy - Serie A
  { value: "8636", label: "Inter Milan", description: "Serie A · Italy" },
  { value: "8564", label: "AC Milan", description: "Serie A · Italy" },
  { value: "9885", label: "Juventus", description: "Serie A · Italy" },
  { value: "9875", label: "Napoli", description: "Serie A · Italy" },
  { value: "8686", label: "AS Roma", description: "Serie A · Italy" },
  { value: "8543", label: "Lazio", description: "Serie A · Italy" },
  { value: "8524", label: "Atalanta", description: "Serie A · Italy" },
  { value: "8535", label: "Fiorentina", description: "Serie A · Italy" },
  { value: "9857", label: "Bologna", description: "Serie A · Italy" },
  { value: "9804", label: "Torino", description: "Serie A · Italy" },

  // Germany - Bundesliga
  { value: "9823", label: "Bayern München", description: "Bundesliga · Germany" },
  { value: "9789", label: "Borussia Dortmund", description: "Bundesliga · Germany" },
  { value: "8178", label: "Bayer Leverkusen", description: "Bundesliga · Germany" },
  { value: "178475", label: "RB Leipzig", description: "Bundesliga · Germany" },
  { value: "9810", label: "Eintracht Frankfurt", description: "Bundesliga · Germany" },
  { value: "10269", label: "VfB Stuttgart", description: "Bundesliga · Germany" },
  { value: "9788", label: "Borussia Mönchengladbach", description: "Bundesliga · Germany" },

  // France - Ligue 1
  { value: "9847", label: "Paris Saint-Germain", description: "Ligue 1 · France" },
  { value: "8592", label: "Marseille", description: "Ligue 1 · France" },
  { value: "9748", label: "Lyon", description: "Ligue 1 · France" },
  { value: "9829", label: "Monaco", description: "Ligue 1 · France" },
  { value: "8639", label: "Lille", description: "Ligue 1 · France" },
  { value: "9851", label: "Rennes", description: "Ligue 1 · France" },

  // Rest of World
  { value: "8593", label: "Ajax", description: "Eredivisie · Netherlands" },
  { value: "8640", label: "PSV Eindhoven", description: "Eredivisie · Netherlands" },
  { value: "10235", label: "Feyenoord", description: "Eredivisie · Netherlands" },
  { value: "9925", label: "Celtic", description: "Premiership · Scotland" },
  { value: "8548", label: "Rangers", description: "Premiership · Scotland" },
  { value: "5981", label: "Flamengo", description: "Brasileirão · Brazil" },
  { value: "9745", label: "Palmeiras", description: "Brasileirão · Brazil" },
  { value: "10274", label: "Corinthians", description: "Brasileirão · Brazil" },
  { value: "10077", label: "Boca Juniors", description: "Liga Profesional · Argentina" },
  { value: "10076", label: "River Plate", description: "Liga Profesional · Argentina" },
  { value: "8094", label: "Al-Hilal", description: "Saudi Pro League · Saudi Arabia" },
  { value: "7798", label: "Al-Nassr", description: "Saudi Pro League · Saudi Arabia" },
  { value: "1060144", label: "Inter Miami CF", description: "MLS · USA" }
]

// Pre-populated F1 Constructors & Drivers (2026 season, ids match Jolpica/Ergast driverIds)
var f1Drivers = [
  // Constructors
  { value: "red_bull", label: "Red Bull Racing", description: "Constructor · Oracle Red Bull Racing" },
  { value: "ferrari", label: "Ferrari", description: "Constructor · Scuderia Ferrari HP" },
  { value: "mclaren", label: "McLaren", description: "Constructor · McLaren F1 Team" },
  { value: "mercedes", label: "Mercedes", description: "Constructor · Mercedes-AMG PETRONAS F1 Team" },
  { value: "aston_martin", label: "Aston Martin", description: "Constructor · Aston Martin Aramco F1 Team" },
  { value: "alpine", label: "Alpine", description: "Constructor · BWT Alpine F1 Team" },
  { value: "williams", label: "Williams", description: "Constructor · Williams Racing" },
  { value: "audi", label: "Audi", description: "Constructor · Audi F1 Team" },
  { value: "rb", label: "Racing Bulls", description: "Constructor · RB F1 Team" },
  { value: "haas", label: "Haas F1 Team", description: "Constructor · MoneyGram Haas F1 Team" },
  { value: "cadillac", label: "Cadillac", description: "Constructor · Cadillac F1 Team" },

  // Drivers
  { value: "antonelli", label: "Andrea Kimi Antonelli", description: "Mercedes" },
  { value: "hamilton", label: "Lewis Hamilton", description: "Ferrari" },
  { value: "russell", label: "George Russell", description: "Mercedes" },
  { value: "leclerc", label: "Charles Leclerc", description: "Ferrari" },
  { value: "norris", label: "Lando Norris", description: "McLaren" },
  { value: "max_verstappen", label: "Max Verstappen", description: "Red Bull Racing" },
  { value: "piastri", label: "Oscar Piastri", description: "McLaren" },
  { value: "hadjar", label: "Isack Hadjar", description: "Red Bull Racing" },
  { value: "gasly", label: "Pierre Gasly", description: "Alpine" },
  { value: "lawson", label: "Liam Lawson", description: "Racing Bulls" },
  { value: "arvid_lindblad", label: "Arvid Lindblad", description: "Racing Bulls" },
  { value: "colapinto", label: "Franco Colapinto", description: "Alpine" },
  { value: "bearman", label: "Oliver Bearman", description: "Haas F1 Team" },
  { value: "bortoleto", label: "Gabriel Bortoleto", description: "Audi" },
  { value: "sainz", label: "Carlos Sainz", description: "Williams" },
  { value: "albon", label: "Alexander Albon", description: "Williams" },
  { value: "ocon", label: "Esteban Ocon", description: "Haas F1 Team" },
  { value: "hulkenberg", label: "Nico Hülkenberg", description: "Audi" },
  { value: "alonso", label: "Fernando Alonso", description: "Aston Martin" },
  { value: "stroll", label: "Lance Stroll", description: "Aston Martin" },
  { value: "bottas", label: "Valtteri Bottas", description: "Cadillac" },
  { value: "perez", label: "Sergio Pérez", description: "Cadillac" },
  { value: "tsunoda", label: "Yuki Tsunoda", description: "Racing Bulls" }
]

// Pre-populated NFL Teams
var nflTeams = [
  { value: "1", label: "Atlanta Falcons", description: "NFC South" },
  { value: "2", label: "Buffalo Bills", description: "AFC East" },
  { value: "3", label: "Chicago Bears", description: "NFC North" },
  { value: "4", label: "Cincinnati Bengals", description: "AFC North" },
  { value: "5", label: "Cleveland Browns", description: "AFC North" },
  { value: "6", label: "Dallas Cowboys", description: "NFC East" },
  { value: "7", label: "Denver Broncos", description: "AFC West" },
  { value: "8", label: "Detroit Lions", description: "NFC North" },
  { value: "9", label: "Green Bay Packers", description: "NFC North" },
  { value: "10", label: "Tennessee Titans", description: "AFC South" },
  { value: "11", label: "Indianapolis Colts", description: "AFC South" },
  { value: "12", label: "Kansas City Chiefs", description: "AFC West" },
  { value: "13", label: "Las Vegas Raiders", description: "AFC West" },
  { value: "14", label: "Los Angeles Rams", description: "NFC West" },
  { value: "15", label: "Miami Dolphins", description: "AFC East" },
  { value: "16", label: "Minnesota Vikings", description: "NFC North" },
  { value: "17", label: "New England Patriots", description: "AFC East" },
  { value: "18", label: "New Orleans Saints", description: "NFC South" },
  { value: "19", label: "New York Giants", description: "NFC East" },
  { value: "20", label: "New York Jets", description: "AFC East" },
  { value: "21", label: "Philadelphia Eagles", description: "NFC East" },
  { value: "22", label: "Arizona Cardinals", description: "NFC West" },
  { value: "23", label: "Pittsburgh Steelers", description: "AFC North" },
  { value: "24", label: "Los Angeles Chargers", description: "AFC West" },
  { value: "25", label: "San Francisco 49ers", description: "NFC West" },
  { value: "26", label: "Seattle Seahawks", description: "NFC West" },
  { value: "27", label: "Tampa Bay Buccaneers", description: "NFC South" },
  { value: "28", label: "Washington Commanders", description: "NFC East" },
  { value: "29", label: "Carolina Panthers", description: "NFC South" },
  { value: "30", label: "Jacksonville Jaguars", description: "AFC South" },
  { value: "33", label: "Baltimore Ravens", description: "AFC North" },
  { value: "34", label: "Houston Texans", description: "AFC South" }
]

// Pre-populated MLB Teams (ESPN team ids, verified against site.api.espn.com)
var mlbTeams = [
  { value: "1", label: "Baltimore Orioles", description: "AL East" },
  { value: "2", label: "Boston Red Sox", description: "AL East" },
  { value: "10", label: "New York Yankees", description: "AL East" },
  { value: "30", label: "Tampa Bay Rays", description: "AL East" },
  { value: "14", label: "Toronto Blue Jays", description: "AL East" },
  { value: "4", label: "Chicago White Sox", description: "AL Central" },
  { value: "5", label: "Cleveland Guardians", description: "AL Central" },
  { value: "6", label: "Detroit Tigers", description: "AL Central" },
  { value: "7", label: "Kansas City Royals", description: "AL Central" },
  { value: "9", label: "Minnesota Twins", description: "AL Central" },
  { value: "11", label: "Athletics", description: "AL West" },
  { value: "18", label: "Houston Astros", description: "AL West" },
  { value: "3", label: "Los Angeles Angels", description: "AL West" },
  { value: "12", label: "Seattle Mariners", description: "AL West" },
  { value: "13", label: "Texas Rangers", description: "AL West" },
  { value: "15", label: "Atlanta Braves", description: "NL East" },
  { value: "28", label: "Miami Marlins", description: "NL East" },
  { value: "21", label: "New York Mets", description: "NL East" },
  { value: "22", label: "Philadelphia Phillies", description: "NL East" },
  { value: "20", label: "Washington Nationals", description: "NL East" },
  { value: "16", label: "Chicago Cubs", description: "NL Central" },
  { value: "17", label: "Cincinnati Reds", description: "NL Central" },
  { value: "8", label: "Milwaukee Brewers", description: "NL Central" },
  { value: "23", label: "Pittsburgh Pirates", description: "NL Central" },
  { value: "24", label: "St. Louis Cardinals", description: "NL Central" },
  { value: "29", label: "Arizona Diamondbacks", description: "NL West" },
  { value: "27", label: "Colorado Rockies", description: "NL West" },
  { value: "19", label: "Los Angeles Dodgers", description: "NL West" },
  { value: "25", label: "San Diego Padres", description: "NL West" },
  { value: "26", label: "San Francisco Giants", description: "NL West" }
]

// Pre-populated NHL Teams (ESPN team ids, verified against site.api.espn.com)
var nhlTeams = [
  { value: "1", label: "Boston Bruins", description: "Atlantic" },
  { value: "2", label: "Buffalo Sabres", description: "Atlantic" },
  { value: "5", label: "Detroit Red Wings", description: "Atlantic" },
  { value: "26", label: "Florida Panthers", description: "Atlantic" },
  { value: "10", label: "Montreal Canadiens", description: "Atlantic" },
  { value: "14", label: "Ottawa Senators", description: "Atlantic" },
  { value: "20", label: "Tampa Bay Lightning", description: "Atlantic" },
  { value: "21", label: "Toronto Maple Leafs", description: "Atlantic" },
  { value: "7", label: "Carolina Hurricanes", description: "Metropolitan" },
  { value: "29", label: "Columbus Blue Jackets", description: "Metropolitan" },
  { value: "11", label: "New Jersey Devils", description: "Metropolitan" },
  { value: "12", label: "New York Islanders", description: "Metropolitan" },
  { value: "13", label: "New York Rangers", description: "Metropolitan" },
  { value: "15", label: "Philadelphia Flyers", description: "Metropolitan" },
  { value: "16", label: "Pittsburgh Penguins", description: "Metropolitan" },
  { value: "23", label: "Washington Capitals", description: "Metropolitan" },
  { value: "4", label: "Chicago Blackhawks", description: "Central" },
  { value: "17", label: "Colorado Avalanche", description: "Central" },
  { value: "9", label: "Dallas Stars", description: "Central" },
  { value: "30", label: "Minnesota Wild", description: "Central" },
  { value: "27", label: "Nashville Predators", description: "Central" },
  { value: "19", label: "St. Louis Blues", description: "Central" },
  { value: "28", label: "Winnipeg Jets", description: "Central" },
  { value: "129764", label: "Utah Mammoth", description: "Central" },
  { value: "25", label: "Anaheim Ducks", description: "Pacific" },
  { value: "3", label: "Calgary Flames", description: "Pacific" },
  { value: "6", label: "Edmonton Oilers", description: "Pacific" },
  { value: "8", label: "Los Angeles Kings", description: "Pacific" },
  { value: "124292", label: "Seattle Kraken", description: "Pacific" },
  { value: "18", label: "San Jose Sharks", description: "Pacific" },
  { value: "22", label: "Vancouver Canucks", description: "Pacific" },
  { value: "37", label: "Vegas Golden Knights", description: "Pacific" }
]

function defaultState() {
  return {
    version: 2,
    sport: "football",
    football: {
      leagueIds: ["47"],
      teamIds: [],
      teamId: "",
      teamName: "",
      standingsLeagueId: "47",
      tab: "fixtures"
    },
    nba: {
      teamIds: [],
      teamId: "",
      teamName: "",
      standingsGroup: "Eastern Conference",
      tab: "fixtures"
    },
    f1: {
      teamIds: [],
      teamId: "",
      teamName: "",
      standingsGroup: "Drivers",
      tab: "fixtures"
    },
    nfl: {
      teamIds: [],
      teamId: "",
      teamName: "",
      standingsGroup: "American Football Conference",
      tab: "fixtures"
    },
    mlb: {
      teamIds: [],
      teamId: "",
      teamName: "",
      standingsGroup: "American League",
      tab: "fixtures"
    },
    nhl: {
      teamIds: [],
      teamId: "",
      teamName: "",
      standingsGroup: "Eastern Conference",
      tab: "fixtures"
    },
    antiSpoiler: false,
    notifications: true,
    refreshMinutes: 15
  }
}

function formatCountdown(timeIso, nowMs) {
  var ms = Date.parse(timeIso || "")
  if (isNaN(ms)) return ""
  var cur = nowMs || Date.now()
  var diff = ms - cur
  if (diff <= 0) return "Starting soon"
  var mins = Math.floor(diff / 60000)
  var hours = Math.floor(mins / 60)
  var days = Math.floor(hours / 24)
  if (days > 0) return days + "d " + (hours % 24) + "h"
  if (hours > 0) return hours + "h " + (mins % 60) + "m"
  return mins + "m"
}

function arrayFrom(value) {
  if (!value || typeof value.length !== "number" || typeof value === "string") return []
  var result = []
  for (var i = 0; i < value.length; i++) result.push(value[i])
  return result
}

function normalizeLeagueIds(value) {
  var result = []
  var source = arrayFrom(value)
  for (var i = 0; i < source.length && result.length < 12; i++) {
    var raw = String(source[i] || "").trim()
    // Use an array membership check rather than an object lookup: persisted
    // values are user-editable and names such as "__proto__" must not affect
    // the deduplication map through Object.prototype.
    if (!raw || result.indexOf(raw) !== -1) continue
    result.push(raw)
  }
  return result
}

function normalizeTeamIds(value) {
  var result = []
  var source = arrayFrom(value)
  for (var i = 0; i < source.length && result.length < 24; i++) {
    var raw = String(source[i] || "").trim()
    if (!raw || result.indexOf(raw) !== -1) continue
    result.push(raw)
  }
  return result
}

function normalizeTab(value) {
  var tab = String(value || "fixtures").toLowerCase()
  if (tab === "live") return "live"
  if (tab === "standings" || tab === "table") return "standings"
  return "fixtures"
}

// Single source of truth for crest cache file names. Both the panel's
// background downloader and TeamCrest.qml must resolve the exact same key,
// otherwise downloaded logos are never displayed.
// Football and F1 key by provider id; US sports key by ESPN abbreviation
// (fallback: id) which is what the ESPN CDN logos are named after.
function crestCacheKey(sport, teamId, abbr) {
  var sp = String(sport || "football").toLowerCase()
  var id = String(teamId || "").trim().toLowerCase()
  var a = String(abbr || "").trim().toLowerCase()
  var base = (sp === "football" || sp === "f1") ? id : (a || id)
  if (!base) return ""
  return (sp + "-" + base).replace(/[^a-z0-9_-]/g, "")
}

// ESPN scoreboard `dates=YYYYMMDD-YYYYMMDD` range covering recent results
// plus upcoming fixtures (without it the API only returns today's events).
function espnDateRange(daysBack, daysAhead) {
  function fmt(d) {
    var y = d.getFullYear()
    var m = ("0" + (d.getMonth() + 1)).slice(-2)
    var day = ("0" + d.getDate()).slice(-2)
    return y + m + day
  }
  var now = Date.now()
  var back = typeof daysBack === "number" ? daysBack : 1
  var ahead = typeof daysAhead === "number" ? daysAhead : 3
  return fmt(new Date(now - back * 86400000)) + "-" + fmt(new Date(now + ahead * 86400000))
}

function formatKickoff(timeIso) {
  var t = Date.parse(timeIso || "")
  if (isNaN(t)) return ""
  var d = new Date(t)
  return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
}

function parseState(raw) {
  var defaults = defaultState()
  var parsed = null
  try {
    parsed = JSON.parse(String(raw || ""))
  } catch (e) {
    return defaults
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return defaults

  var sport = String(parsed.sport || "football").toLowerCase()
  var validSport = false
  for (var s = 0; s < supportedSports.length; s++) {
    if (supportedSports[s].value === sport) { validSport = true; break }
  }
  if (!validSport) sport = "football"

  // V1 legacy migration
  var fb = parsed.football && typeof parsed.football === "object" ? parsed.football : {}
  var fbLeagues = normalizeLeagueIds(fb.leagueIds || parsed.leagueIds)
  if (fbLeagues.length === 0) fbLeagues = ["47"]
  var fbTeamIds = normalizeTeamIds(fb.teamIds || (fb.teamId || parsed.teamId ? [fb.teamId || parsed.teamId] : []))

  function parseSubSport(key, def) {
    var obj = parsed[key] && typeof parsed[key] === "object" ? parsed[key] : {}
    var tids = normalizeTeamIds(obj.teamIds || (obj.teamId ? [obj.teamId] : []))
    return {
      teamIds: tids,
      teamId: String(obj.teamId || (tids.length > 0 ? tids[0] : "")),
      teamName: String(obj.teamName || ""),
      standingsGroup: String(obj.standingsGroup || def.standingsGroup),
      tab: normalizeTab(obj.tab)
    }
  }

  return {
    version: 2,
    sport: sport,
    football: {
      leagueIds: fbLeagues,
      teamIds: fbTeamIds,
      teamId: String(fb.teamId || (fbTeamIds.length > 0 ? fbTeamIds[0] : "") || parsed.teamId || ""),
      teamName: String(fb.teamName || parsed.teamName || ""),
      standingsLeagueId: String(fb.standingsLeagueId || parsed.standingsLeagueId || fbLeagues[0]),
      tab: normalizeTab(fb.tab)
    },
    nba: parseSubSport("nba", defaults.nba),
    f1: parseSubSport("f1", defaults.f1),
    nfl: parseSubSport("nfl", defaults.nfl),
    mlb: parseSubSport("mlb", defaults.mlb),
    nhl: parseSubSport("nhl", defaults.nhl),
    antiSpoiler: parsed.antiSpoiler === true,
    notifications: parsed.notifications !== false,
    refreshMinutes: Math.max(5, Math.min(60, parseInt(parsed.refreshMinutes, 10) || 15))
  }
}

function statePayload(sport, fbLeagues, fbTeamIds, fbTeamName, refreshMinutes, fbStandingsId, sportSettings, antiSpoiler, notifications) {
  var state = defaultState()
  state.sport = String(sport || "football")
  state.antiSpoiler = antiSpoiler === true
  state.notifications = notifications !== false
  state.refreshMinutes = Math.max(5, Math.min(60, parseInt(refreshMinutes, 10) || 15))
  var leagues = normalizeLeagueIds(fbLeagues)
  if (leagues.length === 0) leagues = ["47"]
  var tids = normalizeTeamIds(fbTeamIds)
  state.football = {
    leagueIds: leagues,
    teamIds: tids,
    teamId: String(tids.length > 0 ? tids[0] : ""),
    teamName: String(fbTeamName || ""),
    standingsLeagueId: String(fbStandingsId || leagues[0]),
    tab: "fixtures"
  }
  if (sportSettings && typeof sportSettings === "object") {
    if (sportSettings.nba) state.nba = sportSettings.nba
    if (sportSettings.f1) state.f1 = sportSettings.f1
    if (sportSettings.nfl) state.nfl = sportSettings.nfl
    if (sportSettings.mlb) state.mlb = sportSettings.mlb
    if (sportSettings.nhl) state.nhl = sportSettings.nhl
  }
  return state
}

// ============================================================================
// ESPN SCOREBOARD & STANDINGS PARSERS (NBA, NFL, MLB, NHL)
// ============================================================================

function isEspnScoreboardPayload(value) {
  var json = value
  if (typeof value === "string") {
    try { json = JSON.parse(value) } catch (e) { return false }
  }
  return !!(json && typeof json === "object" && !Array.isArray(json)
    && json.code === undefined && json.error === undefined && json.errors === undefined
    && Array.isArray(json.events))
}

function isEspnStandingsPayload(value) {
  var json = value
  if (typeof value === "string") {
    try { json = JSON.parse(value) } catch (e) { return false }
  }
  return !!(json && typeof json === "object" && !Array.isArray(json)
    && json.code === undefined && json.error === undefined && json.errors === undefined
    && Array.isArray(json.children))
}

function isF1CalendarPayload(value) {
  var json = value
  if (typeof value === "string") {
    try { json = JSON.parse(value) } catch (e) { return false }
  }
  return !!(json && json.error === undefined && json.errors === undefined
    && json.MRData && json.MRData.RaceTable && Array.isArray(json.MRData.RaceTable.Races))
}

function parseEspnScoreboard(raw, sportName, defaultLeagueName) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var events = arrayFrom(json.events)
  var matches = []

  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    if (!e) continue
    var comp = (e.competitions && e.competitions[0]) || {}
    var competitors = arrayFrom(comp.competitors)
    var home = { id: "", name: "Home", shortName: "Home", record: "" }
    var away = { id: "", name: "Away", shortName: "Away", record: "" }
    var homeScore = 0
    var awayScore = 0

    for (var c = 0; c < competitors.length; c++) {
      var item = competitors[c]
      if (!item) continue
      var team = item.team || {}
      var rec = (item.records && item.records[0] && item.records[0].summary) || ""
      var tObj = {
        id: String(team.id || ""),
        name: String(team.displayName || team.name || "Team"),
        shortName: String(team.shortDisplayName || team.name || team.abbreviation || "Team"),
        abbr: String(team.abbreviation || ""),
        record: rec,
        logo: String(team.logo || (team.logos && team.logos[0] && team.logos[0].href) || "")
      }
      if (item.homeAway === "home") {
        home = tObj
        homeScore = parseInt(item.score, 10) || 0
      } else {
        away = tObj
        awayScore = parseInt(item.score, 10) || 0
      }
    }

    var st = e.status || {}
    var stType = st.type || {}
    var stateStr = String(stType.state || "pre").toLowerCase()
    var status = "upcoming"
    if (stateStr === "in") status = "live"
    else if (stateStr === "post") status = "finished"
    else if (stType.name && String(stType.name).toUpperCase().indexOf("CANCEL") !== -1) status = "cancelled"

    var scoreText = ""
    if (status !== "upcoming") {
      scoreText = homeScore + "–" + awayScore
    }

    var liveTime = ""
    if (status === "live") {
      liveTime = String(stType.shortDetail || st.displayClock || "LIVE")
    }

    var homeLines = []
    var awayLines = []
    for (var cl = 0; cl < competitors.length; cl++) {
      if (competitors[cl].homeAway === "home" && competitors[cl].linescores) {
        homeLines = arrayFrom(competitors[cl].linescores).map(function(l) { return l.value })
      } else if (competitors[cl].linescores) {
        awayLines = arrayFrom(competitors[cl].linescores).map(function(l) { return l.value })
      }
    }

    var leagueTitle = (json.leagues && json.leagues[0] && json.leagues[0].name) || defaultLeagueName

    matches.push({
      id: String(e.id || ""),
      sport: sportName,
      leagueId: sportName,
      leagueName: leagueTitle,
      venue: String((comp.venue && comp.venue.fullName) || ""),
      round: (comp.season && comp.season.slug) || "",
      home: home,
      away: away,
      status: status,
      homeScore: homeScore,
      awayScore: awayScore,
      scoreText: scoreText,
      linescores: { home: homeLines, away: awayLines },
      statusReason: String(stType.shortDetail || ""),
      liveTime: liveTime,
      time: String(e.date || ""),
      pageUrl: (comp.headlines && comp.headlines[0] && comp.headlines[0].video && comp.headlines[0].video.links && comp.headlines[0].video.links.web && comp.headlines[0].video.links.web.href) || ("https://www.espn.com/" + sportName)
    })
  }
  return matches
}

function parseEspnStandings(raw, sportName) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return {} }
  if (!json || typeof json !== "object") return {}
  var groups = arrayFrom(json.children)
  var result = {}

  for (var g = 0; g < groups.length; g++) {
    var group = groups[g]
    if (!group) continue
    var groupName = String(group.name || ("Group " + (g + 1)))
    var entries = (group.standings && group.standings.entries) ? arrayFrom(group.standings.entries) : []
    var rows = []

    for (var e = 0; e < entries.length; e++) {
      var entry = entries[e]
      if (!entry) continue
      var team = entry.team || {}
      var stats = arrayFrom(entry.stats)
      var statMap = {}
      for (var s = 0; s < stats.length; s++) {
        if (stats[s] && stats[s].name) statMap[stats[s].name] = stats[s]
      }

      var wins = parseInt((statMap.wins && statMap.wins.displayValue) || (statMap.wins && statMap.wins.value), 10) || 0
      var losses = parseInt((statMap.losses && statMap.losses.displayValue) || (statMap.losses && statMap.losses.value), 10) || 0
      var ties = parseInt((statMap.ties && statMap.ties.displayValue) || (statMap.otLosses && statMap.otLosses.displayValue) || (statMap.ties && statMap.ties.value), 10) || 0
      var played = wins + losses + ties
      var pts = (statMap.pts && statMap.pts.displayValue) || (statMap.points && statMap.points.displayValue) || (statMap.winPercent && statMap.winPercent.displayValue) || (wins + "W")
      var diff = (statMap.differential && statMap.differential.displayValue) || (statMap.pointDifferential && statMap.pointDifferential.displayValue) || (statMap.runDifferential && statMap.runDifferential.displayValue) || (statMap.gamesBehind && statMap.gamesBehind.displayValue) || "-"
      var seed = parseInt((statMap.playoffSeed && statMap.playoffSeed.displayValue), 10) || (e + 1)
      var logoUrl = (team.logos && team.logos[0] && team.logos[0].href) || (team.logo) || ""

      var zone = ""
      if (sportName === "nfl") {
        if (seed <= 7) zone = "europe"
      } else if (sportName === "nhl") {
        if (seed <= 8) zone = "europe"
      } else if (sportName === "mlb") {
        if (seed <= 6) zone = "europe"
      } else {
        // NBA: top 6 playoff seeds, 7-10 play-in
        if (seed <= 6) zone = "europe"
        else if (seed <= 10) zone = "playin"
      }

      rows.push({
        pos: String(seed),
        id: String(team.id || ""),
        name: String(team.displayName || team.name || "Team"),
        shortName: String(team.shortDisplayName || team.name || team.abbreviation || "Team"),
        abbr: String(team.abbreviation || ""),
        logo: String(logoUrl),
        played: played,
        wins: wins,
        draws: ties,
        losses: losses,
        gd: String(diff),
        pts: String(pts),
        zone: zone
      })
    }
    rows.sort(function(a, b) { return (parseInt(a.pos, 10) || 99) - (parseInt(b.pos, 10) || 99) })
    result[groupName] = rows
  }
  return result
}

function f1CountryFlag(countryName, raceName) {
  var c = String(countryName || "").toLowerCase()
  var r = String(raceName || "").toLowerCase()

  if (c.indexOf("australia") !== -1 || r.indexOf("australian") !== -1) return "🇦🇺"
  if (c.indexOf("china") !== -1 || r.indexOf("chinese") !== -1 || r.indexOf("shanghai") !== -1) return "🇨🇳"
  if (c.indexOf("japan") !== -1 || r.indexOf("japanese") !== -1 || r.indexOf("suzuka") !== -1) return "🇯🇵"
  if (c.indexOf("bahrain") !== -1 || r.indexOf("sakhir") !== -1) return "🇧🇭"
  if (c.indexOf("saudi") !== -1 || r.indexOf("jeddah") !== -1) return "🇸🇦"
  if (r.indexOf("miami") !== -1 || r.indexOf("las vegas") !== -1 || r.indexOf("united states") !== -1 || c.indexOf("united states") !== -1 || c.indexOf("usa") !== -1 || r.indexOf("austin") !== -1) return "🇺🇸"
  if (c.indexOf("italy") !== -1 || r.indexOf("emilia") !== -1 || r.indexOf("imola") !== -1 || r.indexOf("monza") !== -1 || r.indexOf("italian") !== -1) return "🇮🇹"
  if (c.indexOf("monaco") !== -1 || r.indexOf("monte carlo") !== -1) return "🇲🇨"
  if (c.indexOf("spain") !== -1 || r.indexOf("spanish") !== -1 || r.indexOf("catalunya") !== -1 || r.indexOf("madrid") !== -1) return "🇪🇸"
  if (c.indexOf("canada") !== -1 || r.indexOf("canadian") !== -1 || r.indexOf("montreal") !== -1) return "🇨🇦"
  if (c.indexOf("austria") !== -1 || r.indexOf("austrian") !== -1 || r.indexOf("spielberg") !== -1 || r.indexOf("red bull ring") !== -1) return "🇦🇹"
  if (c.indexOf("uk") !== -1 || c.indexOf("great britain") !== -1 || r.indexOf("british") !== -1 || r.indexOf("silverstone") !== -1) return "🇬🇧"
  if (c.indexOf("belgium") !== -1 || r.indexOf("belgian") !== -1 || r.indexOf("spa") !== -1) return "🇧🇪"
  if (c.indexOf("hungary") !== -1 || r.indexOf("hungarian") !== -1 || r.indexOf("hungaroring") !== -1) return "🇭🇺"
  if (c.indexOf("netherlands") !== -1 || r.indexOf("dutch") !== -1 || r.indexOf("zandvoort") !== -1) return "🇳🇱"
  if (c.indexOf("azerbaijan") !== -1 || r.indexOf("baku") !== -1) return "🇦🇿"
  if (c.indexOf("singapore") !== -1 || r.indexOf("marina bay") !== -1) return "🇸🇬"
  if (c.indexOf("mexico") !== -1 || r.indexOf("rodriguez") !== -1) return "🇲🇽"
  if (c.indexOf("brazil") !== -1 || r.indexOf("são paulo") !== -1 || r.indexOf("interlagos") !== -1) return "🇧🇷"
  if (c.indexOf("qatar") !== -1 || r.indexOf("lusail") !== -1) return "🇶🇦"
  if (c.indexOf("abu dhabi") !== -1 || c.indexOf("uae") !== -1 || c.indexOf("emirates") !== -1 || r.indexOf("yas marina") !== -1) return "🇦🇪"
  return "🏁"
}

function f1DriverFlag(driverIdOrNat) {
  var d = String(driverIdOrNat || "").toLowerCase()
  if (d.indexOf("british") !== -1 || d.indexOf("hamilton") !== -1 || d.indexOf("norris") !== -1 || d.indexOf("russell") !== -1 || d.indexOf("bearman") !== -1 || d.indexOf("lindblad") !== -1) return "🇬🇧"
  if (d.indexOf("verstappen") !== -1 || d.indexOf("dutch") !== -1) return "🇳🇱"
  if (d.indexOf("leclerc") !== -1 || d.indexOf("monegasque") !== -1) return "🇲🇨"
  if (d.indexOf("piastri") !== -1 || d.indexOf("australian") !== -1) return "🇦🇺"
  if (d.indexOf("alonso") !== -1 || d.indexOf("sainz") !== -1 || d.indexOf("spanish") !== -1) return "🇪🇸"
  if (d.indexOf("antonelli") !== -1 || d.indexOf("italian") !== -1) return "🇮🇹"
  if (d.indexOf("gasly") !== -1 || d.indexOf("ocon") !== -1 || d.indexOf("hadjar") !== -1 || d.indexOf("french") !== -1) return "🇫🇷"
  if (d.indexOf("hulkenberg") !== -1 || d.indexOf("german") !== -1) return "🇩🇪"
  if (d.indexOf("tsunoda") !== -1 || d.indexOf("japanese") !== -1) return "🇯🇵"
  if (d.indexOf("albon") !== -1 || d.indexOf("thai") !== -1) return "🇹🇭"
  if (d.indexOf("stroll") !== -1 || d.indexOf("canadian") !== -1) return "🇨🇦"
  if (d.indexOf("bortoleto") !== -1 || d.indexOf("brazilian") !== -1) return "🇧🇷"
  if (d.indexOf("lawson") !== -1 || d.indexOf("zealand") !== -1) return "🇳🇿"
  if (d.indexOf("colapinto") !== -1 || d.indexOf("argentin") !== -1) return "🇦🇷"
  if (d.indexOf("bottas") !== -1 || d.indexOf("finnish") !== -1) return "🇫🇮"
  if (d.indexOf("perez") !== -1 || d.indexOf("pérez") !== -1 || d.indexOf("mexican") !== -1) return "🇲🇽"
  return "🏎"
}

// ============================================================================
// FORMULA 1 CALENDAR & STANDINGS PARSER (JOLPICA / ERGAST)
// ============================================================================

function parseF1Calendar(raw, nowMs) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var races = (json.MRData && json.MRData.RaceTable && json.MRData.RaceTable.Races) ? arrayFrom(json.MRData.RaceTable.Races) : []
  var now = Number(nowMs) || Date.now()
  var matches = []

  for (var i = 0; i < races.length; i++) {
    var r = races[i]
    if (!r) continue
    var raceIso = r.date + "T" + (r.time || "14:00:00Z")
    var raceMs = Date.parse(raceIso)
    var status = "upcoming"
    if (!isNaN(raceMs)) {
      if (now > raceMs + 3 * 3600 * 1000) status = "finished"
      else if (now >= raceMs) status = "live"
    }

    var raceName = String(r.raceName || "Grand Prix")
    var circuitName = (r.Circuit && r.Circuit.circuitName) || "Circuit"
    var locality = (r.Circuit && r.Circuit.Location && r.Circuit.Location.locality) || ""
    var country = (r.Circuit && r.Circuit.Location && r.Circuit.Location.country) || ""
    var flag = f1CountryFlag(country, raceName)

    var sessions = []
    if (r.FirstPractice) {
      sessions.push({
        name: "Practice 1",
        shortName: "FP1",
        time: r.FirstPractice.date + "T" + (r.FirstPractice.time || "10:00:00Z")
      })
    }
    if (r.SprintQualifying || r.SprintShootout) {
      var sq = r.SprintQualifying || r.SprintShootout
      sessions.push({
        name: "Sprint Qualifying",
        shortName: "SQ",
        time: sq.date + "T" + (sq.time || "14:00:00Z")
      })
    } else if (r.SecondPractice) {
      sessions.push({
        name: "Practice 2",
        shortName: "FP2",
        time: r.SecondPractice.date + "T" + (r.SecondPractice.time || "14:00:00Z")
      })
    }
    if (r.Sprint) {
      sessions.push({
        name: "Sprint Race",
        shortName: "Sprint",
        time: r.Sprint.date + "T" + (r.Sprint.time || "10:00:00Z")
      })
    } else if (r.ThirdPractice) {
      sessions.push({
        name: "Practice 3",
        shortName: "FP3",
        time: r.ThirdPractice.date + "T" + (r.ThirdPractice.time || "10:00:00Z")
      })
    }
    if (r.Qualifying) {
      sessions.push({
        name: "Qualifying",
        shortName: "Quali",
        time: r.Qualifying.date + "T" + (r.Qualifying.time || "14:00:00Z")
      })
    }
    sessions.push({
      name: "Grand Prix (Race)",
      shortName: "Race",
      time: raceIso
    })

    matches.push({
      id: "f1-2026-" + r.round,
      sport: "f1",
      leagueId: "f1",
      leagueName: "Formula 1",
      round: "Round " + r.round,
      raceName: raceName,
      circuitName: circuitName,
      locality: locality,
      country: country,
      countryFlag: flag,
      sessions: sessions,
      home: {
        id: "f1-gp-" + r.round,
        name: raceName,
        shortName: raceName.replace(" Grand Prix", " GP"),
        record: locality ? (locality + ", " + country) : country,
        logo: ""
      },
      away: {
        id: "f1-circuit-" + r.round,
        name: circuitName,
        shortName: country || circuitName,
        record: "",
        logo: ""
      },
      status: status,
      homeScore: 0,
      awayScore: 0,
      scoreText: status === "finished" ? "Official" : (status === "live" ? "RACE DAY" : "Round " + r.round),
      statusReason: status === "finished" ? "Official" : (status === "live" ? "LIVE" : "Scheduled"),
      liveTime: status === "live" ? "RACE" : "",
      time: raceIso,
      pageUrl: r.url || "https://www.formula1.com"
    })
  }
  return matches
}

function parseF1DriverStandings(raw) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var list = (json.MRData && json.MRData.StandingsTable && json.MRData.StandingsTable.StandingsLists && json.MRData.StandingsTable.StandingsLists[0] && json.MRData.StandingsTable.StandingsLists[0].DriverStandings) ? arrayFrom(json.MRData.StandingsTable.StandingsLists[0].DriverStandings) : []
  var rows = []

  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    if (!d) continue
    var driver = d.Driver || {}
    var constructor = (d.Constructors && d.Constructors[0]) || {}
    var pos = parseInt(d.position, 10) || (i + 1)
    var conId = String(constructor.constructorId || constructor.name || "").toLowerCase()
    var driverFlag = f1DriverFlag(driver.driverId || driver.nationality)

    rows.push({
      pos: String(pos),
      id: String(driver.driverId || ""),
      name: (driver.givenName || "") + " " + (driver.familyName || ""),
      shortName: String(driver.code || driver.familyName || "Driver"),
      abbr: String(driver.code || driver.familyName || "DRV").slice(0, 3).toUpperCase(),
      flag: driverFlag,
      teamId: conId,
      teamName: String(constructor.name || ""),
      played: parseInt(d.wins, 10) || 0,
      wins: parseInt(d.wins, 10) || 0,
      draws: 0,
      losses: 0,
      gd: String(constructor.name || ""),
      pts: String(d.points || "0") + " PTS",
      zone: pos === 1 ? "europe" : (pos <= 3 ? "playin" : "")
    })
  }
  return rows
}

function parseF1ConstructorStandings(raw) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var list = (json.MRData && json.MRData.StandingsTable && json.MRData.StandingsTable.StandingsLists && json.MRData.StandingsTable.StandingsLists[0] && json.MRData.StandingsTable.StandingsLists[0].ConstructorStandings) ? arrayFrom(json.MRData.StandingsTable.StandingsLists[0].ConstructorStandings) : []
  var rows = []

  for (var i = 0; i < list.length; i++) {
    var c = list[i]
    if (!c) continue
    var constructor = c.Constructor || {}
    var pos = parseInt(c.position, 10) || (i + 1)
    var conId = String(constructor.constructorId || constructor.name || "").toLowerCase()

    rows.push({
      pos: String(pos),
      id: conId,
      name: String(constructor.name || "Constructor"),
      shortName: String(constructor.name || "Constructor"),
      abbr: String(constructor.name || "CON").slice(0, 2).toUpperCase(),
      teamId: conId,
      teamName: String(constructor.name || ""),
      played: parseInt(c.wins, 10) || 0,
      wins: parseInt(c.wins, 10) || 0,
      draws: 0,
      losses: 0,
      gd: String(constructor.nationality || ""),
      pts: String(c.points || "0") + " PTS",
      zone: pos === 1 ? "europe" : (pos <= 3 ? "playin" : "")
    })
  }
  return rows
}

// ============================================================================
// FOTMOB FOOTBALL PARSERS
// ============================================================================

function extractPageProps(html) {
  if (!html || typeof html !== "string") return {}
  var marker = '<script id="__NEXT_DATA__" type="application/json">'
  var start = html.indexOf(marker)
  if (start === -1) return {}
  start += marker.length
  var end = html.indexOf("</script>", start)
  if (end === -1) return {}
  try {
    var parsed = JSON.parse(html.substring(start, end))
    return (parsed && parsed.props && parsed.props.pageProps) || {}
  } catch (e) {
    return {}
  }
}

function parseScore(status) {
  if (!status) return { home: 0, away: 0, text: "" }
  if (typeof status.scoreStr === "string" && status.scoreStr.indexOf("-") !== -1) {
    var parts = status.scoreStr.split("-")
    var home = parseInt(parts[0].trim(), 10) || 0
    var away = parseInt(parts[1].trim(), 10) || 0
    return { home: home, away: away, text: home + "–" + away }
  }
  var aggregate = status.aggregateStr || ""
  if (aggregate) return { home: 0, away: 0, text: aggregate }
  return { home: 0, away: 0, text: "" }
}

function cleanPageUrl(raw) {
  var url = String(raw || "").trim()
  if (!url) return ""
  if (/^https:\/\//i.test(url)) return url
  // Keep non-HTTPS absolute URLs out of the parsed value. They are not
  // useful for provider detail pages and must never reach curl/xdg-open.
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(url)) return ""
  if (url.charAt(0) === "/" && url.charAt(1) !== "/") return url
  return "/" + url.replace(/^\/+/, "")
}

function trustedHost(host, allowedHosts) {
  var value = String(host || "").toLowerCase().replace(/\.$/, "")
  var hosts = arrayFrom(allowedHosts)
  for (var i = 0; i < hosts.length; i++) {
    var allowed = String(hosts[i] || "").toLowerCase().replace(/\.$/, "")
    if (value === allowed || value.slice(-(allowed.length + 1)) === "." + allowed) return true
  }
  return false
}

function trustedHttpsUrl(raw, allowedHosts) {
  var url = String(raw || "").trim()
  // Reject credentials, ports, non-HTTPS schemes, control characters, and
  // malformed hostnames before handing a provider URL to a local process.
  if (!/^https:\/\/[^\s/?#]+(?:[/?#]|$)/i.test(url) || /[\u0000-\u001f\u007f]/.test(url)) return ""
  var match = url.match(/^https:\/\/([^\s/@?#]+)(?:[/?#].*)?$/i)
  if (!match || !trustedHost(match[1], allowedHosts)) return ""
  return url
}

function isTrustedCrestUrl(raw, sport) {
  var s = String(sport || "football").toLowerCase()
  var hosts = s === "football" ? ["fotmob.com"] : ["espncdn.com", "espn.com"]
  return trustedHttpsUrl(raw, hosts) !== ""
}

function matchExternalUrl(match) {
  if (!match) return ""
  var sport = String(match.sport || "football").toLowerCase()
  var raw = String(match.pageUrl || "").trim()
  var base = "https://www.espn.com/" + sport
  var hosts = ["espn.com"]
  if (sport === "football") {
    base = "https://www.fotmob.com"
    hosts = ["fotmob.com"]
  } else if (sport === "f1") {
    base = "https://www.formula1.com"
    hosts = ["formula1.com", "wikipedia.org"]
  }
  // Relative paths are common in FotMob and ESPN payloads; resolve them
  // against the sport's known base so a click opens the actual article, not
  // a useless bare-host root. F1 has no fixed base — only fully-qualified
  // Wikipedia or formula1.com links reach this branch.
  if (raw.charAt(0) === "/" && raw.charAt(1) !== "/") {
    if (sport === "football" || sport === "nba" || sport === "nfl" || sport === "mlb" || sport === "nhl") {
      return base + raw
    }
  }
  return trustedHttpsUrl(raw, hosts) || base
}

function matchDetailUrl(match) {
  if (!match || String(match.sport || "football").toLowerCase() !== "football") return ""
  var raw = String(match.pageUrl || "").trim()
  if (raw.charAt(0) === "/" && raw.charAt(1) !== "/") return "https://www.fotmob.com" + raw
  return trustedHttpsUrl(raw, ["fotmob.com"])
}

function parseMatch(raw, league) {
  var score = parseScore(raw && raw.status)
  var status = raw && raw.status ? raw.status : {}
  var bool = function(v) { return v === true || v === "true" }

  var reasonShort = String(status.reason && status.reason.short || "").toUpperCase()
  var reasonLong = String(status.reason && status.reason.long || "").toUpperCase()

  var isFinishedReason = reasonShort === "FT" || reasonShort === "AET" || reasonShort === "PEN" || reasonLong.indexOf("FULL") !== -1 || reasonLong.indexOf("AFTER EXTRA") !== -1 || reasonLong.indexOf("PENALTIES") !== -1 || bool(status.finished)
  var isCancelledReason = reasonShort === "CANC" || reasonShort === "POSTP" || reasonShort === "ABD" || reasonLong.indexOf("CANCEL") !== -1 || reasonLong.indexOf("POSTP") !== -1 || reasonLong.indexOf("ABANDON") !== -1 || bool(status.cancelled)

  var state = "upcoming"
  if (isCancelledReason) {
    state = "cancelled"
  } else if (isFinishedReason) {
    state = "finished"
  } else if (bool(status.ongoing) || (bool(status.started) && !bool(status.finished) && !isFinishedReason)) {
    state = "live"
  }

  var home = raw && raw.home ? raw.home : {}
  var away = raw && raw.away ? raw.away : {}
  var homeId = String(home.id || "")
  var awayId = String(away.id || "")
  var homeLogo = homeId !== "" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + homeId + ".png") : ""
  var awayLogo = awayId !== "" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + awayId + ".png") : ""

  return {
    id: String(raw && raw.id || ""),
    sport: "football",
    leagueId: String(league.id || ""),
    leagueName: String(league.name || ""),
    round: String(raw && raw.round || ""),
    home: { id: homeId, name: String(home.name || ""), shortName: String(home.shortName || home.name || ""), logo: homeLogo },
    away: { id: awayId, name: String(away.name || ""), shortName: String(away.shortName || away.name || ""), logo: awayLogo },
    status: state,
    homeScore: score.home,
    awayScore: score.away,
    scoreText: score.text,
    statusReason: String(status.reason && status.reason.short || ""),
    liveTime: status.liveTime && status.liveTime.short ? String(status.liveTime.short) : (state === "live" ? "LIVE" : ""),
    time: String(status.utcTime || ""),
    pageUrl: cleanPageUrl(raw && raw.pageUrl)
  }
}

function parseDetails(html) {
  var props = extractPageProps(html)
  var content = props.content || {}
  var facts = content.matchFacts || {}
  var box = facts.infoBox || {}
  var header = props.header || {}
  var status = header.status || {}

  var out = {}
  var stadium = box.Stadium || null
  if (stadium && stadium.name) {
    out.stadium = String(stadium.name)
    if (stadium.city) out.city = String(stadium.city)
  }
  var referee = box.Referee || null
  if (referee && referee.text) out.referee = String(referee.text)
  if (typeof box.Attendance === "number" && box.Attendance > 0) out.attendance = box.Attendance
  var gen = props.general || {}
  if (gen.leagueRoundName) out.round = String(gen.leagueRoundName)
  if (status.halftimeScore) out.halftimeScore = String(status.halftimeScore)
  if (status.reason && status.reason.long) out.statusLong = String(status.reason.long)
  if (status.reason && status.reason.short) out.reason = String(status.reason.short)
  if (status.finished === true) out.finished = true

  return Object.keys(out).length > 0 ? out : null
}

function parseStandings(props) {
  var table = props && props.table ? props.table : []
  var tableBlock = null
  if (Array.isArray(table)) {
    tableBlock = table.length > 0 ? table[0] : null
  } else if (table && typeof table === "object") {
    tableBlock = table
  }
  var tableData = tableBlock && tableBlock.data ? tableBlock.data : {}
  var tableValues = tableData.table || {}
  var rows = arrayFrom(tableValues.all)
  var legend = arrayFrom(tableData.legend)
  var result = []
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    var tId = String(r.id || "")
    result.push({
      pos: String(r.idx || (i + 1)),
      id: tId,
      name: String(r.name || ""),
      shortName: String(r.shortName || r.name || ""),
      logo: tId !== "" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + tId + ".png") : "",
      played: parseInt(r.played, 10) || 0,
      wins: parseInt(r.wins, 10) || 0,
      draws: parseInt(r.draws, 10) || 0,
      losses: parseInt(r.losses, 10) || 0,
      gd: parseInt(r.goalConDiff, 10) || 0,
      pts: parseInt(r.pts, 10) || 0,
      zone: zoneFromLegend(legend, i)
    })
  }
  return result
}

function zoneFromLegend(legend, idx) {
  var source = arrayFrom(legend)
  for (var i = 0; i < source.length; i++) {
    var entry = source[i]
    if (!entry || !entry.indices) continue
    var indices = arrayFrom(entry.indices)
    for (var j = 0; j < indices.length; j++) {
      if (Number(indices[j]) === idx) {
        var key = String(entry.title || "").toLowerCase()
        if (key.indexOf("champions league") !== -1 || key.indexOf("promotion") !== -1 || key.indexOf("qualification") !== -1 || key.indexOf("playoff") !== -1)
          return "europe"
        if (key.indexOf("relegation") !== -1 || key.indexOf("bottom") !== -1)
          return "relegation"
      }
    }
  }
  return ""
}

function parseLeaguePage(html, requestedId) {
  var props = extractPageProps(html)
  // A page with no provider payload at all (bot-wall, consent page, rate-limit
  // HTML) is a fetch failure, not an empty league — returning null lets the
  // caller retry instead of silently rendering nothing
  if (!props.details && !props.fixtures && !props.table) return null
  var details = props.details || {}
  var fixtures = props.fixtures || {}
  var league = {
    id: String(details.id || requestedId || ""),
    name: String(details.name || "League " + (requestedId || "")),
    country: String(details.country || "")
  }
  var matches = []
  var source = fixtures.allMatches || []
  for (var i = 0; i < source.length; i++) {
    var match = parseMatch(source[i], league)
    if (match.id && match.home.name && match.away.name) matches.push(match)
  }
  return { league: league, matches: matches, standings: parseStandings(props) }
}

function findTeamPageData(html, requestedTeamId) {
  var props = extractPageProps(html)
  var fallback = props.fallback || {}
  var teamKey = "team-" + String(requestedTeamId || "")
  // The fallback map can contain several team payloads. Never substitute the
  // first available team when the requested key is absent: that would show a
  // different club's schedule after a provider schema change.
  return fallback[teamKey] || null
}

function isTeamPagePayload(html, requestedTeamId) {
  var teamData = findTeamPageData(html, requestedTeamId)
  return !!(teamData && teamData.fixtures && teamData.fixtures.allFixtures)
}

function parseTeamPage(html, requestedTeamId) {
  var teamData = findTeamPageData(html, requestedTeamId)
  if (!teamData || !teamData.fixtures || !teamData.fixtures.allFixtures) return []
  var rawFixtures = arrayFrom(teamData.fixtures.allFixtures.fixtures)
  var matches = []
  for (var i = 0; i < rawFixtures.length; i++) {
    var f = rawFixtures[i]
    var t = f.tournament || {}
    var league = {
      id: String(t.leagueId || ""),
      name: String(t.name || "Competition"),
      country: ""
    }
    var match = parseMatch(f, league)
    if (match.id && match.home.name && match.away.name) matches.push(match)
  }
  return matches
}

function mergePages(pages) {
  var matches = []
  var seen = {}
  var source = arrayFrom(pages)
  for (var i = 0; i < source.length; i++) {
    var pageMatches = source[i] && source[i].matches ? source[i].matches : []
    for (var j = 0; j < pageMatches.length; j++) {
      var match = pageMatches[j]
      if (!match || !match.id || seen[match.id]) continue
      seen[match.id] = true
      matches.push(match)
    }
  }
  return matches
}

// Replace existing matches by id while preserving the current ordering. Team
// pages and scoped live refreshes contain newer score/status data than the
// previous full round; append only genuinely new fixtures.
function mergeMatchUpdates(existing, updates) {
  var result = arrayFrom(existing).slice()
  var indexes = {}
  for (var i = 0; i < result.length; i++) {
    if (result[i] && result[i].id) indexes[String(result[i].id)] = i
  }
  var source = arrayFrom(updates)
  for (var j = 0; j < source.length; j++) {
    var match = source[j]
    if (!match || !match.id) continue
    var key = String(match.id)
    if (indexes[key] === undefined) {
      indexes[key] = result.length
      result.push(match)
    } else {
      result[indexes[key]] = match
    }
  }
  return result
}

// Merge page snapshots by their resolved league id. Unlike mergePages this
// intentionally replaces a stale page instead of letting the first copy win.
function mergeLeaguePages(existing, updates) {
  var result = arrayFrom(existing).slice()
  var indexes = {}
  for (var i = 0; i < result.length; i++) {
    var oldPage = result[i]
    if (oldPage && oldPage.league && oldPage.league.id)
      indexes[String(oldPage.league.id)] = i
  }
  var source = arrayFrom(updates)
  for (var j = 0; j < source.length; j++) {
    var page = source[j]
    if (!page || !page.league || !page.league.id) continue
    var key = String(page.league.id)
    if (indexes[key] === undefined) {
      indexes[key] = result.length
      result.push(page)
    } else {
      result[indexes[key]] = page
    }
  }
  return result
}

// ============================================================================
// MOCK MODE (OMASPORTS_MOCK=1)
// ============================================================================
// A deterministic, always-fresh simulation of every sport. Anchored to the
// first call in a panel session so matches evolve realistically while you
// watch: the live game progresses through kickoff → 1st half → HT → 2nd half
// → FT, the upcoming game crosses its kickoff and a scripted goal is scored
// mid-session (to exercise goal notifications).
var mockAnchor = 0

function mockMinuteClock(kickoffMs, nowMs) {
  // Football clock simulation: returns { state, liveTime, minute }
  var elapsed = Math.floor((nowMs - kickoffMs) / 60000)
  if (elapsed < 0) return { state: "upcoming", liveTime: "", minute: 0 }
  if (elapsed < 45) return { state: "live", liveTime: "\u200e" + Math.max(1, elapsed) + "\u2019\u200e", minute: elapsed }
  if (elapsed < 60) return { state: "live", liveTime: "HT", minute: 45 }
  if (elapsed < 108) return { state: "live", liveTime: "\u200e" + Math.min(90, elapsed - 15) + "\u2019\u200e", minute: elapsed - 15 }
  return { state: "finished", liveTime: "", minute: 90 }
}

function mockRound(sport, nowMs) {
  var now = Number(nowMs) || Date.now()
  if (!mockAnchor || mockAnchor > now) mockAnchor = now
  var anchor = mockAnchor
  var iso = function(msOffset) { return new Date(anchor + msOffset).toISOString() }
  var MIN = 60000, HOUR = 3600000, DAY = 86400000
  var s = String(sport || "football")

  function fbMatch(id, homeId, homeName, awayId, awayName, kickoffOffset, round) {
    var kickoff = anchor + kickoffOffset
    var clock = mockMinuteClock(kickoff, now)
    var homeScore = 0, awayScore = 0
    if (clock.state !== "upcoming") {
      // Scripted storyline: 0-0 → 1-0 at 18' → 1-1 at 32' (goal notification!) → 2-1 at 61'
      var elapsed = Math.floor((now - kickoff) / 60000)
      if (elapsed >= 18) homeScore = 1
      if (elapsed >= 32) awayScore = 1
      if (elapsed >= 61) homeScore = 2
    }
    return {
      id: id, sport: "football", leagueId: "47", leagueName: "Premier League",
      round: round || "",
      home: { id: homeId, name: homeName, shortName: homeName, logo: "https://images.fotmob.com/image_resources/logo/teamlogo/" + homeId + ".png" },
      away: { id: awayId, name: awayName, shortName: awayName, logo: "https://images.fotmob.com/image_resources/logo/teamlogo/" + awayId + ".png" },
      status: clock.state,
      homeScore: homeScore, awayScore: awayScore,
      scoreText: clock.state === "upcoming" ? "" : homeScore + "\u2013" + awayScore,
      statusReason: clock.state === "finished" ? "FT" : "",
      liveTime: clock.liveTime,
      time: iso(kickoffOffset),
      pageUrl: "/matches/mock/" + id
    }
  }

  function espnMatch(id, sportName, leagueName, homeId, homeAbbr, homeName, awayId, awayAbbr, awayName, kickoffOffset, state, score, clock) {
    var cdn = "https://a.espncdn.com/i/teamlogos/" + sportName + "/500/"
    return {
      id: id, sport: sportName, leagueId: sportName, leagueName: leagueName,
      round: "",
      home: { id: homeId, name: homeName, shortName: homeAbbr, abbr: homeAbbr, record: "10-4", logo: cdn + homeAbbr + ".png" },
      away: { id: awayId, name: awayName, shortName: awayAbbr, abbr: awayAbbr, record: "9-5", logo: cdn + awayAbbr + ".png" },
      status: state,
      homeScore: state === "upcoming" ? 0 : score[0],
      awayScore: state === "upcoming" ? 0 : score[1],
      scoreText: state === "upcoming" ? "" : score[0] + "\u2013" + score[1],
      statusReason: state === "finished" ? "Final" : (clock || ""),
      liveTime: state === "live" ? (clock || "LIVE") : "",
      time: iso(kickoffOffset),
      pageUrl: "https://www.espn.com/" + sportName
    }
  }

  var matches = []
  var standings = {}

  if (s === "football") {
    matches = [
      // LIVE at launch (kicked off 25 min before the panel session started)
      fbMatch("mock-fb-1", "9825", "Arsenal", "9826", "Crystal Palace", -25 * MIN, "Matchday 1"),
      // Kicks off 12 minutes in → pre-match notification + countdown
      fbMatch("mock-fb-2", "9772", "Benfica", "9773", "FC Porto", 12 * MIN, "Matchday 1"),
      // Recent result
      fbMatch("mock-fb-3", "9767", "Famalic\u00e3o", "9769", "Estoril Praia", -26 * HOUR),
      // Tomorrow
      fbMatch("mock-fb-4", "9775", "Vit\u00f3ria SC", "9771", "SC Braga", 26 * HOUR)
    ]
    standings = { "Premier League": mockFootballTable() }
  } else if (s === "nba") {
    matches = [
      espnMatch("mock-nba-1", "nba", "NBA", "13", "LAL", "Los Angeles Lakers", "2", "BOS", "Boston Celtics", -75 * MIN, "live", [98, 95], "Q3 8:44"),
      espnMatch("mock-nba-2", "nba", "NBA", "9", "GSW", "Golden State Warriors", "4", "CHI", "Chicago Bulls", 5 * HOUR, "upcoming", [0, 0], "")
    ]
    standings = {
      "Eastern Conference": mockEspnTable("nba", [["2", "BOS", "Boston Celtics"], ["4", "CHI", "Chicago Bulls"]]),
      "Western Conference": mockEspnTable("nba", [["13", "LAL", "Los Angeles Lakers"], ["9", "GSW", "Golden State Warriors"]])
    }
  } else if (s === "f1") {
    // Race happening right now (live for a 3h window, like the real parser)
    // plus the next one in 3 days — mirrors parseF1Calendar's output shape.
    function f1Race(id, round, name, circuit, locality, country, flag, raceOffset, statusOverride) {
      var raceMs = anchor + raceOffset
      var status = statusOverride
      if (!status) {
        if (now > raceMs + 3 * HOUR) status = "finished"
        else if (now >= raceMs) status = "live"
        else status = "upcoming"
      }
      return {
        id: id, sport: "f1", leagueId: "f1", leagueName: "Formula 1",
        round: round, raceName: name, circuitName: circuit,
        locality: locality, country: country, countryFlag: flag,
        status: status,
        sessions: [
          { name: "Practice 1", shortName: "FP1", time: new Date(raceMs - 2 * DAY).toISOString() },
          { name: "Qualifying", shortName: "Quali", time: new Date(raceMs - DAY).toISOString() },
          { name: "Grand Prix (Race)", shortName: "Race", time: new Date(raceMs).toISOString() }
        ],
        home: { id: "f1-gp-mock", name: name, shortName: name.replace(" Grand Prix", " GP"), record: locality + ", " + country, logo: "" },
        away: { id: "f1-circuit-mock", name: circuit, shortName: country, record: "", logo: "" },
        homeScore: 0, awayScore: 0,
        scoreText: status === "finished" ? "Official" : (status === "live" ? "RACE DAY" : round),
        statusReason: status === "finished" ? "Official" : (status === "live" ? "LIVE" : "Scheduled"),
        liveTime: status === "live" ? "RACE" : "",
        time: new Date(raceMs).toISOString(), pageUrl: "https://www.formula1.com"
      }
    }
    matches = [
      f1Race("mock-f1-1", "Round 11", "Mock Grand Prix", "Circuito da Mocka", "Lisboa", "Portugal", "\ud83c\uddf5\ud83c\uddf7", -45 * MIN),
      f1Race("mock-f1-2", "Round 12", "Sprint Mock Grand Prix", "Mock Ring", "Spielberg", "Austria", "\ud83c\udde6\ud83c\uddfa", 3 * DAY)
    ]
    standings = {
      "Drivers": mockF1Drivers(),
      "Constructors": mockF1Constructors()
    }
  } else if (s === "nfl") {
    matches = [
      espnMatch("mock-nfl-0", "nfl", "NFL", "3", "CHI", "Chicago Bears", "1", "ATL", "Atlanta Falcons", -70 * MIN, "live", [17, 10], "Q2 5:32"),
      espnMatch("mock-nfl-1", "nfl", "NFL", "2", "BUF", "Buffalo Bills", "3", "CHI", "Chicago Bears", -20 * HOUR, "finished", [27, 24], "Final"),
      espnMatch("mock-nfl-2", "nfl", "NFL", "1", "ATL", "Atlanta Falcons", "2", "BUF", "Buffalo Bills", 6 * HOUR, "upcoming", [0, 0], "")
    ]
    standings = { "AFC": mockEspnTable("nfl", [["2", "BUF", "Buffalo Bills"]]), "NFC": mockEspnTable("nfl", [["3", "CHI", "Chicago Bears"], ["1", "ATL", "Atlanta Falcons"]]) }
  } else if (s === "mlb") {
    matches = [
      espnMatch("mock-mlb-0", "mlb", "MLB", "2", "BOS", "Boston Red Sox", "10", "NYY", "New York Yankees", -90 * MIN, "live", [4, 4], "7th"),
      espnMatch("mock-mlb-1", "mlb", "MLB", "10", "NYY", "New York Yankees", "2", "BOS", "Boston Red Sox", -3 * HOUR, "finished", [5, 3], "Final"),
      espnMatch("mock-mlb-2", "mlb", "MLB", "1", "BAL", "Baltimore Orioles", "10", "NYY", "New York Yankees", 4 * HOUR, "upcoming", [0, 0], "")
    ]
    standings = { "American League": mockEspnTable("mlb", [["10", "NYY", "New York Yankees"], ["2", "BOS", "Boston Red Sox"], ["1", "BAL", "Baltimore Orioles"]]), "National League": mockEspnTable("mlb", []) }
  } else if (s === "nhl") {
    matches = [
      espnMatch("mock-nhl-1", "nhl", "NHL", "1", "BOS", "Boston Bruins", "5", "DET", "Detroit Red Wings", -2 * HOUR, "live", [2, 2], "2nd 12:00"),
      espnMatch("mock-nhl-2", "nhl", "NHL", "2", "BUF", "Buffalo Sabres", "1", "BOS", "Boston Bruins", 7 * HOUR, "upcoming", [0, 0], "")
    ]
    standings = { "Atlantic": mockEspnTable("nhl", [["1", "BOS", "Boston Bruins"], ["2", "BUF", "Buffalo Sabres"], ["5", "DET", "Detroit Red Wings"]]) }
  }

  return { matches: matches, standings: standings }
}

function mockFootballTable() {
  var teams = [
    ["9825", "Arsenal", 1], ["9772", "Benfica", 1], ["9773", "FC Porto", 0],
    ["9826", "Crystal Palace", 0], ["9771", "SC Braga", 0], ["9767", "Famalic\u00e3o", 0],
    ["9769", "Estoril Praia", 0], ["9775", "Vit\u00f3ria SC", -1]
  ]
  var rows = []
  for (var i = 0; i < teams.length; i++) {
    var t = teams[i]
    var zone = i < 3 ? "europe" : (i === teams.length - 1 ? "relegation" : "")
    rows.push({
      pos: String(i + 1), id: t[0], name: t[1], shortName: t[1],
      logo: "https://images.fotmob.com/image_resources/logo/teamlogo/" + t[0] + ".png",
      played: 10 + i, wins: 6, draws: 2, losses: 2,
      gd: t[2] * 5, pts: 20 - i, zone: zone
    })
  }
  return rows
}

function mockEspnTable(sport, teams) {
  var rows = []
  for (var i = 0; i < teams.length; i++) {
    var t = teams[i]
    var zone = ""
    if (sport === "nba") zone = i < 3 ? "europe" : "playin"
    else if (sport === "nhl") zone = i < 1 ? "europe" : ""
    else if (sport === "nfl") zone = i < 1 ? "europe" : ""
    else if (sport === "mlb") zone = i < 1 ? "europe" : ""
    rows.push({
      pos: String(i + 1), id: t[0], name: t[2], shortName: t[2], abbr: t[1],
      logo: "https://a.espncdn.com/i/teamlogos/" + sport + "/500/" + t[1] + ".png",
      played: 12, wins: 8, draws: 0, losses: 4,
      gd: "+6", pts: String(8 - i) + "W", zone: zone
    })
  }
  return rows
}

function mockF1Drivers() {
  var data = [
    ["1", "norris", "Lando Norris", "NOR", "\ud83c\uddec\ud83c\udde7", "mclaren", "McLaren", "234 PTS"],
    ["2", "piastri", "Oscar Piastri", "PIA", "\ud83c\udde6\ud83c\uddfa", "mclaren", "McLaren", "226 PTS"],
    ["3", "verstappen", "Max Verstappen", "VER", "\ud83c\uddf3\ud83c\uddf1", "red_bull", "Red Bull Racing", "210 PTS"],
    ["4", "hamilton", "Lewis Hamilton", "HAM", "\ud83c\uddec\ud83c\udde7", "ferrari", "Ferrari", "152 PTS"],
    ["5", "leclerc", "Charles Leclerc", "LEC", "\ud83c\uddf2\ud83c\udde8", "ferrari", "Ferrari", "148 PTS"]
  ]
  var rows = []
  for (var i = 0; i < data.length; i++) {
    var d = data[i]
    rows.push({
      pos: d[0], id: d[1], name: d[2], shortName: d[3], abbr: d[3],
      flag: d[4], teamId: d[5], teamName: d[6],
      played: 11, wins: i === 0 ? 5 : 1, draws: 0, losses: 0,
      gd: d[6], pts: d[7], zone: i < 3 ? "europe" : ""
    })
  }
  return rows
}

function mockF1Constructors() {
  var data = [
    ["1", "mclaren", "McLaren", "460 PTS"],
    ["2", "red_bull", "Red Bull Racing", "341 PTS"],
    ["3", "ferrari", "Ferrari", "300 PTS"]
  ]
  var rows = []
  for (var i = 0; i < data.length; i++) {
    rows.push({
      pos: data[i][0], id: data[i][1], name: data[i][2], shortName: data[i][2],
      abbr: data[i][1], logo: "", played: 11, wins: 0, draws: 0, losses: 0,
      gd: data[i][2], pts: data[i][3], zone: i === 0 ? "europe" : ""
    })
  }
  return rows
}

// ============================================================================
// UNIVERSAL MATCH & TEAM DISCOVERY HELPERS
// ============================================================================

function teamOptionsForSport(sport, matches) {
  var s = String(sport || "football").toLowerCase()
  if (s === "nba") return nbaTeams
  if (s === "f1") return f1Drivers
  if (s === "nfl") return nflTeams
  if (s === "mlb") return mlbTeams
  if (s === "nhl") return nhlTeams

  var byId = {}
  for (var p = 0; p < popularFootballClubs.length; p++) {
    var club = popularFootballClubs[p]
    byId[String(club.value)] = club
  }

  var source = arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var match = source[i]
    if (!match) continue
    if (match.home && match.home.id && match.home.name) {
      var hId = String(match.home.id)
      if (!byId[hId]) {
        byId[hId] = {
          value: hId,
          label: match.home.name,
          description: match.leagueName || "Football"
        }
      }
    }
    if (match.away && match.away.id && match.away.name) {
      var aId = String(match.away.id)
      if (!byId[aId]) {
        byId[aId] = {
          value: aId,
          label: match.away.name,
          description: match.leagueName || "Football"
        }
      }
    }
  }
  var list = []
  for (var key in byId) list.push(byId[key])
  list.sort(function(a, b) { return a.label.localeCompare(b.label) })
  return list
}

function isFollowedTeam(teamId, teamIds) {
  var id = String(teamId || "").trim().toLowerCase()
  if (!id) return false
  var ids = (typeof teamIds === "string" || typeof teamIds === "number") ? [teamIds] : arrayFrom(teamIds)
  for (var i = 0; i < ids.length; i++) {
    if (String(ids[i] || "").trim().toLowerCase() === id) return true
  }
  return false
}

function isNumericIdentifier(value) {
  return /^\d+$/.test(String(value || "").trim())
}

function compareMatchTimes(a, b) {
  var ta = parseMatchTimeMs(a)
  var tb = parseMatchTimeMs(b)
  if (isNaN(ta) && isNaN(tb)) return 0
  if (isNaN(ta)) return 1
  if (isNaN(tb)) return -1
  return ta - tb
}

function matchesForTeam(matches, teamIdOrIds, sport) {
  var s = String(sport || "football").toLowerCase()
  if (s === "f1") {
    return arrayFrom(matches)
  }
  var rawIds = Array.isArray(teamIdOrIds) ? teamIdOrIds : [teamIdOrIds]
  var ids = []
  for (var k = 0; k < rawIds.length; k++) {
    var str = String(rawIds[k] || "").trim().toLowerCase()
    if (str && ids.indexOf(str) === -1) ids.push(str)
  }
  if (ids.length === 0) return []

  var result = []
  var seen = {}
  var source = arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m || seen[m.id]) continue
    var homeId = String(m.home && m.home.id || "").toLowerCase()
    var awayId = String(m.away && m.away.id || "").toLowerCase()
    var homeName = String(m.home && m.home.name || "").trim().toLowerCase()
    var awayName = String(m.away && m.away.name || "").trim().toLowerCase()
    var homeShort = String(m.home && m.home.shortName || "").trim().toLowerCase()
    var awayShort = String(m.away && m.away.shortName || "").trim().toLowerCase()

    var matchFound = false
    for (var j = 0; j < ids.length; j++) {
      var id = ids[j]
      // Provider ids are authoritative. Do not use substring matching for
      // numeric ids: team id "7" must not match a team named "76ers".
      if (homeId === id || awayId === id) {
        matchFound = true
        break
      }
      if (!isNumericIdentifier(id) && (homeName === id || awayName === id || homeShort === id || awayShort === id)) {
        matchFound = true
        break
      }
    }
    if (matchFound) {
      seen[m.id] = true
      result.push(m)
    }
  }
  result.sort(compareMatchTimes)
  return result
}

function matchesForLeague(matches, leagueId) {
  var id = String(leagueId || "")
  if (!id) return arrayFrom(matches)
  var result = []
  var source = arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (m && String(m.leagueId) === id) result.push(m)
  }
  result.sort(compareMatchTimes)
  return result
}

function featuredMatchForTeam(teamMatches) {
  var source = arrayFrom(teamMatches)
  if (source.length === 0) return null

  // 1. Live match first
  for (var i = 0; i < source.length; i++) {
    if (source[i] && source[i].status === "live") return source[i]
  }

  // 2. Next upcoming match
  var now = Date.now()
  var bestUpcoming = null
  var bestUpcomingTime = Infinity
  for (var j = 0; j < source.length; j++) {
    var m = source[j]
    if (!m || m.status !== "upcoming") continue
    var t = parseMatchTimeMs(m)
    if (isNaN(t) || t < now) continue
    if (t < bestUpcomingTime) {
      bestUpcomingTime = t
      bestUpcoming = m
    }
  }
  if (bestUpcoming) return bestUpcoming

  // 3. Most recent finished match
  var bestFinished = null
  var bestFinishedTime = -Infinity
  for (var k = 0; k < source.length; k++) {
    var fm = source[k]
    if (!fm || fm.status !== "finished") continue
    var ft = parseMatchTimeMs(fm)
    if (isNaN(ft)) continue
    if (ft > bestFinishedTime) {
      bestFinishedTime = ft
      bestFinished = fm
    }
  }
  return bestFinished || source[0]
}

function teamIdForMatch(match, teamIds) {
  if (!match) return ""
  var ids = (typeof teamIds === "string" || typeof teamIds === "number") ? [teamIds] : arrayFrom(teamIds)
  for (var i = 0; i < ids.length; i++) {
    var id = String(ids[i] || "").trim()
    var normalized = id.toLowerCase()
    if (id && (String(match.home && match.home.id || "").toLowerCase() === normalized
        || String(match.away && match.away.id || "").toLowerCase() === normalized)) return id
  }
  return ""
}

function teamOutcomeForTeams(match, teamIds) {
  return teamOutcome(match, teamIdForMatch(match, teamIds))
}

function isStandingsRowFavorite(row, teamIds, selectedTeamName) {
  if (!row) return false
  if (isFollowedTeam(row.id, teamIds) || isFollowedTeam(row.teamId, teamIds)) return true
  var name = String(selectedTeamName || "").trim().toLowerCase()
  if (!name) return false
  return String(row.name || "").trim().toLowerCase() === name
    || String(row.shortName || "").trim().toLowerCase() === name
}

function teamOutcome(match, teamId) {
  if (!match || match.status !== "finished") return ""
  var id = String(teamId || "").toLowerCase()
  var homeId = String(match.home && match.home.id || "").toLowerCase()
  var awayId = String(match.away && match.away.id || "").toLowerCase()
  var isHome = homeId === id
  var isAway = awayId === id
  if (!isHome && !isAway) return ""

  var hs = parseInt(match.homeScore, 10) || 0
  var as = parseInt(match.awayScore, 10) || 0
  if (hs === as) return "draw"
  if (isHome) return hs > as ? "win" : "loss"
  return as > hs ? "win" : "loss"
}

function groupMatches(matches) {
  var source = arrayFrom(matches)
  if (source.length === 0) return []

  var live = []
  var upcoming = []
  var recent = []

  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m) continue
    if (m.status === "live") live.push(m)
    else if (m.status === "upcoming") upcoming.push(m)
    else recent.push(m)
  }

  live.sort(compareMatchTimes)
  upcoming.sort(compareMatchTimes)
  recent.sort(function(a, b) {
    var aTime = parseMatchTimeMs(a)
    var bTime = parseMatchTimeMs(b)
    if (isNaN(aTime) && isNaN(bTime)) return 0
    if (isNaN(aTime)) return 1
    if (isNaN(bTime)) return -1
    return bTime - aTime
  })

  var groups = []
  if (live.length > 0) {
    groups.push({ key: "live", label: "Live Matches", matches: live })
  }
  if (upcoming.length > 0) {
    groups.push({ key: "upcoming", label: "Upcoming Fixtures", matches: upcoming })
  }
  if (recent.length > 0) {
    groups.push({ key: "recent", label: "Recent Results", matches: recent.slice(0, 10) })
  }
  return groups
}

function formatMatchDate(timeStr) {
  var t = parseMatchTimeMs({ time: timeStr })
  if (isNaN(t)) return "TBD"
  var d = new Date(t)
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()]
}

function matchStatusText(match) {
  if (!match) return ""
  if (match.status === "live") return match.liveTime || "LIVE"
  if (match.status === "finished") return "FT"
  if (match.status === "cancelled") return "Postponed"
  return formatMatchDate(match.time)
}

// Between provider polls, tick a football live clock forward from the last
// fetched minute using wall-clock time, capped by a stoppage-time buffer so we
// never run far ahead of the broadcast clock. Returns the original string
// untouched when the data is fresh or the clock is not a plain minute
// ("HT", "45+2’", quarter labels, penalties…).
function interpolateLiveTime(match, nowMs, fetchedAtMs) {
  if (!match || match.status !== "live") return match ? String(match.liveTime || "") : ""
  if (match.sport && match.sport !== "football") return String(match.liveTime || "")
  var lt = String(match.liveTime || "")
  // Only tick a bare minute like "13" / "13’" — never "8:44", "45+2’, "HT"…
  // (strip invisible LRM/RLM bi-di control chars FotMob wraps its clocks in)
  var cleaned = lt.replace(/[\u200e\u200f\s]/g, "")
  var m = cleaned.match(/^(\d{1,3})[\u2019\u2032']?$/)
  if (!m) return lt
  var base = parseInt(m[1], 10)
  if (base < 0 || base > 130) return lt
  var age = (Number(nowMs) - Number(fetchedAtMs)) / 60000
  if (!isFinite(age) || age <= 0) return lt
  var drift = Math.floor(age)
  if (drift <= 0) return lt
  // Never show more than +4 minutes beyond what the provider reported —
  // beyond that a refetch is overdue and guessing is worse than honesty
  return "\u200e" + String(base + Math.min(drift, 4)) + "\u2019\u200e"
}

function leagueLabel(id) {
  var s = String(id || "")
  if (s === "nba") return "NBA"
  if (s === "f1") return "Formula 1"
  if (s === "nfl") return "NFL"
  if (s === "mlb") return "MLB"
  if (s === "nhl") return "NHL"
  for (var i = 0; i < supportedLeagues.length; i++) {
    if (supportedLeagues[i].value === s) return supportedLeagues[i].label
  }
  return "League " + s
}

function sportMeta(sport) {
  var s = String(sport || "football").toLowerCase()
  for (var i = 0; i < supportedSports.length; i++) {
    if (supportedSports[i].value === s) return supportedSports[i]
  }
  return supportedSports[0]
}

function shortTournamentName(name) {
  var s = String(name || "").trim()
  if (!s) return ""
  // ESPN league display names are long; the date column only fits siglas
  if (s.indexOf("National Basketball Association") !== -1) return "NBA"
  if (s.indexOf("National Football League") !== -1 && s.indexOf("Conference") === -1) return "NFL"
  if (s.indexOf("Major League Baseball") !== -1) return "MLB"
  if (s.indexOf("National Hockey League") !== -1) return "NHL"
  if (s.indexOf("Champions League Qualification") !== -1) return "UCL Qual."
  if (s.indexOf("Champions League") !== -1) return "Champions Lg"
  if (s.indexOf("Europa League Qualification") !== -1) return "UEL Qual."
  if (s.indexOf("Europa League") !== -1) return "Europa League"
  if (s.indexOf("Conference League Qualification") !== -1) return "UECL Qual."
  if (s.indexOf("Conference League") !== -1) return "Conf. League"
  if (s.indexOf("Primeira Liga") !== -1 || s.indexOf("Liga Portugal") !== -1) return "Liga Portugal"
  if (s.indexOf("Premier League") !== -1) return "Premier Lg"
  if (s.indexOf("Taca de Portugal") !== -1 || s.indexOf("Taça de Portugal") !== -1) return "Taça Portugal"
  if (s.indexOf("Taca da Liga") !== -1 || s.indexOf("Taça da Liga") !== -1) return "Taça da Liga"
  if (s.indexOf("Copa del Rey") !== -1) return "Copa del Rey"
  if (s.indexOf("Supercopa") !== -1) return "Supercopa"
  if (s.indexOf("Club Friendlies") !== -1) return "Friendly"
  return s
}

function liveMatches(matches, detailsMap) {
  var result = []
  var source = arrayFrom(matches)
  var map = detailsMap || {}
  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m || m.status !== "live") continue
    var d = map[String(m.id)]
    if (d && (d.statusLong === "Full-Time" || d.reason === "FT" || d.finished === true)) continue
    result.push(m)
  }
  result.sort(compareMatchTimes)
  return result
}

function matchLine(match) {
  if (!match) return ""
  var home = (match.home && (match.home.shortName || match.home.name)) || ""
  var away = (match.away && (match.away.shortName || match.away.name)) || ""
  var line = home + " " + (match.scoreText || "–") + " " + away
  if (match.liveTime) line += " · " + match.liveTime
  return line
}

function leagues() { return supportedLeagues }
function sports() { return supportedSports }

// Builds the exact JSON shape Panel.qml writes to sports-favorites.json.
// Single source of truth: the round-trip test exercises THIS function, not a
// hand-copied replica, so drift between writer and reader fails fast.
// `cur` is the active sport key; `saved` is the previously persisted/parsed
// state; `ui` carries the live panel selections.
function buildPersistedState(cur, saved, ui) {
  var sportSettings = {}
  var sportsList = ["nba", "f1", "nfl", "mlb", "nhl"]
  for (var s = 0; s < sportsList.length; s++) {
    var spk = sportsList[s]
    var prevSp = saved[spk] || {}
    if (cur === spk) {
      sportSettings[spk] = {
        teamIds: ui.selectedTeamIds,
        teamId: ui.selectedTeamId,
        teamName: ui.selectedTeamName,
        standingsGroup: ui.standingsLeagueId,
        tab: ui.tabName
      }
    } else {
      sportSettings[spk] = prevSp
    }
  }

  var fb = saved.football || {}
  var fbTeamIds = cur === "football" ? ui.selectedTeamIds : (fb.teamIds || (fb.teamId ? [fb.teamId] : []))
  var payload = statePayload(
    cur,
    fb.leagueIds || ui.selectedLeagueIds,
    fbTeamIds,
    cur === "football" ? ui.selectedTeamName : fb.teamName,
    saved.refreshMinutes,
    cur === "football" ? ui.standingsLeagueId : fb.standingsLeagueId,
    sportSettings,
    ui.antiSpoiler,
    ui.enableNotifications
  )
  // Keep statePayload's positional API stable; add the active football tab at
  // the persistence boundary where the UI-specific field belongs.
  payload.football.tab = cur === "football" ? normalizeTab(ui.tabName) : normalizeTab(fb.tab)
  return payload
}

// ---- Identity stability helpers -------------------------------------------
// QML Repeaters tear down every delegate when the model array identity
// changes. Refreshes produce fresh arrays even when nothing visible changed,
// so callers compare fingerprints and keep the old array when equal.

function sameTeamData(a, b) {
  if (!a || !b) return a === b
  return String(a.id || "") === String(b.id || "")
    && String(a.name || "") === String(b.name || "")
    && String(a.shortName || "") === String(b.shortName || "")
    && String(a.abbr || "") === String(b.abbr || "")
    && String(a.record || "") === String(b.record || "")
    && String(a.logo || "") === String(b.logo || "")
}

function sameSessions(a, b) {
  var first = arrayFrom(a)
  var second = arrayFrom(b)
  if (first.length !== second.length) return false
  for (var i = 0; i < first.length; i++) {
    if (!first[i] || !second[i]) return false
    if (String(first[i].name || "") !== String(second[i].name || "")
        || String(first[i].shortName || "") !== String(second[i].shortName || "")
        || String(first[i].time || "") !== String(second[i].time || "")) return false
  }
  return true
}

function sameMatches(a, b) {
  if (a === b) return true
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false
  // Linescores (NBA/NFL quarters, NHL periods, MLB innings) are intentionally
  // excluded from the fingerprint. Total score already drives the visible delta
  // and including period-level updates would force a Repeater teardown for
  // every poll — which is how the live tab flickers every 3-4 seconds.
  // Add `linescores` here only if you also fix the Repeater churn.
  for (var i = 0; i < a.length; i++) {
    var x = a[i]
    var y = b[i]
    if (!x || !y) return false
    if (String(x.id) !== String(y.id)
        || String(x.status || "") !== String(y.status || "")
        || Number(x.homeScore || 0) !== Number(y.homeScore || 0)
        || Number(x.awayScore || 0) !== Number(y.awayScore || 0)
        || String(x.scoreText || "") !== String(y.scoreText || "")
        || String(x.liveTime || "") !== String(y.liveTime || "")
        || String(x.time || "") !== String(y.time || "")
        || String(x.leagueId || "") !== String(y.leagueId || "")
        || String(x.leagueName || "") !== String(y.leagueName || "")
        || String(x.round || "") !== String(y.round || "")
        || String(x.venue || "") !== String(y.venue || "")
        || String(x.pageUrl || "") !== String(y.pageUrl || "")
        || String(x.raceName || "") !== String(y.raceName || "")
        || String(x.circuitName || "") !== String(y.circuitName || "")
        || String(x.countryFlag || "") !== String(y.countryFlag || "")
        || !sameTeamData(x.home, y.home)
        || !sameTeamData(x.away, y.away)
        || !sameSessions(x.sessions, y.sessions)) return false
  }
  return true
}

function sameRows(a, b) {
  if (a === b) return true
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false
  for (var i = 0; i < a.length; i++) {
    var x = a[i]
    var y = b[i]
    if (!x || !y) return false
    if (String(x.pos || "") !== String(y.pos || "")
        || String(x.id || "") !== String(y.id || "")
        || String(x.name || "") !== String(y.name || "")
        || String(x.shortName || "") !== String(y.shortName || "")
        || String(x.abbr || "") !== String(y.abbr || "")
        || String(x.logo || "") !== String(y.logo || "")
        || String(x.flag || "") !== String(y.flag || "")
        || String(x.teamId || "") !== String(y.teamId || "")
        || String(x.teamName || "") !== String(y.teamName || "")
        || String(x.pts || "") !== String(y.pts || "")
        || String(x.gd || "") !== String(y.gd || "")
        || Number(x.played || 0) !== Number(y.played || 0)
        || Number(x.wins || 0) !== Number(y.wins || 0)
        || Number(x.draws || 0) !== Number(y.draws || 0)
        || Number(x.losses || 0) !== Number(y.losses || 0)
        || String(x.zone || "") !== String(y.zone || "")) return false
  }
  return true
}

function sameGroups(a, b) {
  if (a === b) return true
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false
  for (var i = 0; i < a.length; i++) {
    var x = a[i]
    var y = b[i]
    if (!x || !y) return false
    if ((x.key || "") !== (y.key || "") || (x.label || "") !== (y.label || "")) return false
    if (!sameMatches(x.matches || [], y.matches || [])) return false
  }
  return true
}

function notificationClock(timeMs) {
  var date = new Date(timeMs)
  return ("0" + date.getHours()).slice(-2) + ":" + ("0" + date.getMinutes()).slice(-2)
}

// Union of two history maps. Entries present in `next` always win; entries
// only in `prev` are kept only if their `seenAt` is within `ttl` of `now`,
// so stale ids cannot accumulate forever. Uses hasOwnProperty to avoid
// prototype pollution from keys like "__proto__" in user-edited state files.
function mergeSeenMap(prev, next, now, ttl) {
  var merged = {}
  for (var prevId in next) {
    if (Object.prototype.hasOwnProperty.call(next, prevId)) merged[prevId] = next[prevId]
  }
  for (var oldId in prev) {
    if (Object.prototype.hasOwnProperty.call(prev, oldId) && !Object.prototype.hasOwnProperty.call(merged, oldId)) {
      var oldEntry = prev[oldId]
      if (oldEntry && now - Number(oldEntry.seenAt || 0) < ttl) merged[oldId] = oldEntry
    }
  }
  return merged
}

function notificationTeamName(team) {
  return String(team && (team.name || team.shortName) || "Team")
}

// Compare a newly fetched round with the previous in-memory snapshot. The
// result contains display-ready notifications and a new history map, keeping
// all transition logic independent from QML and straightforward to test.
function diffMatchNotifications(matches, previous, options) {
  var opts = options || {}
  var oldSeen = previous && typeof previous === "object" ? previous : {}
  var source = arrayFrom(matches)
  var now = Number(opts.nowMs)
  if (!isFinite(now)) now = Date.now()
  if (opts.enabled === false) return { notifications: [], nextSeen: oldSeen }
  if (source.length === 0) {
    return { notifications: [], nextSeen: mergeSeenMap(oldSeen, {}, now, NOTIFICATION_TTL_MS) }
  }

  var activeSport = String(opts.activeSport || "").toLowerCase()
  var favoriteIds = arrayFrom(opts.favoriteIds)
  var nextSeen = {}
  var notifications = []

  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m || !m.id) continue
    var id = String(m.id)
    var hasPrevious = Object.prototype.hasOwnProperty.call(oldSeen, id)
    var candidate = hasPrevious && oldSeen[id] && typeof oldSeen[id] === "object" ? oldSeen[id] : null
    var prev = candidate && now - Number(candidate.seenAt || 0) < NOTIFICATION_TTL_MS ? candidate : null
    var homeId = String(m.home && m.home.id || "").toLowerCase()
    var awayId = String(m.away && m.away.id || "").toLowerCase()
    var isFavorite = activeSport === "f1"
      || isFollowedTeam(homeId, favoriteIds)
      || isFollowedTeam(awayId, favoriteIds)
    var homeName = notificationTeamName(m.home)
    var awayName = notificationTeamName(m.away)
    var sport = String(m.sport || activeSport || "football").toLowerCase()
    var icon = sportMeta(sport).icon
    var previousHomeScore = Number(prev && prev.homeScore || 0)
    var previousAwayScore = Number(prev && prev.awayScore || 0)
    var homeScore = Number(m.homeScore || 0)
    var awayScore = Number(m.awayScore || 0)
    var upcomingNotified = !!(prev && prev.notifiedUpcoming)

    // Never notify on first sight: the first poll establishes a baseline.
    if (prev && isFavorite) {
      if (m.status === "live" && prev.status === "upcoming") {
        notifications.push({
          kind: "started",
          matchId: id,
          sport: sport,
          iconTeam: m.home || {},
          title: sport === "f1" ? ("🏁 F1: " + (m.raceName || homeName || "Grand Prix")) : ("● LIVE: " + homeName + " vs " + awayName),
          body: sport === "f1"
            ? ("The session is underway in " + (m.locality || m.country || "live") + "!")
            : ("The match has kicked off!" + (m.leagueName ? " · " + m.leagueName : "")),
          urgency: "normal"
        })
      }

      if (m.status === "live") {
        var homeDelta = homeScore - previousHomeScore
        var awayDelta = awayScore - previousAwayScore
        if (homeDelta > 0) {
          notifications.push({
            kind: "score",
            matchId: id,
            sport: sport,
            side: "home",
            delta: homeDelta,
            iconTeam: m.home || {},
            title: sport === "football" ? ("⚽ GOAL! " + homeName) : (icon + " " + homeName + " (+" + homeDelta + ")"),
            body: opts.antiSpoiler
              ? (homeName + " scored" + (m.liveTime ? " (" + m.liveTime + ")" : ""))
              : (homeName + " " + (m.scoreText || (homeScore + " – " + awayScore)) + " " + awayName + (m.liveTime ? " (" + m.liveTime + ")" : "")),
            urgency: "normal"
          })
        }
        if (awayDelta > 0) {
          notifications.push({
            kind: "score",
            matchId: id,
            sport: sport,
            side: "away",
            delta: awayDelta,
            iconTeam: m.away || {},
            title: sport === "football" ? ("⚽ GOAL! " + awayName) : (icon + " " + awayName + " (+" + awayDelta + ")"),
            body: opts.antiSpoiler
              ? (awayName + " scored" + (m.liveTime ? " (" + m.liveTime + ")" : ""))
              : (homeName + " " + (m.scoreText || (homeScore + " – " + awayScore)) + " " + awayName + (m.liveTime ? " (" + m.liveTime + ")" : "")),
            urgency: "normal"
          })
        }
      }

      if (m.status === "upcoming" && !upcomingNotified) {
        var kickoffMs = parseMatchTimeMs(m)
        if (!isNaN(kickoffMs)) {
          var diffMins = Math.floor((kickoffMs - now) / 60000)
          if (diffMins > 0 && diffMins <= 15) {
            notifications.push({
              kind: "upcoming",
              matchId: id,
              sport: sport,
              minutes: diffMins,
              iconTeam: m.home || {},
              title: sport === "f1"
                ? ("🏎️ F1 starting soon: " + (m.raceName || homeName || "Grand Prix"))
                : ("⏰ Starting in " + diffMins + "m: " + homeName + " vs " + awayName),
              body: (m.leagueName ? m.leagueName + " · " : "") + "Scheduled start at " + notificationClock(kickoffMs),
              urgency: "normal"
            })
            upcomingNotified = true
          }
        }
      }
    }

    nextSeen[id] = {
      homeScore: homeScore,
      awayScore: awayScore,
      status: String(m.status || "upcoming"),
      notifiedUpcoming: upcomingNotified,
      seenAt: now
    }
  }

  // Keep history through transient provider omissions, but do not retain
  // unbounded match ids forever.
  return { notifications: notifications, nextSeen: mergeSeenMap(oldSeen, nextSeen, now, NOTIFICATION_TTL_MS) }
}
