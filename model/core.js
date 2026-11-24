.pragma library

// Core catalogs, bounded state parsing, and provider-neutral helpers.

var NOTIFICATION_TTL_MS = 6 * 3600 * 1000

// Polling and retry policy (centralized for one-edit maintenance).
// These were previously inlined across Panel.qml and the QML retry helpers;
// consolidating them here lets QML read them via `Model.MAX_ROUND_RETRIES`
// and friends so a new value only needs to be added once.

var MAX_ROUND_RETRIES = 2
// Retries are provider polls too: never retry faster than the documented
// provider floor, otherwise a transient error can still trigger an IP ban.

var RETRY_DELAY_ESPN_MS = 15 * 1000

var RETRY_DELAY_FOTMOB_F1_MS = 20 * 1000

var RETRY_DELAY_MS = RETRY_DELAY_ESPN_MS // compatibility for existing consumers
// Race results change only when a weekend completes, so refresh enrichment
// periodically rather than on every 20-second calendar poll.

var F1_RESULTS_REFRESH_MS = 5 * 60 * 1000

var MIN_REFRESH_MINUTES = 5

var MAX_REFRESH_MINUTES = 60

var REFRESH_OPTIONS = [5, 10, 15, 30, 45, 60]

// HOME directory fallback used by every path that writes to the user's
// cache/state file. Quickshell.env is only defined inside the QML runtime;
// under Node (e.g. the test suite) we degrade to process.env so the same
// helper is safe to call from anywhere a consumer might import SportsModel.

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

function safeHome(homeOverride) {
  var home = String(homeOverride || "")
  if (!home) {
    try {
      if (typeof Quickshell !== "undefined" && Quickshell && typeof Quickshell.env === "function") {
        home = String(Quickshell.env("HOME") || "")
      }
    } catch (e) { /* Quickshell not bound — fall through */ }
  }
  if (!home && typeof process !== "undefined" && process && process.env) {
    home = String(process.env.HOME || "")
  }
  return home || "/var/tmp"
}

function clampRefreshMinutes(value) {
  return Math.max(MIN_REFRESH_MINUTES, Math.min(MAX_REFRESH_MINUTES, parseInt(value, 10) || 15))
}

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

function dictSet(map, key, value) {
  var next = {}
  for (var k in map) {
    if (Object.prototype.hasOwnProperty.call(map, k)) next[k] = map[k]
  }
  if (value === undefined || value === null) {
    delete next[key]
  } else {
    next[key] = value
  }
  return next
}

function dictDelete(map, key) {
  return dictSet(map, key, undefined)
}

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
    backgroundUpdates: true,
    showBarTicker: true,
    showSpotlight: true,
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
  if (tab === "settings" || tab === "preferences") return "settings"
  return "fixtures"
}

function crestCacheKey(sport, teamId, abbr) {
  // The character class is filesystem-safe: any non-alphanumeric/dash/underscore
  // bytes (including provider-supplied weirdness like slashes or unicode) are
  // stripped, leaving at worst a sport-prefixed key. Unknown sport values
  // default to "football" so the cache layout is stable even when a parser
  // ships a new sport slug before the catalog knows about it.
  var sp = String(sport || "football").toLowerCase()
  var id = String(teamId || "").trim().toLowerCase()
  var a = String(abbr || "").trim().toLowerCase()
  var base = (sp === "football" || sp === "f1") ? id : (a || id)
  if (!base) return ""
  return (sp + "-" + base).replace(/[^a-z0-9_-]/g, "")
}

function espnDateList(daysBack, daysAhead, nowMs) {
  function fmt(d) {
    var y = d.getFullYear()
    var m = ("0" + (d.getMonth() + 1)).slice(-2)
    var day = ("0" + d.getDate()).slice(-2)
    return y + m + day
  }
  var now = new Date(typeof nowMs === "number" ? nowMs : Date.now())
  var back = typeof daysBack === "number" ? daysBack : 1
  var ahead = typeof daysAhead === "number" ? daysAhead : 3
  var days = []
  for (var i = -back; i <= ahead; i++) {
    // Calendar arithmetic (not +86400000) so DST switches never skip or
    // repeat a local day
    days.push(fmt(new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, 12)))
  }
  return days
}

function mergeEspnScoreboardPayloads(payloads) {
  var list = arrayFrom(payloads)
  var merged = { leagues: [], events: [] }
  var seen = {}
  for (var p = 0; p < list.length; p++) {
    var json = list[p]
    if (!isEspnScoreboardPayload(json)) continue
    if (merged.leagues.length === 0 && Array.isArray(json.leagues)) merged.leagues = json.leagues
    var events = arrayFrom(json.events)
    for (var e = 0; e < events.length; e++) {
      var ev = events[e]
      if (!ev) continue
      var id = String(ev.id || "")
      if (id) {
        if (seen[id] !== undefined) {
          // Later payloads were fetched later; prefer their fresher status
          merged.events[seen[id]] = ev
          continue
        }
        seen[id] = merged.events.length
      }
      merged.events.push(ev)
    }
  }
  merged.events.sort(function(a, b) {
    return (Date.parse(a.date || "") || 0) - (Date.parse(b.date || "") || 0)
  })
  return merged
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
    backgroundUpdates: parsed.backgroundUpdates !== false,
    showBarTicker: parsed.showBarTicker !== false,
    showSpotlight: parsed.showSpotlight !== false,
    refreshMinutes: clampRefreshMinutes(parsed.refreshMinutes)
  }
}

function statePayload(sport, fbLeagues, fbTeamIds, fbTeamName, refreshMinutes, fbStandingsId, sportSettings, antiSpoiler, notifications, backgroundUpdates, showBarTicker, showSpotlight) {
  var state = defaultState()
  state.sport = String(sport || "football")
  state.antiSpoiler = antiSpoiler === true
  state.notifications = notifications !== false
  state.backgroundUpdates = backgroundUpdates !== false
  state.showBarTicker = showBarTicker !== false
  state.showSpotlight = showSpotlight !== false
  state.refreshMinutes = clampRefreshMinutes(refreshMinutes)
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

function monogramText(abbr, teamName) {
  var abbreviation = String(abbr || "").trim()
  if (abbreviation) {
    return abbreviation.substring(0, 3).toUpperCase()
  }
  var name = String(teamName || "").trim()
  if (!name) return "?"
  var parts = name.split(/\s+/)
  if (parts.length >= 2) {
    return String(parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase()
  }
  return name.slice(0, 2).toUpperCase()
}
