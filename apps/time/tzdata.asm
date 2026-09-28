#importonce
//========================================================
// apps/time/tzdata.asm - tijdzones voor SYSTEM -> TIME
// Commodore Desk 64
//
// Alle UTC-verschuivingen (-12:00 tot +14:00, ook de halve en de
// kwartieren), met voorbeeldsteden. Waar landen met dezelfde verschuiving
// een andere zomertijd hebben, staan ze apart. Per zone: verschuiving in
// kwartieren (tzQ, met teken) en de zomertijdregel (tzRule, zie time.asm).
// TZ_DEFAULT (layout.inc) moet naar AMSTERDAM, BERLIN, PARIS wijzen.
//========================================================

.const DST_NONE = 0
.const DST_EU   = 1              // laatste zondag maart - laatste zondag oktober
.const DST_US   = 2              // 2e zondag maart - 1e zondag november
.const DST_AU   = 3              // 1e zondag oktober - 1e zondag april
.const DST_NZ   = 4              // laatste zondag september - 1e zondag april

.encoding "screencode_upper"
.var tzList = List()
.function tz(q, rule, name) {
        .return List().add(q, rule, name)
}
.eval tzList.add(tz(-48, DST_NONE, "BAKER ISLAND"))
.eval tzList.add(tz(-44, DST_NONE, "PAGO PAGO, NIUE"))
.eval tzList.add(tz(-40, DST_NONE, "HONOLULU, TAHITI"))
.eval tzList.add(tz(-38, DST_NONE, "MARQUESAS ISLANDS"))
.eval tzList.add(tz(-36, DST_US,   "ANCHORAGE"))
.eval tzList.add(tz(-32, DST_US,   "LOS ANGELES, VANCOUVER"))
.eval tzList.add(tz(-28, DST_US,   "DENVER, CALGARY"))
.eval tzList.add(tz(-28, DST_NONE, "PHOENIX"))
.eval tzList.add(tz(-24, DST_US,   "CHICAGO, WINNIPEG"))
.eval tzList.add(tz(-24, DST_NONE, "MEXICO CITY, COSTA RICA"))
.eval tzList.add(tz(-20, DST_US,   "NEW YORK, TORONTO"))
.eval tzList.add(tz(-20, DST_NONE, "BOGOTA, LIMA, PANAMA"))
.eval tzList.add(tz(-16, DST_US,   "HALIFAX, BERMUDA"))
.eval tzList.add(tz(-16, DST_NONE, "CARACAS, LA PAZ"))
.eval tzList.add(tz(-14, DST_US,   "NEWFOUNDLAND"))
.eval tzList.add(tz(-12, DST_NONE, "SAO PAULO, BUENOS AIRES"))
.eval tzList.add(tz(-8,  DST_NONE, "SOUTH GEORGIA"))
.eval tzList.add(tz(-4,  DST_EU,   "AZORES"))
.eval tzList.add(tz(-4,  DST_NONE, "CAPE VERDE"))
.eval tzList.add(tz(0,   DST_NONE, "UTC, REYKJAVIK, ACCRA"))
.eval tzList.add(tz(0,   DST_EU,   "LONDON, DUBLIN, LISBON"))
.eval tzList.add(tz(4,   DST_EU,   "AMSTERDAM, BERLIN, PARIS"))
.eval tzList.add(tz(4,   DST_NONE, "LAGOS, ALGIERS, TUNIS"))
.eval tzList.add(tz(8,   DST_EU,   "ATHENS, HELSINKI, KYIV"))
.eval tzList.add(tz(8,   DST_NONE, "JOHANNESBURG, HARARE"))
.eval tzList.add(tz(12,  DST_NONE, "MOSCOW, ISTANBUL, RIYADH"))
.eval tzList.add(tz(14,  DST_NONE, "TEHRAN"))
.eval tzList.add(tz(16,  DST_NONE, "DUBAI, BAKU, TBILISI"))
.eval tzList.add(tz(18,  DST_NONE, "KABUL"))
.eval tzList.add(tz(20,  DST_NONE, "KARACHI, TASHKENT"))
.eval tzList.add(tz(22,  DST_NONE, "MUMBAI, DELHI, COLOMBO"))
.eval tzList.add(tz(23,  DST_NONE, "KATHMANDU"))
.eval tzList.add(tz(24,  DST_NONE, "DHAKA, ALMATY"))
.eval tzList.add(tz(26,  DST_NONE, "YANGON"))
.eval tzList.add(tz(28,  DST_NONE, "BANGKOK, JAKARTA, HANOI"))
.eval tzList.add(tz(32,  DST_NONE, "BEIJING, PERTH, MANILA"))
.eval tzList.add(tz(35,  DST_NONE, "EUCLA"))
.eval tzList.add(tz(36,  DST_NONE, "TOKYO, SEOUL"))
.eval tzList.add(tz(38,  DST_NONE, "DARWIN"))
.eval tzList.add(tz(38,  DST_AU,   "ADELAIDE"))
.eval tzList.add(tz(40,  DST_NONE, "BRISBANE, GUAM"))
.eval tzList.add(tz(40,  DST_AU,   "SYDNEY, MELBOURNE"))
.eval tzList.add(tz(44,  DST_NONE, "NOUMEA, SOLOMON ISLANDS"))
.eval tzList.add(tz(48,  DST_NZ,   "AUCKLAND, WELLINGTON"))
.eval tzList.add(tz(48,  DST_NONE, "FIJI, KAMCHATKA"))
.eval tzList.add(tz(51,  DST_NZ,   "CHATHAM ISLANDS"))
.eval tzList.add(tz(52,  DST_NONE, "TONGA, SAMOA"))
.eval tzList.add(tz(56,  DST_NONE, "KIRITIMATI"))

.eval tzList.lock()
.const TZ_N = tzList.size()
.assert "TZ_DEFAULT = AMSTERDAM", tzList.get(TZ_DEFAULT).get(2), "AMSTERDAM, BERLIN, PARIS"
.for (var i = 0; i < TZ_N; i++) {
        .assert "tijdzonenaam max 24 tekens", tzList.get(i).get(2).size() <= 24, true
}

.const TZ_NW = 25                // naam: 24 tekens + $ff, vaste breedte
tzQ:
.for (var i = 0; i < TZ_N; i++) .byte tzList.get(i).get(0) & $ff
tzRule:
.for (var i = 0; i < TZ_N; i++) .byte tzList.get(i).get(1)
tzNameLo: .fill TZ_N, <[tzNames + i*TZ_NW]
tzNameHi: .fill TZ_N, >[tzNames + i*TZ_NW]
tzNames:
.for (var i = 0; i < TZ_N; i++) {
        .text tzList.get(i).get(2)
        .fill TZ_NW - tzList.get(i).get(2).size(), $ff
}
