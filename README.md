# Karmabook

<p align="center">
  <img src="Art/description-banner.webp" alt="Karmabook: I Will Always Remember You" width="640">
</p>

Private notes on players for WoW: Forever. Add someone once, and the next time they talk in guild chat, whisper you, or walk past, you get a sound and a banner with your note on what they did.

Nothing is sent to anyone unless you pick **Share** on a page: **Guild** sends it quietly to guildmates who have Karmabook, and **Say** posts it in chat for everyone nearby. It never whispers anyone, and only lists people you add yourself. The Notes tab holds plain notes that aren't about anyone.

## Adding someone

- Right-click their name in chat or on a portrait and pick **Add to Karmabook**
- Target them and type `/karmabook add`
- Type `/karmabook add First Surname: took my herb and laughed`

Each page gets a label (Grudge, Kill on Sight, Caution, or Good Player), race and class, where you saw them, and dated notes. The tabs on the right of the book show one label at a time.

## Sharing with your guild

- Pick **Share > Guild** on a page, or tick **Share with guild** on the add form before you save. Only that page's newest note is sent, and only to guildmates who are online and have Karmabook.
- Pages guildmates share wait in your **Guild** tab. They never alert you until you pick **Add to my book**. Turn off **Receive shared pages** in settings to stop getting them.
- You can't share a page about someone in your guild.
- The **Sync** page in settings (`/karmabook sync`) lists every page you shared or got, anything ignored and why. **Check guild** shows which online guildmates have Karmabook, so you know a share will reach someone.

## Commands

| Command | What it does |
|---|---|
| `/karmabook` or `/kbook` | Open your notebook |
| `/karmabook add` | Add your target, or type a name in the form |
| `/karmabook add First Surname: note` | Add a player or a new note |
| `/karmabook find First Surname` | Print a player's notes |
| `/karmabook options` | Open settings |
| `/karmabook sync` | Open the Sync log: everything shared and received, and who in your guild has Karmabook |
| `/karmabook status` | Show whether chat is hidden from addons right now |
| `/karmabook debug` | Print each chat sender's raw name, for testing |

## Installing

Copy the `Karmabook` folder into `World of Warcraft/_forever_/Interface/AddOns/`, then restart the game.

## Limits

- The game hides chat from addons in dungeons, raids, and PvP matches, so chat alerts can't fire there.
- You only hear channels you've joined, and officer chat only if your rank can read it.
- Same-faction players only have a nameplate if friendly nameplates are on. Otherwise a nearby alert needs you to target or mouse over them.

## Support

Found a bug or have an idea? [Open an issue](https://github.com/DigitalPenguin1/Karmabook/issues). If you enjoy Karmabook, you can [buy me a coffee](https://buymeacoffee.com/relyk22).

Made by Relyk Rageroot.
