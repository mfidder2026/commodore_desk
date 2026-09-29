"""Tiny POP3 + SMTP test server for the Commodore Desk 64 EMAIL client.

Plain text only (no TLS), one test account, a fixed mailbox with messages
that exercise the client: plain text, quoted-printable UTF-8 with an
encoded-word subject, nested multipart with HTML and an attachment, base64
text, HTML-only and a long paragraph for word wrap. Messages sent via SMTP
are printed and appended to the POP3 mailbox.

Run it where VICE can reach it (for example inside WSL, which shares the
virtual switch with VICE's RR-Net):
    python3 tools/mailtest_server.py [pop3-port] [smtp-port]
Test account: test@c64.test / Secret99
"""
import base64
import socket
import sys
import threading

USER, PASS = 'test@c64.test', 'Secret99'
POP_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 1110
SMTP_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 1587

B64_TEXT = base64.encodebytes(
    'This body is base64 encoded.\r\nSecond line: café and naïve.\r\n'.encode()).decode()

MAILBOX = [
    'From: Alice Example <alice@example.org>\r\nTo: test@c64.test\r\n'
    'Subject: Hello from Alice\r\nDate: Sun, 27 Sep 2026 10:00:00 +0200\r\n\r\n'
    'Hi there!\r\n\r\nThis is a plain text message.\r\n..and this line started with a dot.\r\n\r\nAlice\r\n',

    'From: =?UTF-8?Q?Bj=C3=B6rn_M=C3=BCller?= <bjorn@example.de>\r\n'
    'Subject: =?UTF-8?Q?Gr=C3=BC=C3=9Fe_aus?= =?UTF-8?B?S8O2bG4=?=\r\n'
    'Date: Sat, 26 Sep 2026 18:30:00 +0200\r\nMIME-Version: 1.0\r\n'
    'Content-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: quoted-printable\r\n\r\n'
    'Caf=C3=A9 cr=C3=A8me br=C3=BBl=C3=A9e =E2=80=93 =E2=80=9Cquoted=E2=80=9D.\r\n'
    'A soft line break joins this =\r\nsentence together.\r\n',

    'From: "Newsletter" <news@example.com>\r\nSubject: Weekly news\r\n'
    'Date: Fri, 25 Sep 2026 08:00:00 +0200\r\nMIME-Version: 1.0\r\n'
    'Content-Type: multipart/mixed; boundary="MIX"\r\n\r\n'
    'This is a multi-part message in MIME format.\r\n'
    '--MIX\r\nContent-Type: multipart/alternative;\r\n boundary="ALT"\r\n\r\n'
    '--ALT\r\nContent-Type: text/plain; charset=us-ascii\r\n\r\n'
    'Plain part of the newsletter.\r\nIt should be shown, not the HTML.\r\n'
    '--ALT\r\nContent-Type: text/html\r\n\r\n<p>HTML <b>part</b></p>\r\n--ALT--\r\n'
    '--MIX\r\nContent-Type: application/pdf; name="x.pdf"\r\nContent-Transfer-Encoding: base64\r\n\r\n'
    + 'JVBERi0xLjQKJcfsj6IKNSAwIG9iago8PC9MZW5ndGggNiAwIFI+PgpzdHJlYW0K\r\n' * 40 +
    '--MIX--\r\n',

    'From: bob@example.net\r\nSubject: Base64 body\r\nDate: Thu, 24 Sep 2026 12:00:00 +0200\r\n'
    'MIME-Version: 1.0\r\nContent-Type: text/plain; charset=utf-8\r\n'
    'Content-Transfer-Encoding: base64\r\n\r\n' + B64_TEXT.replace('\n', '\r\n'),

    'From: Shop <shop@example.com>\r\nSubject: Your order\r\nDate: Wed, 23 Sep 2026 09:15:00 +0200\r\n'
    'MIME-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n'
    '<html><head><style>p { color: red; }</style></head><body>\r\n'
    '<h1>Thank you!</h1><p>Your order &amp; payment were received.</p>\r\n'
    '<p>Total:&nbsp;12 EUR</p><br>Bye</body></html>\r\n',

    'From: Carol <carol@example.org>\r\nSubject: A long paragraph\r\nDate: Tue, 22 Sep 2026 20:00:00 +0200\r\n\r\n'
    + 'The quick brown fox jumps over the lazy dog, again and again, ' * 12 + '\r\n',
]


