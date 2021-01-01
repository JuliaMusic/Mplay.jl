const korg_drumset = (
  (
    36, 36, 36, 36, 39, 38, 38, 40, 40, 40, 37, 40,     # A09
    45, 50, 50, 50, 50, 42, 42, 42, 46, 46, 54, 42,
    49, 57, 51, 59, 70, 69, 39, 61, 62, 60, 56, 64,
    63, 66, 80, 65, 81, 29, 30, 38, 38, 38,  0,  0,
    40,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
  ),
  (
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,     # A29
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
  ),
  (
    36, 36, 36, 36, 36, 36, 36, 36, 35, 35, 35, 35,     # B09
    35, 35, 35, 35, 40, 38, 38, 38, 38, 38, 38, 38,
    37, 38, 38, 25, 25, 38, 38, 38, 38, 38, 38, 38,
    42, 42, 46, 44, 42, 46, 49, 49, 49, 49, 57,  0,
    59, 43, 41, 47, 45, 50, 48, 47, 47, 47, 47,  0
  ),
  (
    36, 37, 38, 39, 40, 47, 42, 44, 42, 48, 46, 44,     # B29
    50, 49, 57, 51, 53, 63, 62, 63, 76, 56, 75, 66,
    65, 65, 61, 54, 60, 60, 69, 70, 60, 70, 70, 70,
    80, 26, 81, 85, 77, 76, 68, 76, 67, 75, 67, 75,
     0, 56,  0, 77, 62, 63, 71, 63,  0,  0, 84, 84
  )
)

const korg_map = (
  (
    92,  -1, -63,  74, -25,  12, -33, -49, -82,   1,  # A00 - A99
  -101,   6,  57,  67,  30,  13, -35, -43,  83, 126,
   100,  18, -64,  86, -37,  89,   5, -50,   5,   1,
    89,  26, -59,  69,  18, 115, -35, -53, -82,-114,
   124,   5, -64,  23, -38,  89, -37, -42,  48,   4,
   -52, 101, -58, -67,  -7,  99,  62,  47,  49,  56,
    95,  -8, -70,  87, -44,  13, -62,  54,  91,   1,
     6,  18,  58, -72,  -3, 116, -38, -51,  73, 124,
    -6,  80,  -5, +74, -28, 123,   1, -54, 128,  18,
    18,  20, 123, -67, 100, +99, -39, -50,  82, 123
  ),
  (
   -92,  -3, -61,  72, -25,  12, -33, -49, -52,   1,  # B00 - B99
    77,   6,  57,  65, -32, 109,  52,  44,  51, 123,
    95,  17,  62,  76,  25, 101, -39,  50, 100,   1,
   -20,  -6, -61, -69,-103, 115, -35, -53, -82, -48,
   -62,  -5,  82,  22, -29, +97, -38, +86,  47,   1,
    96,  -6, -58, -68,  47, +48,  89,  46, -51,   1,
   103,  18, -62, -91,  27,  12,  64,  95,  91,   1,
   +17,  18, -64, -44, 106, +11,  50, -50,  80, 102,
    95,   6,  84,  70, -28, +99, -33,  55, -54, 102,
    98, -20, -63, 110, 108,  15, -39,  52,  82, 123
  )
)

