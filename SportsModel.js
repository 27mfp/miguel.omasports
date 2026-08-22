.pragma library

// ============================================================================
// MATCHDAY MULTI-SPORT DATA ENGINE
// Supports: Football (FotMob), NBA, F1, NFL, MLB, NHL (ESPN / Jolpica)
// ============================================================================

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
  var seen = {}
  var source = arrayFrom(value)
  for (var i = 0; i < source.length && result.length < 12; i++) {
    var raw = String(source[i] || "").trim()
    if (!raw || seen[raw]) continue
    seen[raw] = true
    result.push(raw)
  }
  return result
}

function normalizeTeamIds(value) {
  var result = []
  var seen = {}
  var source = arrayFrom(value)
  for (var i = 0; i < source.length && result.length < 24; i++) {
    var raw = String(source[i] || "").trim()
    if (!raw || seen[raw]) continue
    seen[raw] = true
    result.push(raw)
  }
  return result
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
  if (!parsed || typeof parsed !== "object") return defaults

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
      tab: String(obj.tab || "fixtures")
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
      tab: String(fb.tab || "fixtures")
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
  var tids = normalizeTeamIds(fbTeamIds)
  state.football = {
    leagueIds: normalizeLeagueIds(fbLeagues),
    teamIds: tids,
    teamId: String(tids.length > 0 ? tids[0] : ""),
    teamName: String(fbTeamName || ""),
    standingsLeagueId: String(fbStandingsId || (fbLeagues && fbLeagues[0]) || "47")
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
    else if (stType.name && String(stType.name).indexOf("CANCEL") !== -1) status = "cancelled"

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

function parseF1Calendar(raw) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var races = (json.MRData && json.MRData.RaceTable && json.MRData.RaceTable.Races) ? arrayFrom(json.MRData.RaceTable.Races) : []
  var now = Date.now()
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
  if (url.indexOf("http") === 0) return url
  if (url.charAt(0) === "/") return url
  return "/" + url
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
  var rows = []
  if (Array.isArray(table) && table.length > 0 && table[0].data && table[0].data.table) {
    rows = table[0].data.table.all || []
  } else if (table && table.data && table.data.table) {
    rows = table.data.table.all || []
  }
  var legend = (props && props.table && props.table[0] && props.table[0].data && props.table[0].data.legend) || []
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
      if (indices[j] === idx) {
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

function parseTeamPage(html, requestedTeamId) {
  var props = extractPageProps(html)
  var fallback = props.fallback || {}
  var teamKey = "team-" + requestedTeamId
  var teamData = fallback[teamKey] || null
  if (!teamData) {
    for (var k in fallback) {
      if (k.indexOf("team-") === 0 && fallback[k] && fallback[k].fixtures) {
        teamData = fallback[k]
        break
      }
    }
  }
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

function matchesForTeam(matches, teamIdOrIds, sport) {
  var s = String(sport || "football").toLowerCase()
  if (s === "f1") {
    return arrayFrom(matches)
  }
  var rawIds = Array.isArray(teamIdOrIds) ? teamIdOrIds : [teamIdOrIds]
  var ids = []
  for (var k = 0; k < rawIds.length; k++) {
    var str = String(rawIds[k] || "").trim().toLowerCase()
    if (str) ids.push(str)
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
    var homeName = String(m.home && m.home.name || "").toLowerCase()
    var awayName = String(m.away && m.away.name || "").toLowerCase()
    var homeShort = String(m.home && m.home.shortName || "").toLowerCase()
    var awayShort = String(m.away && m.away.shortName || "").toLowerCase()

    var matchFound = false
    for (var j = 0; j < ids.length; j++) {
      var id = ids[j]
      if (homeId === id || awayId === id || homeName.indexOf(id) !== -1 || awayName.indexOf(id) !== -1 || homeShort.indexOf(id) !== -1 || awayShort.indexOf(id) !== -1) {
        matchFound = true
        break
      }
    }
    if (matchFound) {
      seen[m.id] = true
      result.push(m)
    }
  }
  result.sort(function(a, b) {
    var ta = Date.parse(a.time || "")
    var tb = Date.parse(b.time || "")
    if (isNaN(ta)) return 1
    if (isNaN(tb)) return -1
    return ta - tb
  })
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
  result.sort(function(a, b) {
    var ta = Date.parse(a.time || "")
    var tb = Date.parse(b.time || "")
    if (isNaN(ta)) return 1
    if (isNaN(tb)) return -1
    return ta - tb
  })
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
    var t = Date.parse(m.time || "")
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
    var ft = Date.parse(fm.time || "")
    if (isNaN(ft)) continue
    if (ft > bestFinishedTime) {
      bestFinishedTime = ft
      bestFinished = fm
    }
  }
  return bestFinished || source[0]
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

function groupMatches(matches, referenceDate, dateKeyFn) {
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

  var groups = []
  if (live.length > 0) {
    groups.push({ key: "live", label: "Live Matches", matches: live })
  }
  if (upcoming.length > 0) {
    groups.push({ key: "upcoming", label: "Upcoming Fixtures", matches: upcoming })
  }
  if (recent.length > 0) {
    recent.reverse()
    groups.push({ key: "recent", label: "Recent Results", matches: recent.slice(0, 10) })
  }
  return groups
}

function formatMatchDate(timeStr) {
  var t = Date.parse(timeStr || "")
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
  result.sort(function(a, b) { return Date.parse(a.time || "") - Date.parse(b.time || "") })
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
