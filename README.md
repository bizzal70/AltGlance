# AltGlance

All your characters at a glance: level, gold, where they are, rested experience, professions and bag space. An addon for World of Warcraft: Forever (client 1.60.x).

Formerly called AltBoard. It was renamed in 0.2.0 because another Forever addon, Allemano AltBoard, already uses that name and folder on CurseForge. `/alts` still opens it.

## What it does

AltGlance keeps a line on every character on your account and shows them all in one window, from whichever character you are playing:

| Column | |
|---|---|
| Faction | Their faction's crest (Horde or Alliance). The row is faintly tinted red for the Horde, blue for the Alliance |
| Character | Their name, in their class colour |
| Realm | What kind of realm they are on: RP PvP, PvP, RP or Normal, in its own colour (read from the realm's name; blank if the name does not say) |
| Level | |
| Gold | With a total across all characters at the bottom, and each faction's own total (gold cannot cross between them) |
| Last seen in | The zone they were in |
| Rested | Rested experience, as a share of a level |
| Professions | With skill levels |
| Bank alt | A tick box: tick the character whose name the mailbox fills in (one per realm and faction), untick to clear |
| Bags free | Free slots out of total |
| Played | How long since you last played them |

Click a column heading to sort by it; click again to reverse. Sorting by **Faction** puts all your Alliance characters together and all your Horde ones together, highest level first within each. Hover a row for more detail.

## Using it

Click the AltGlance button on the minimap, or type `/alts` (or `/altglance`).

A character appears in the list once you have logged in to them with AltGlance enabled, and their line is brought up to date each time you play them. Characters you have not played since installing it are not listed yet.

| Command | What it does |
|---|---|
| `/alts` | Open the list |
| `/alts find <item>` | Which of your characters has an item, in bags or bank: `/alts find linen` |
| `/alts prof` | The profession planner (also the **Professions** button in the list, or right-click the minimap button) |
| `/alts options` | The Options window (also the **Options** button in the list) |
| `/alts tooltip` | Item tooltips showing each character's count, on or off |
| `/alts bank <name>` | Your bank alt, whose name the mailbox fills in (`/alts bank off` to clear) |
| `/alts forget <name>` | Remove a character you no longer have |
| `/alts button` | Show or hide the minimap button |

You can also remove a character with the small **x** at the end of their row; it takes two presses.

## On your characters

Hover over any item, in your bags, at a vendor, in a link in chat, anywhere, and its tooltip shows how many each of your characters has:

| On your characters: | |
|---|---|
| Mirabel | 26 |
| Tolan | 14 (bags 2, bank 12) |
| Total | 40 |

Each character is shown with their faction's crest, in their class colour, most first. To search instead, type `/alts find` and part of the item's name.

- **Bags** are counted whenever they change while you play a character.
- **The bank** can only be read while it is open, so each character's bank is counted the first time they open it with AltGlance 0.5.0 or later, and kept up to date each time after.
- Mail and items you are wearing are not counted.

## Profession planner

On each character, press **Record my professions** at the top of the planner (or open a profession window yourself once: Tailoring, Enchanting, Alchemy...), and AltGlance records the recipes they know. Once everything is recorded the button reads **Update my ...**: press it to read the profession shown again, for recipes learned since. Each press opens one profession window, reads it and closes it, since the game shows recipes only there. Then type `/alts prof`, or press **Professions** in the list:

- Step through your characters' professions with **<** and **>**; the button beside them, named after the character you are playing, goes back to theirs. The list shows every recipe they know: **green** when they can make it now with what they hold, **yellow \*** when they can with materials from your other characters, with how many.
- Choose a recipe to see each material it takes, how many the crafter has, and which of your characters holds the rest. Characters on the other faction are marked, as mail cannot cross factions. Anything still to buy or gather is listed underneath. Hover over a material for its tooltip.
- Choose how many to make (**Most** sets as many as your characters' materials allow), then **Craft** to make them (on the crafter, with their profession window open; if it is closed the button opens it), or **Add to plan** to gather the materials first.
- Log in to a character holding planned materials and open a mailbox: the Send materials panel is set to send to the crafter, and **Planned for crafting** mails what the plan still needs. Materials the crafter already has enough of stay put.

The filter at the top right shows all recipes, those you can make now, or those you can make with your alts' help. Counts come from each character's bags, and their bank as of their last visit to it.

## Send materials to an alt

Open any mailbox and a **Send materials** panel appears beside it:

1. **To:** step through your other characters on the same realm and faction with **<** and **>** (mail cannot cross factions). It starts on your bank alt, or whoever you sent to last.
2. **What:** turn each kind on or off: **Planned for crafting** (the profession planner's plan, sent to its crafter), **Ore & stone**, **Herbs**, **Leather**, **Cloth**, **Gems**, **Recipes & patterns** (not soulbound), **Fishing catch** (raw fish, other catches and clams), **Other trade goods** (every other crafting material), and **Gear to disenchant** (green, blue and purple weapons and armour that are not soulbound yet). The last five are off until you turn them on.
3. **Send** (on the mailbox's Send Mail page): everything chosen is mailed, 12 stacks a mail (the game's limit), one mail after another until all of it is on its way. Chat says what went. You pay the usual postage.

Materials a quest in your log asks you to collect stay in your bags too: enough stacks to cover the quest are kept, and the panel says which ("Kept for quests: Linen Cloth 10"). Soulbound items, food and everything else stay in your bags. You can also put any items on the Send Mail page yourself and press the panel's Send: that mail goes to your bank alt as it is (not one with money or C.O.D. on it, which is for the mailbox's own Send). Every button is big enough to tap, and works with a gamepad. Mail only ever goes to a character's **full name** (first and last, as Shannizz Wolfbane): first names are not unique in Forever. A character is offered once AltGlance knows their full name, which it learns the next time you log in to them, and right before each mail it checks again that it is one of yours on the same realm and faction.

### Your bank alt

Tick their box in the list's **Bank alt** column, press **Make this my bank alt** on the mailbox panel, or type `/alts bank <name>`, and that character's name is filled in on the mailbox's **Send Mail** page whenever its To box is empty, so you never have to type it. It is filled in again after each mail you send. One bank alt per realm and faction; `/alts bank off` clears it. A name you have typed yourself is never replaced. In gamepad mode the game does not allow an addon to type into that box, so there the name is not filled in: use Send on the Send materials panel, which mails straight to your bank alt.

## Good to know

- **Rested experience is estimated** for characters you are not playing. AltGlance knows how much they had when you logged out and whether they were in an inn or city, and works out how much has built up since. Estimates are marked with `~`.
- **Nothing is sent anywhere.** The list is saved on your own computer with the game's other saved settings.
- The **Bags free** column counts the bags a character carries, not their bank.

## Controller

With a game controller, the **B** button closes the AltGlance list and the profession planner, like the X and Escape do. In the planner, the D-pad picks a recipe (up/down) and changes profession (left/right), **X** adds to the plan and **Y** crafts; with only the list open, the D-pad scrolls it. When a fight starts every button AltGlance borrowed is handed straight back. While a window is open, B closes it; once it is closed, B goes back to whatever you have it set to. (In combat the game does not let addons change a button, so B goes back to normal when the fight ends.)

## More from this author

Other small addons for World of Warcraft: Forever, all free:

- **[GatherLog](https://www.curseforge.com/wow/addons/gatherlog)** remembers ore, herbs, fishing pools, skinning spots, chests and rares across all your characters, and guides you back to the best spots.
- **[MouseTip](https://www.curseforge.com/wow/addons/mousetip)** shows tooltips at your mouse cursor.
- **[RangeShade](https://www.curseforge.com/wow/addons/rangeshade)** shades action buttons red when your target is out of range.
- **[JunkMate](https://www.curseforge.com/wow/addons/junkmate)** sells junk and repairs at vendors, and warns when your gear is wearing out.
- **[SwiftQuest](https://www.curseforge.com/wow/addons/swiftquest)** accepts quests and hands them in as soon as you talk to the quest giver, without ever choosing a reward for you.
- **[SessionRecap](https://www.curseforge.com/wow/addons/sessionrecap)** keeps a running tally of your play session: gold, experience per hour, quests, gathering and loot.
- **[MacroKit](https://www.curseforge.com/wow/addons/macrokit)** adds ready-made macros for your class and spec, for all nine classes, and never overwrites your own.
- **[ZoomPad](https://www.curseforge.com/wow/addons/zoompad)** puts big + and - buttons on screen that zoom the camera, made for the Steam Deck touchscreen.
- **[GamepadMacros](https://www.curseforge.com/wow/addons/gamepadmacros)** adds ready-made macros for controller and Steam Deck players: heal yourself, use a quest item, save and wear gear, leave a group, emotes.

## Installing

Install it from [CurseForge](https://www.curseforge.com/wow/addons/altglance) with the CurseForge app, or by hand: copy this folder into `World of Warcraft\_forever_\Interface\AddOns\` as `AltGlance`, restart the game, and enable AltGlance on the character select screen.

## Developing

- `tools\Link-Addon.ps1` links this folder into the game's AddOns folder, so edits are live after `/reload`.
- `python tests/run.py` runs the tests (`pip install lupa` once). They run the addon in real Lua 5.1 against a fake of the game's API.
- `tools\Publish.ps1 -Message "..."` runs the tests and pushes to GitHub. GitHub runs the tests again on every push.

## Releasing

`tools\Publish.ps1 -Message "Release x.y.z" -Tag vx.y.z` publishes and tags. The tag makes GitHub package the addon and attach the zip to a GitHub release.

To also upload to CurseForge and Wago, two things are needed once:

1. Create the project on each site, then add its ID to `AltGlance.toc`:
   `## X-Curse-Project-ID: 123456` and `## X-Wago-ID: abc123`.
2. Create an upload token on each site and add it to this repository's secrets (Settings, Secrets and variables, Actions) as `CF_API_KEY` and `WAGO_API_TOKEN`.

Before each release: raise `## Version:` in `AltGlance.toc` and add the version to `CHANGELOG.md`.

## Licence

MIT. See `LICENSE`.
