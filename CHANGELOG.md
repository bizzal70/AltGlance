# AltGlance

## 0.6.0

- **Send materials:** opening a mailbox shows a panel beside it that mails your ore and stone, herbs, leather and cloth to another of your characters on the same realm and faction, 12 stacks a mail, one after another until all are sent. Pick who with the < and > buttons, turn each kind on or off, then press Send. Soulbound items, food and everything else stay in your bags. Made to be easy with a gamepad or touchscreen.
- **Gear to disenchant:** a fifth kind on that panel, off until you turn it on: green, blue and purple weapons and armour that are not soulbound yet, for a bank alt who disenchants.
- **Bank alt:** mark one character as your bank alt (the button on that panel, or `/alts bank <name>`), and their name is filled in on the Send Mail page whenever its To box is empty, so you need not type it. `/alts bank off` clears it.

## 0.5.0

- **On your characters:** hover over any item and its tooltip lists how many each of your characters has, in their bags and in their bank, with a total. Bags are counted as you play each character; a bank is counted when that character opens it.
- `/alts find <item>` lists which characters hold an item, by any part of its name: `/alts find linen`.
- `/alts tooltip` turns the tooltip lines off or on.

## 0.4.0

- Sort by faction: the crests now have their own **Faction** column. Click its heading to list the Alliance first, again for the Horde first; within each faction the highest level comes first.

## 0.3.0

- Horde or Alliance at a glance: each character has their faction's crest before their name, and their row is faintly tinted red (Horde) or blue (Alliance). The tooltip shows the faction with its crest, and the footer shows how many characters and how much gold each faction has, since gold cannot cross between them.

## 0.2.1

- Fixed: gold, experience, rested, bag space and professions showed 0 for every character. AltGlance read the character one last time as you logged out, when the game has already cleared those to 0. It no longer does, and reads the character again a few seconds after logging in. Each character's figures come back the next time you play them.

## 0.2.0

- **AltBoard is now AltGlance.** Another Forever addon on CurseForge, Allemano AltBoard, installs into the same AltBoard folder and uses `/altboard`, so the two could not be installed side by side. `/alts` still opens it (`/altglance` too), the folder is `AltGlance`, and the saved data is `AltGlanceDB`. Nothing else changes. Entries below this one use the old name.

## 0.1.1

- Fixed: the minimap button could keep following the mouse after a drag, and then move together with another addon's button sitting on top of it. It now stops the moment you let go.

## 0.1.0

- First version.
