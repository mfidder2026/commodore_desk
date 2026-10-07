"""Test server for WEB (the CD64 browser): every case on its own page.

  /               index with links to everything
  /tags           headings, paragraphs, lists, bold, <pre>, <hr>, tables,
                  images (alt / no alt / empty alt), entities, script/style
  /utf8           UTF-8 accents, quotes, dashes, an emoji (skipped)
  /latin1         the same text in ISO-8859-1
  /long           a page of ~200 KB (WEB shows the start + "PAGE TOO LONG")
  /links          300 links; every 10th has an address of 300+ characters
                  (WEB keeps only a check number for those and finds them
                  again by reading the page once more)
  /target?n=N     where those links go
  /rel/a/b.html   relative links: ../x.html ./y.html z.html /abs ?q=1 //host
  /redirect       302 -> /tags
  /loop           301 -> /loop (WEB stops after 5)
  /https          301 -> https://example.com/ (WEB: HTTPS NOT POSSIBLE)
  /missing        404 with its own page
  /text.txt       text/plain (with long lines)
  /file.prg       application/octet-stream (WEB: CANNOT SHOW)
  /form           a GET search form (text field + hidden field + button)
  /search?q=...   shows what was searched (and the hidden field)
  /post           a POST form (WEB ignores it)
  /slow           waits 60 s (RUN/STOP on the C64)
  /empty          200 without a body

usage: python tools/web_test_server.py [port]   (default 8099)
"""
import http.server
import sys
import time
import urllib.parse

ESC = urllib.parse.quote


def page(title, body):
    return ('<!DOCTYPE html>\n<html><head><meta charset="utf-8"><title>%s</title>\n'
            '<style>body { color: red; } /* not shown */</style>\n'
            '<script>var x = "<b>not shown</b>"; if (a < b) {}</script></head>\n'
            '<body>%s</body></html>\n' % (title, body))


INDEX = page('CD64 web test', '''<h1>WEB test pages</h1>
<ul>
<li><a href="/tags">Tags</a></li>
<li><a href="/utf8">UTF-8</a> and <a href="/latin1">Latin-1</a></li>
<li><a href="/long">A very long page</a></li>
<li><a href="/links">300 links</a></li>
<li><a href="/rel/a/b.html">Relative links</a></li>
<li><a href="/redirect">Redirect</a>, <a href="/loop">loop</a>, <a href="/https">to https</a></li>
<li><a href="/missing">404</a>, <a href="/text.txt">text</a>, <a href="/file.prg">a PRG</a></li>
<li><a href="/form">Search form</a>, <a href="/post">POST form</a></li>
<li><a href="/slow">Slow</a>, <a href="/empty">empty</a></li>
</ul>''')

TAGS = page('Tags &amp; more', '''<h1>Heading one</h1>
<p>A paragraph with <b>bold</b>, <strong>strong</strong> and <i>italic</i> words that is long
enough to wrap over more than one line of thirty-five characters.</p>
<h2>Lists</h2>
<ul><li>First item</li><li>Second item with a <a href="/tags">link in it</a></li></ul>
<ol><li>One</li><li>Two</li></ol>
<p>Entities: &amp; &lt;tag&gt; &quot;quoted&quot; caf&eacute; na&iuml;ve &copy; 2026 &#65;&#x42;C &hellip; &nbsp;end</p>
<pre>
  +-----+
  | PRE |   keeps   spaces
  +-----+
</pre>
<hr>
<table><tr><th>Name</th><td>CD64</td></tr><tr><th>Year</th><td>2026</td></tr></table>
<p>Images: <img src="a.png" alt="a cat"> <img src="b.png"> <img src="c.png" alt=""> done.</p>
<!-- a comment <b>not shown</b> -->
<noscript>Shown, because WEB has no JavaScript.</noscript>
<p>A&nbsp;word&nbsp;chain&nbsp;that&nbsp;is&nbsp;much&nbsp;too&nbsp;long&nbsp;for&nbsp;one&nbsp;line.</p>
<p>Supercalifragilisticexpialidociouswordthatneverstops.</p>''')

UTF8 = page('UTF-8', '''<p>Café crème, naïve, Ångström, Straße, ça va.</p>
<p>“Quotes” and ‘single’ – dash — em… bullet • euro &euro;.</p>
<p>Emoji \U0001F600 gone, CJK 中 gone.</p>''')

