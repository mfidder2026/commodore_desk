# INET – plan en besluiten

Aanvulling op `C64_Network_Stack_Technisch_Bouwplan.md`, met de productkeuzes van 26-09-2026.

## Menu

In de menubalk komt het uitklapmenu **INET** met deze items:

| Item | Status |
|---|---|
| **NETWORK** | klaar |
| **PING** | klaar (RR-Net) |
| **CHAT** | klaar (RR-Net, plain HTTP) |
| **EMAIL** | nog niet beschikbaar (grijs) |

- **NETWORK** toont de status van de netwerkhardware.
- NETWORK is ook de *enige* plek voor alle instellingen:
  - IP, MASK, GATEWAY, DNS;
  - de CHAT-server: HOST, PORT, API KEY, MODEL.
- Opslag gaat naar `NET.CFG`. In het geheugen staat de config vast op `$C400`, zodat elke INET-overlay hem deelt.
- FTP en RSS vervallen.
- Er komt **geen proxy of relay** op de PC.
- Er komt geen TLS: alleen plain HTTP binnen het eigen netwerk.

## CHAT – OpenAI-compatibele client

CHAT werkt met Ollama en met andere OpenAI-compatibele servers:

- Het modellenlijstje komt van `GET http://HOST:PORT/v1/models`. De gebruiker kiest daaruit het model, en dat wordt `MODEL` in NET.CFG.
- Een vraag gaat naar `POST http://HOST:PORT/v1/chat/completions`, met:
  - `Authorization: Bearer <API KEY>`, alleen als die is ingevuld;
  - de body `{"model":"…","messages":[…],"stream":true}`.
- Het antwoord wordt gestreamd. De C64 leest per stukje alleen `"content"` uit en zet het direct op het scherm. Het complete antwoord hoeft dus nooit in het geheugen.
- Tekst wordt vertaald naar het C64-schermtekenset:
  - UTF-8-tekens worden vervangen;
  - letters worden kleine letters bij het verzenden, want modelnamen zijn hoofdlettergevoelig.

Beperking van het toetsenbord: de invoer kent nog geen SHIFT-letters. Een API-key met hoofdletters kan dus nog niet getypt worden. Voor Ollama is dat geen probleem, omdat die geen key nodig heeft.

Over "de AI mijn e-mail laten lezen": dat kan alleen als de *server* die mogelijkheid heeft, bijvoorbeeld via tools of MCP in de chatserver. De C64 stuurt alleen tekst heen en weer.

## EMAIL

EMAIL wordt een "retro mailbox". Er wordt geen mail gedownload via POP/IMAP en er is geen versleuteling. Het ontwerp moet nog onderzocht worden.

## Bouwvolgorde

Zie het bouwplan.

1. Ethernet TX/RX (CS8900).
2. ARP.
3. IP/ICMP, met **PING** als eerste app.
4. UDP/DNS.
5. TCP.
6. HTTP-client.
7. **CHAT**.

Op een Ultimate doet de Ultimate zelf TCP (via UCI-sockets). Daar kan CHAT dus eerder werken dan op de RR-Net.
