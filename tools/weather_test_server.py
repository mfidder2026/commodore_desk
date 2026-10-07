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

The answer has the same fields as the real service
(%l|%x|%t|%f|%C|%w|%h|%p|%P|%S|%s|%T, UTF-8 degree sign and arrows).
The C64 has to be pointed at this server: the test tools write
127.0.0.1 / 8000 into weHost / wePort of WEATHER before it fetches.

usage: python tools/weather_test_server.py [port]   (default 8000)
"""
import http.server
import sys
import time

DAY, NIGHT = '13:45:10+0200', '23:10:00+0200'
ARROWS = '↓↙←↖↑↗→↘'              # wind blowing to S, SW, W, NW, N, NE, E, SE

CASES = {
    #  name           symbol  temp  feels  condition              arrow  time
    'SUNNY':         ('o',   '+27', '+28', 'Sunny',                0, DAY),
    'CLEARNIGHT':    ('o',   '+12', '+11', 'Clear',                1, NIGHT),
    'PARTLY':        ('m',   '+19', '+18', 'Partly cloudy',        2, DAY),
    'PARTLYNIGHT':   ('m',   '+9',  '+7',  'Partly cloudy',        3, NIGHT),
    'CLOUDY':        ('mm',  '+15', '+14', 'Cloudy',               4, DAY),
    'OVERCAST':      ('mmm', '+14', '+13', 'Overcast',             5, DAY),
    'FOG':           ('=',   '+6',  '+4',  'Fog',                  6, DAY),
    'LIGHTRAIN':     ('/',   '+11', '+9',  'Light rain',           7, DAY),
    'SHOWERS':       ('.',   '+13', '+12', 'Light rain shower',    0, DAY),
    'SHOWERSNIGHT':  ('.',   '+10', '+8',  'Light rain shower',    1, NIGHT),
    'HEAVYRAIN':     ('//',  '+12', '+9',  'Heavy rain',           2, DAY),
    'LIGHTSNOW':     ('*',   '-1',  '-5',  'Light snow',           3, DAY),
    'HEAVYSNOW':     ('**',  '-4',  '-9',  'Heavy snow',           4, DAY),
    'SLEET':         ('x',   '+1',  '-3',  'Light sleet',          5, DAY),
    'THUNDER':       ('!/',  '+22', '+24', 'Thundery outbreaks',   6, DAY),
    'THUNDERSNOW':   ('*!*', '-2',  '-7',  'Thundery snow',        7, DAY),
    'UNKNOWN':       ('?',   '+12', '+10', 'Smoky haze',           0, DAY),
}


def line(name):
    sym, t, f, cond, arrow, now = CASES[name]
    return ('%s|%s|%s°C|%s°C|%s |%s%dkm/h|63%%|0.4mm|1012hPa|07:58:12|19:02:40|%s'
            % (name.title(), sym, t, f, cond, ARROWS[arrow], 5 + arrow * 3, now))


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.0'          # the server closes: like wttr.in

    def answer(self, code, body):
        data = body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        place = self.path[1:].split('?')[0].upper()
        print('C64 asks for', repr(place), flush=True)
        if place in CASES:
            self.answer(200, line(place))
        elif place == 'NOTFOUND':
            self.answer(500, 'location not found: upstream error: opencage: invalid response')
        elif place == 'ERROR':
            self.answer(503, 'Service Unavailable')
        elif place == 'EMPTY':
            self.answer(200, '')
        elif place == 'SLOW':
            time.sleep(60)
            self.answer(200, line('SUNNY'))
        elif place == 'LONG':
            self.answer(200, line('PARTLY') + 'x' * 600)
        else:                               # AUTO or anything else: sunny
            self.answer(200, line('SUNNY').replace('Sunny|', 'Sunny|', 1))

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print('weather test server on port', port, flush=True)
    http.server.ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