const korg_instruments = (
  (
    "Ephemerals", "16' Piano ", "Orchbrass ", "Woodwind  ", "RosewoodGt",
    "VS Bells 1", "XFade Bass", "TheStrings", "Residrops ", "Total Kit ",
    "GhostRyder", "DigiPiano1", "OrchTrpts ", "Alto Sax  ", "Alan's Run",
    "Marimba   ", "B.Bass    ", "ChamberEns", "Tidal Wave", "Jet Stream",
    "OxygenMask", "Perc.Org 1", "Brass Band", "Bottles   ", "ZingString",
    "SolarBells", "RezzzzBass", "Analog Pad", "SynPiano  ", "Dance Kit ",
    "Fresh Air ", "DoubleStop", "FrHrn&Tuba", "Sweet Oboe", "Harmonics1",
    "SteelDrums", "Pick Bass ", "Choir L+R ", "Raw Deal  ", "Mr. Gong  ",
    "FreeFlight", "Hard Tines", "Fat Synth ", "Harmonica ", "Strategy  ",
    "Borealis  ", "SlapBass 1", "Bass&Cello", "AnalogPerc", "FreezeDrum",
    "DesertDawn", "PadPiano 1", "Trombone 1", "Tenor Sax ", "Blue Moon ",
    "XpressBell", "TKO Bass  ", "Harp      ", "Soft Pad  ", "Orch Hit  ",
    "Syn Choir ", "Clav      ", "Mute Ens. ", "Tin Flute ", "JStick Wah",
    "DigiBell  ", "OctaveBass", "Voices    ", "RezzzzzPad", "VeloGated ",
    "Aliabase  ", "Spit Organ", "FanFare   ", "Clarinet  ", "PedalSteel",
    "Log Drums ", "Seq. Bass ", "ArcoAttack", "Expecting ", "Crickets  ",
    "Shimmering", "Whirly    ", "Muted Trpt", "Flute     ", "Clean Gtr ",
    "Bell Rise ", "Deep Bass ", "Air Vox   ", "NuclearSun", "50's SciFi",
    "UnderWater", "Full Pipes", "JSDogfight", "PerkySaxes", "Sitar     ",
    "Metal Bell", "BowBowBass", "SadStrings", "MonoLead 1", "Flutter   "
  ),
  (
    "DreamWeave", "8' Piano  ", "Velo.Horns", "SweetReeds", "ClassicGtr",
    "VS Bells 2", "A.Bass 1  ", "YourString", "Bellevue  ", "MrProducer",
    "Pitzpan   ", "DigiPiano2", "Trumpet   ", "SopranoSax", "FeedBacker",
    "Kalimba   ", "E.Bass 3  ", "Rosin Bros", "Tona Pad  ", "Stadium!!!",
    "Lub Pad   ", "CX-3      ", "Brass 1   ", "Pan Flute ", "A.Guitar  ",
    "EtherBells", "Resi Bass ", "String Pad", "Tap Dance ", "Percussion",
    "Sanctuary ", "DWGS EP   ", "FrenchBoys", "BasoonOboe", "Harmonics2",
    "Gamelan   ", "Syn Pick  ", "Choir     ", "Shapedet  ", "Timpani   ",
    "BellShower", "Old  EP   ", "LeadStab 1", "Musette   ", "MuteGuitar",
    "Baby'sGone", "SlapBass 2", "Stradivari", "Quitar    ", "Velo Perc ",
    "Hyperborea", "Super Tine", "Trombone 2", "Bari.Sax  ", "Hackbrett ",
    "SplitBells", "Tech Bass ", "Pizzicato ", "Pulse Pad ", "Drum Hit  ",
    "AirFlight ", "Gospel Org", "Brass 2   ", "Arabesque ", "JazzGuitar",
    "Vibraphone", "Fretless  ", "Heavenly  ", "WS Analog ", "Orch Perc ",
    "Gasmore   ", "PercOrg 2 ", "Soft Horns", "Bassoon   ", "Mr. Banjoe",
    "Music Box ", "Cool Bass ", "Marcato   ", "MlwSquares", "Shellphone",
    "Ghost Pad ", "Digi Years", "Muted Bone", "EnglishHrn", "Mr. Clean ",
    "Bell Tree ", "A.Bass 2  ", "Vox Voice ", "Vox Dude !", "AlienVisit",
    "Spectrum  ", "Positive  ", "SFZ Brass ", "Scotland  ", "Koto      ",
    "Tubular   ", "Stab Bass ", "Too Bad...", "MonoLead 2", "Steam     "
  )
)

drumkit = zeros(Int, 16)
bank = zeros(Int, 16)
drum_channel = 9

korg = false
