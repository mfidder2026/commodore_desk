"""Test server for the WEATHER app: answers like wttr.in, without internet.

The "place" in the request picks the case (upper case, as the C64 sends it):

  SUNNY CLEARNIGHT PARTLY PARTLYNIGHT CLOUDY OVERCAST FOG LIGHTRAIN
  SHOWERS SHOWERSNIGHT HEAVYRAIN LIGHTSNOW HEAVYSNOW SLEET THUNDER
  THUNDERSNOW UNKNOWN     a weather type (with its own wind arrow)
  NOTFOUND   500 "location not found" (as wttr.in for an unknown place)
  ERROR      503 Service Unavailable
  EMPTY      200 without a body
  SLOW       waits 60 s before answering (time-out on the C64)
  LONG       a 600-byte answer (the C64 keeps 255)
  DATES      a forecast for 31 Jan, 1 Feb and 1 Mar 2027 (Sun, Mon, Mon)

Two kinds of request, as WEATHER sends them:

  ?format=%l|%x|...&m&lang=en   the weather now: one line with the same
                                fields as the real service (UTF-8 degree
                                sign and arrows); &u instead of &m gives
                                F, mph and inches
  ?format=j1                    the 3-day forecast: JSON in the layout of
                                wttr.in (sorted keys, 8 hours a day, ~30 KB);
                                day 0 is the case, day 1 and 2 the next ones

The C64 has to be pointed at this server: the test tools write
127.0.0.1 / 8000 into weHost / wePort of WEATHER before it fetches.

usage: python tools/weather_test_server.py [port]   (default 8000)
"""
import http.server
import json
import sys
import time

DAY, NIGHT = '13:45:10+0200', '23:10:00+0200'
ARROWS = '↓↙←↖↑↗→↘'              # wind blowing to S, SW, W, NW, N, NE, E, SE
DIRS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']   # where it comes from

CASES = {
    #  name           symbol  temp  feels  condition              arrow  time   WWO code
    'SUNNY':         ('o',   '+27', '+28', 'Sunny',                0, DAY,   113),
    'CLEARNIGHT':    ('o',   '+12', '+11', 'Clear',                1, NIGHT, 113),
    'PARTLY':        ('m',   '+19', '+18', 'Partly cloudy',        2, DAY,   116),
    'PARTLYNIGHT':   ('m',   '+9',  '+7',  'Partly cloudy',        3, NIGHT, 116),
    'CLOUDY':        ('mm',  '+15', '+14', 'Cloudy',               4, DAY,   119),
    'OVERCAST':      ('mmm', '+14', '+13', 'Overcast',             5, DAY,   122),
    'FOG':           ('=',   '+6',  '+4',  'Fog',                  6, DAY,   248),
    'LIGHTRAIN':     ('/',   '+11', '+9',  'Light rain',           7, DAY,   266),
    'SHOWERS':       ('.',   '+13', '+12', 'Light rain shower',    0, DAY,   176),
    'SHOWERSNIGHT':  ('.',   '+10', '+8',  'Light rain shower',    1, NIGHT, 176),
    'HEAVYRAIN':     ('//',  '+12', '+9',  'Heavy rain',           2, DAY,   302),
    'LIGHTSNOW':     ('*',   '-1',  '-5',  'Light snow',           3, DAY,   326),
    'HEAVYSNOW':     ('**',  '-4',  '-9',  'Heavy snow',           4, DAY,   338),
    'SLEET':         ('x',   '+1',  '-3',  'Light sleet',          5, DAY,   317),
    'THUNDER':       ('!/',  '+22', '+24', 'Thundery outbreaks',   6, DAY,   389),
    'THUNDERSNOW':   ('*!*', '-2',  '-7',  'Thundery snow',        7, DAY,   392),
    'UNKNOWN':       ('?',   '+12', '+10', 'Smoky haze',           0, DAY,   999),
}
NAMES = list(CASES)
DESC = {113: 'Sunny', 116: 'Partly cloudy', 119: 'Cloudy', 122: 'Overcast', 248: 'Fog',
        266: 'Light drizzle', 176: 'Patchy rain nearby', 302: 'Moderate rain',
        326: 'Light snow', 338: 'Heavy snow', 317: 'Light sleet',
        389: 'Moderate or heavy rain with thunder', 392: 'Patchy light snow with thunder',
        999: 'Smoky haze'}
RAINY = (266, 176, 302, 317, 389)


def f_of(c):
    return round(c * 9 / 5 + 32)


def line(name, us=False):
    sym, t, f, cond, arrow, now, _ = CASES[name]
    wind = 5 + arrow * 3
    if us:
        t, f = '%+d' % f_of(int(t)), '%+d' % f_of(int(f))
        return ('%s|%s|%s°F|%s°F|%s |%s%dmph|63%%|0.02 in|1012hPa|07:58:12|19:02:40|%s'
                % (name.title(), sym, t, f, cond, ARROWS[arrow], round(wind / 1.609), now))
    return ('%s|%s|%s°C|%s°C|%s |%s%dkm/h|63%%|0.4mm|1012hPa|07:58:12|19:02:40|%s'
            % (name.title(), sym, t, f, cond, ARROWS[arrow], wind, now))