LATIN1 = ('<html><head><title>Latin-1</title></head><body>'
          '<p>Café crème, naïve, Ångström, Straße, ça va.</p></body></html>')


def links_page():
    out = ['<h1>300 links</h1>']
    for i in range(300):
        if i % 10 == 9:
            href = '/target?n=%d&amp;pad=%s' % (i, 'x' * 300)
        else:
            href = '/target?n=%d' % i
        out.append('<a href="%s">Link %d</a> ' % (href, i))
        if i % 3 == 2:
            out.append('<br>\n')
    return page('300 links', ''.join(out))


REL = page('Relative', '''<p><a href="../x.html">up</a></p>
<p><a href="./y.html">dot</a></p>
<p><a href="z.html">same dir</a></p>
<p><a href="/abs">absolute path</a></p>
<p><a href="?q=1">query</a></p>
<p><a href="//127.0.0.1:%d/proto">protocol relative</a></p>
<p><a href="#top">anchor (not a link)</a> <a href="mailto:a@b.c">mail (not a link)</a></p>''')

FORM = page('Search', '''<h1>Search</h1>
<form action="/search" method="get">
<input type="hidden" name="lang" value="en">
<input type="text" name="q" value="">
<input type="submit" value="Search">
</form>''')

POST = page('Post', '''<form action="/search" method="post"><input type="text" name="q">
<input type="submit"></form><p>WEB ignores POST forms.</p>''')


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.0'

    def answer(self, code, body, ctype='text/html; charset=utf-8', extra=(), enc='utf-8'):
        data = body.encode(enc) if isinstance(body, str) else body
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(data)))
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def go(self, code, where):
        self.answer(code, '<a href="%s">moved</a>' % where, extra=[('Location', where)])

    def do_GET(self):
        u = urllib.parse.urlsplit(self.path)
        p, q = u.path, urllib.parse.parse_qs(u.query)
        print('C64 asks for', self.path[:100], flush=True)
        port = self.server.server_address[1]
        if p == '/':
            self.answer(200, INDEX)
        elif p == '/tags':
            self.answer(200, TAGS)
        elif p == '/utf8':
            self.answer(200, UTF8)
        elif p == '/latin1':
            self.answer(200, LATIN1, 'text/html; charset=iso-8859-1', enc='latin-1')
        elif p == '/long':
            self.answer(200, page('Long', ''.join('<p>Paragraph %d of a very long page, '
                                                    'with some words to fill the line.</p>\n' % i
                                                    for i in range(3000))))
        elif p == '/links':
            self.answer(200, links_page())
        elif p == '/target':
            self.answer(200, page('Target', '<h1>Target %s</h1><p>pad: %d characters</p>'
                                  % (q.get('n', ['?'])[0], len(q.get('pad', [''])[0]))))
        elif p == '/rel/a/b.html':
            self.answer(200, REL % port)
        elif p in ('/rel/x.html', '/rel/a/y.html', '/rel/a/z.html', '/abs', '/proto'):
            self.answer(200, page('Arrived', '<h1>Arrived at %s</h1><p>%s</p>' % (p, u.query)))
        elif p == '/redirect':
            self.go(302, '/tags')
        elif p == '/loop':
            self.go(301, '/loop')
        elif p == '/https':
            self.go(301, 'https://example.com/')
        elif p == '/missing':
            self.answer(404, page('Not found', '<h1>404</h1><p>No such page here.</p>'))
        elif p == '/text.txt':
            self.answer(200, 'Plain text\nA line that is much longer than thirty-five characters '
                             'and wraps.\n\tTab\n<b>not a tag</b> &amp; not an entity\n',
                        'text/plain')
        elif p == '/file.prg':
            self.answer(200, bytes([1, 8] + list(range(200))), 'application/octet-stream')
        elif p == '/form':
            self.answer(200, FORM)
        elif p == '/search':
            self.answer(200, page('Results', '<h1>You searched</h1><p>q=[%s] lang=[%s]</p>'
                                  % (q.get('q', [''])[0], q.get('lang', [''])[0])))
        elif p == '/post':
            self.answer(200, POST)
        elif p == '/slow':
            time.sleep(60)
            self.answer(200, page('Slow', '<p>finally</p>'))
        elif p == '/empty':
            self.answer(200, '')
        else:
            self.answer(404, page('404', '<p>unknown test page</p>'))

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
    print('web test server on port', port, flush=True)
    http.server.ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
