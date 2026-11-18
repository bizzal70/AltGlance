# AltGlance

## 0.7.0

- **Fishing catch** on the Send materials panel (off until you turn it on): raw fish, the other catches such as Oily Blackmouth, Firefin Snapper, Stonescale Eel and Deviate Fish, and clams and clam meat. Meat from hunting stays behind.

## 0.6.9

- More gamepad-mode fixes at the mailbox: AltGlance no longer hooks into Blizzard's Send Mail page or ties its panel to the mail window (both could make the game block the mailbox's gamepad steps, also when closing it). The Send materials panel now has a close (x) button and always hides when the mailbox closes.

## 0.6.8

- Fixed: in gamepad mode, "Interface action failed because of an AddOn" and "AltGlance has been blocked" at the mailbox. The cause was AltGlance typing the bank alt's name into the Send Mail To box, which the game does not allow in gamepad mode. There it no longer fills the box; the Send materials panel's Send still mails straight to your bank alt. With mouse and keyboard the name is filled in as before.

## 0.6.7

- Fixed: in gamepad mode the mailbox could bring up "Interface action failed because of an AddOn" and "AltGlance has been blocked from an action only available to the Blizzard UI", even without pressing Send. The Send materials panel was part of the mail window, so Blizzard's gamepad navigation of that window ran into it; it is now a window of its own beside the mailbox.

## 0.6.6

- Fixed: pressing Send on the Send materials panel brought up "AltGlance has been blocked from an action only available to the Blizzard UI" (the mail still went). AltGlance no longer switches the mailbox to the Send Mail page itself; if you are on the Inbox, it asks you to open Send Mail first.

## 0.6.5

- Fixed: Gems on the Send materials panel did not pick up Malachite, Tigerseye or Shadowgem. Forever files gems under trade goods, Other, together with all sorts of reagents, so they are now known by item: the original game's gems and pearls.

## 0.6.4

- Two more kinds on the Send materials panel, both off until you turn them on: **Gems** (Malachite, Tigerseye, Shadowgem and the like) and **Recipes & patterns** (ones not yet soulbound).

## 0.6.3

- A **Bank alt** column in the list: tick a character to make them the bank alt for their realm and faction (the one ticked before is unticked), untick to clear. Works from any character, whenever you change your mind; the mailbox panel and `/alts bank` still work too.

## 0.6.2

- The Send materials panel is tidier and easier to read: wider, so full names fit; headings for Send to and What to send; a coloured box and On or Off on each kind; a short Make this my bank alt button (it turned green as Your bank alt); and the stacks and mails to send on their own line above a larger Send button, no longer hidden behind the last row.

## 0.6.1

- **Full names.** Forever characters have a first and a last name, and first names are not unique, so AltGlance now records each character's full name (as Shannizz Wolfbane) and shows it in the list and tooltips. It is learned the next time you log in to each character.
- **Safer mail.** Send materials and the bank alt now use full names only: a character appears on the panel once their full name is known. Right before each mail goes, AltGlance checks again that it is one of your characters on the same realm and faction, and sends nothing otherwise.

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