def pop3(conn):
    f = conn.makefile('rb')
    def say(s):
        conn.sendall((s + '\r\n').encode())
    say('+OK test POP3 ready')
    user = None
    authed = False
    while True:
        line = f.readline()
        if not line:
            return
        cmd = line.decode(errors='replace').strip()
        print('POP3 <', cmd if not cmd.upper().startswith('PASS') else 'PASS ****')
        up = cmd.upper()
        if up.startswith('USER '):
            user = cmd[5:]
            say('+OK')
        elif up.startswith('PASS '):
            if user == USER and cmd[5:] == PASS:
                authed = True
                say('+OK logged in')
            else:
                say('-ERR [AUTH] Authentication failed.')
        elif up == 'QUIT':
            say('+OK bye')
            return
        elif not authed:
            say('-ERR not logged in')
        elif up == 'STAT':
            say('+OK %d %d' % (len(MAILBOX), sum(len(m) for m in MAILBOX)))
        elif up.startswith('TOP ') or up.startswith('RETR '):
            parts = cmd.split()
            n = int(parts[1])
            if not 1 <= n <= len(MAILBOX):
                say('-ERR no such message')
                continue
            msg = MAILBOX[n - 1]
            if up.startswith('TOP'):
                head, _, body = msg.partition('\r\n\r\n')
                keep = int(parts[2])
                msg = head + '\r\n\r\n' + '\r\n'.join(body.split('\r\n')[:keep])
            say('+OK')
            out = []
            for l in msg.split('\r\n'):
                out.append('.' + l if l.startswith('.') else l)
            conn.sendall(('\r\n'.join(out).rstrip('\r\n') + '\r\n.\r\n').encode())
        else:
            say('-ERR unknown command')


def smtp(conn):
    f = conn.makefile('rb')
    def say(s):
        conn.sendall((s + '\r\n').encode())
    say('220 test.local ESMTP test')
    authed = False
    while True:
        line = f.readline()
        if not line:
            return
        cmd = line.decode(errors='replace').strip()
        up = cmd.upper()
        print('SMTP <', cmd if not up.startswith('AUTH') else 'AUTH PLAIN ****')
        if up.startswith('EHLO') or up.startswith('HELO'):
            conn.sendall(b'250-test.local\r\n250-AUTH PLAIN LOGIN\r\n250 8BITMIME\r\n')
        elif up.startswith('AUTH PLAIN '):
            raw = base64.b64decode(cmd[11:])
            parts = raw.split(b'\0')
            ok = len(parts) == 3 and parts[1].decode() == USER and parts[2].decode() == PASS
            print('SMTP   auth user=%r ok=%s' % (parts[1] if len(parts) > 1 else b'', ok))
            say('235 2.7.0 Authentication successful' if ok else '535 5.7.8 Authentication failed')
            authed = ok
        elif up.startswith('MAIL FROM:'):
            say('250 2.1.0 Ok' if authed else '530 5.7.0 Authentication required')
        elif up.startswith('RCPT TO:'):
            say('250 2.1.5 Ok')
        elif up == 'DATA':
            say('354 End data with <CR><LF>.<CR><LF>')
            data = []
            while True:
                l = f.readline().decode(errors='replace')
                if l in ('.\r\n', '.\n'):
                    break
                data.append(l[1:] if l.startswith('..') else l)
            msg = ''.join(data)
            print('----- received message -----\n' + msg + '----------------------------')
            MAILBOX.append(msg.replace('\r\n', '\n').replace('\n', '\r\n'))
            say('250 2.0.0 Ok: queued')
        elif up == 'QUIT':
            say('221 2.0.0 Bye')
            return
        else:
            say('502 5.5.2 Error: command not recognized')


def serve(port, handler):
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', port))
    s.listen(5)
    while True:
        c, a = s.accept()
        print('connection from', a, 'port', port)
        threading.Thread(target=lambda: (handler(c), c.close()), daemon=True).start()


if __name__ == '__main__':
    threading.Thread(target=serve, args=(POP_PORT, pop3), daemon=True).start()
    print('POP3 on %d, SMTP on %d, user %s' % (POP_PORT, SMTP_PORT, USER))
    sys.stdout.flush()
    serve(SMTP_PORT, smtp)