def hour(h, code, temp, rain):
    return {'DewPointC': '9', 'DewPointF': '48', 'FeelsLikeC': str(temp - 1),
            'FeelsLikeF': str(f_of(temp - 1)), 'HeatIndexC': str(temp), 'HeatIndexF': str(f_of(temp)),
            'WindChillC': str(temp - 1), 'WindChillF': str(f_of(temp - 1)), 'WindGustKmph': '12',
            'WindGustMiles': '7', 'chanceoffog': '0', 'chanceoffrost': '0', 'chanceofhightemp': '0',
            'chanceofovercast': '40', 'chanceofrain': str(rain), 'chanceofremdry': '60',
            'chanceofsnow': '0', 'chanceofsunshine': '50', 'chanceofthunder': '0', 'chanceofwindy': '0',
            'cloudcover': '40', 'diffRad': '0.0', 'humidity': '70', 'precipInches': '0.0',
            'precipMM': '0.0', 'pressure': '1015', 'pressureInches': '30', 'shortRad': '0.0',
            'tempC': str(temp), 'tempF': str(f_of(temp)), 'time': str(h * 100), 'uvIndex': '1',
            'visibility': '10', 'visibilityMiles': '6', 'weatherCode': str(code),
            'weatherDesc': [{'value': DESC[code] + ' '}],
            'weatherIconUrl': [{'value': 'https://cdn.worldweatheronline.com/images/wsymbols01_png_64/'
                                         'wsymbol_0002_sunny_intervals.png'}],
            'winddir16Point': 'SW', 'winddirDegree': '225', 'windspeedKmph': '10', 'windspeedMiles': '6'}


def forecast(name):
    k = NAMES.index(name) if name in CASES else 0
    dates = ['2026-10-07', '2026-10-08', '2026-10-09']
    if name == 'DATES':
        dates = ['2027-01-31', '2027-02-01', '2027-03-01']
    days = []
    for d in range(3):
        n = NAMES[(k + d) % len(NAMES)]
        code = CASES[n][6]
        mx = int(CASES[n][1]) + 2
        mn = mx - 8
        hourly = []
        for i, h in enumerate(range(0, 24, 3)):
            other = 113 if code != 113 else 116          # only 12:00 counts
            rain = min(100, 20 + 15 * i) if code in RAINY else 5 * (i % 3)
            hourly.append(hour(h, code if h == 12 else other, mn + i, rain))
        days.append({'astronomy': [{'moon_illumination': '15', 'moon_phase': 'Waning Crescent',
                                    'moonrise': '03:42 AM', 'moonset': '05:52 PM',
                                    'sunrise': '07:52 AM', 'sunset': '07:04 PM'}],
                     'avgtempC': str((mx + mn) // 2), 'avgtempF': str(f_of((mx + mn) // 2)),
                     'date': dates[d], 'hourly': hourly, 'maxtempC': str(mx), 'maxtempF': str(f_of(mx)),
                     'mintempC': str(mn), 'mintempF': str(f_of(mn)), 'sunHour': '5.0',
                     'totalSnow_cm': '0.0', 'uvIndex': '2'})
    now = hour(13, 122, 15, 10)
    now.update({'localObsDateTime': '2026-10-07 01:45 PM', 'observation_time': '11:45 AM',
                'temp_C': '15', 'temp_F': '59'})
    data = {'current_condition': [now],
            'nearest_area': [{'areaName': [{'value': name.title()}], 'country': [{'value': 'Testland'}],
                              'latitude': '52.000', 'longitude': '4.000', 'population': '0',
                              'region': [{'value': 'Test'}], 'weatherUrl': [{'value': 'x'}]}],
            'request': [{'query': 'Lat 52.00 and Lon 4.00', 'type': 'LatLon'}],
            'weather': days}
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.0'          # the server closes: like wttr.in

    def answer(self, code, body, ctype='text/plain'):
        data = body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype + '; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        place, _, query = self.path[1:].partition('?')
        place = place.upper()
        j1 = 'format=j1' in query
        us = '&u' in query
        print("C64 asks for", repr(self.path), 'forecast' if j1 else ('now, US units' if us else 'now'),
              flush=True)
        if place == 'NOTFOUND':
            self.answer(500, 'location not found: upstream error: opencage: invalid response')
        elif place == 'ERROR':
            self.answer(503, 'Service Unavailable')
        elif place == 'EMPTY':
            self.answer(200, '')
        elif place == 'SLOW':
            time.sleep(60)
            self.answer(200, line('SUNNY'))
        elif j1:
            self.answer(200, forecast(place), 'application/json')
        elif place == 'LONG':
            self.answer(200, line('PARTLY', us) + 'x' * 600)
        elif place in CASES:
            self.answer(200, line(place, us))
        else:                               # AUTO, DATES or anything else: sunny
            self.answer(200, line('SUNNY', us))

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print('weather test server on port', port, flush=True)
    http.server.ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
