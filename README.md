# Karmabook

Private notes on players for WoW: Forever. Add someone once, and the next time they talk in guild chat, whisper you, or walk past, you get a sound and a banner with your note on what they did.

Nothing is sent to anyone unless you press **Share with guild** on a page. The addon never messages players, and only lists people you add yourself. The Notes tab holds plain notes that aren't about anyone.

## Adding someone

- Right-click their name in chat or on a portrait and pick **Add to Karmabook**
- Target them and type `/karmabook add`
- Type `/karmabook add First Surname: took my herb and laughed`

## Commands

| Command | What it does |
|---|---|
| `/karmabook` | Open your notebook |
| `/karmabook add` | Add your target, or type a name in the form |
| `/karmabook add First Surname: note` | Add a player or a new note |
| `/karmabook find First Surname` | Print a player's notes |
| `/karmabook options` | Open settings |
| `/karmabook status` | Show whether chat is hidden from addons right now |
| `/karmabook debug` | Print each chat sender's raw name, for testing |

## Limits

- The game hides chat from addons in dungeons, raids, and PvP matches, so chat alerts can't fire there.
- You only hear channels you've joined, and officer chat only if your rank can read it.
- Same-faction players only have a nameplate if friendly nameplates are on. Otherwise a nearby alert needs you to target or mouse over them.
