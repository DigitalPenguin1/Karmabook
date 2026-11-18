# Changelog

## 0.3.1

- Players in your group no longer alert for party chat or showing up nearby, whatever their label. Before, only Good Players went quiet

## 0.3.0

- Right-clicking a name in the book opens a menu with Whisper and Edit page. Guild tab names get Whisper too
- A dot by each name shows if they're online: green online, red offline, faint unknown. Guild roster, friends list, group, and recent sightings update it on their own. Clicking a name runs a quiet /who for anyone else
- Pages know a player's faction: from their race, from seeing them, or from the new Faction picker on the form (needed for Skyborne). The other faction's dots stay faint, since /who can't see them
- Alliance and Horde crests next to names in the list and on the page, once the faction is known
- Check online under the list runs /who on the next unchecked name each press, and right-click has Check online (/who) for one name
- Pages show the player's level, picked up from /who, the guild roster, and seeing them. A /who also fills in missing race and class
- Adding someone from their target or portrait saves their level, and fills in race, class, and faction on the form. Adding from a chat name runs a /who on Save to get the level

## 0.2.1

- The addon list shows the yin-yang icon too, the same as the minimap button
- Removed the old heart icon file, which nothing used anymore
- The yin-yang on the heart in the CurseForge art now sits centered under the mouth
- New CurseForge logo with the yin-yang on the heart

## 0.2.0

- Good Players in your group no longer alert: no group-join alert, no chat or nearby alerts while they're grouped with you, and no alert when they invite you
- Tearing out a page you shared takes it back from guildmates' Guild tabs. The delete prompt says so
- Unshares are sent again every 15 minutes for two weeks, so guildmates who were offline still get them
- Renaming a shared page takes back the old name and shares the page again under the new one
- Changing the label or note on a shared page reminds you that the guild still has the old version
- Help explains the colored ! on names in chat
- New yin-yang minimap button, and a yin-yang on the heart in the CurseForge art

## 0.1.0

First version, for WoW: Forever.

- Private list of players with dated notes, added by you and nobody else
- Sound, banner, and chat alert showing your note when a listed player talks in guild, officer, whisper, say, yell, emote, party, raid, instance, or any channel you've joined
- Same alert when they're nearby, invite you, or join your group
- Notes in tooltips and a marker on listed names in chat
- Right-click "Add to Karmabook" on names in chat and on portraits
- Grudge, Kill on Sight, Caution, and Good Player labels
- Divider tabs for All, Grudges, Kill on Sight, Caution, Good, and Guild
- Share sends a page's newest note: Guild goes quietly to online guildmates with the addon, where it waits in the Guild tab and can't alert until they add it; Say posts it in chat for everyone nearby
- Editable location on the add and edit forms
- Back button on the Help page that returns to your page without closing the book
- About button at the top of the settings page
- "Share with guild" checkbox on the add and edit form, off each time it opens
- Sync page in settings (or `/karmabook sync`) listing every page shared, received, added, dismissed, or ignored and why. Check guild shows which online guildmates have Karmabook
- Notes tab for plain notes that aren't about a player
- Heart icon for the minimap button and addon list
