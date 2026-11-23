# AltGlance

## 0.12.1

- **Shorter profession names in the list** ("Herb 34, Skin 75, FA 23"), so every profession fits; hover over a character for them in full.
- **Lighter on the game:** a change of money, experience, zone, professions or bags now reads only that, not the whole character, and links remembered for items no character holds any more are dropped once per session, so the saved data stops growing.

## 0.12.0

- **Options window:** the new **Options** button in the list (or `/alts options`) gathers AltGlance's settings: the minimap button, the item tooltip counts, how old bank counts are shown, and a button that puts every AltGlance window back in the middle of the screen (if one was dragged off a small screen). It also says who your bank alt is here. With a controller, the D-pad picks a row, A changes it and B closes.
- **Bank counts say how old they are:** the bank can only be read while it is open, so a count from a visit more than a day ago now says so in tooltips: "14 (bags 2, bank 12, 5 days ago)". It can be turned off in Options.
- **Right-click the minimap button** to open the profession planner (left-click still opens the list).

## 0.11.3

- **The profession planner remembers where you were:** it reopens on the character, profession and recipe you were last looking at, scrolled where you left it, even after logging out or switching characters. The button with your character's name still takes you to your own professions. (It still opens on All recipes.)

## 0.11.2

- The profession planner always opens on **All recipes**. The filter button still narrows the list while it is open.

## 0.11.1

- **The scroll bar's handle can be dragged**, and the mouse wheel scrolls over the bar too, not only over the list.
- **Controller in the planner:** while it is open, D-pad up and down pick a recipe (the list scrolls along), left and right change character and profession, **X** adds to the plan, **Y** crafts, **B** closes. A line at the bottom says so when you play with a controller. With only the list open, the D-pad scrolls it.
- **Borrowed controller buttons are handed back the moment a fight starts**, so your D-pad and face buttons always do their usual jobs in combat, even with an AltGlance window open. They are borrowed again once the fight is over.

## 0.11.0

- **Fits any screen and text size.** The list, the profession planner and the Send materials panel now keep their layout whatever text size you play with: with bigger text the whole window is drawn bigger, so text never runs into its neighbours, and a window that would not fit your screen (a handheld's, say) is shrunk to fit.
- **Scroll bars** on the character list and the planner's recipe list, with up and down buttons you can press with a controller's cursor; click above or below the bar's handle to jump a page. Only shown when the list is longer than the window.
- **Send materials says why nobody is offered**, instead of just "No alt to send to yet": your other characters are on the other faction or another realm, or AltGlance still needs to learn a name (log in to them once more), or no other character is recorded yet.

## 0.10.4

- **Controller:** the B button now closes the AltGlance list and the profession planner, like the X and Escape. While one is open, B closes it; once it is closed, B does whatever you have it set to again. (The Send materials panel still closes with the mailbox.)

## 0.10.3

- Profession planner: a button beside the **<** and **>** arrows, named after the character you are playing ("Bizzall"), goes straight back to their professions after browsing your other characters. It is dimmed while you are already there.

## 0.10.2

- The **Record** button is now always there. Once your professions are recorded it reads **Update my Cooking** (or whichever of your professions is shown): press it to read that profession again, so recipes learned since show up. Its tooltip says when it was last read. On another character's profession it is greyed and says who to log in to.

## 0.10.1

- **Record** now records one profession per press, and then shows the next one ("Record my First Aid"). The game lets an addon open a profession window only straight after a click, so opening the second one by itself was blocked ("Interface action failed because of an AddOn").

## 0.10.0

- **Record my professions:** a button at the top of the profession planner, shown while the character you are playing has a profession with recipes that is not recorded yet. Press it and AltGlance opens each of those profession windows in turn, records the recipes and closes it again: no need to open them yourself. Gathering professions without recipes (Herbalism, Skinning, Fishing) are skipped, and one found to have nothing to record is not offered again. If the game will not open a window for an addon, AltGlance says so, and opening it once yourself still works.

## 0.9.2

- **Fix, take two:** whether two characters are on the same realm now goes by the realm's server number, which every character carries, not by the realm's name. On the affected character the game gave a different name, or none, so 0.9.1 was not enough. The bank alt is found the same way. 0.9.1 also saved the character's last name as its realm on that character (Forever gives the last name where the game normally gives the realm); that is no longer read, and is cleared.

## 0.9.1

- **Fix: Send materials said "No alt to send to yet" on some characters.** Forever's game sometimes gives an empty realm name, so that character looked as if it were on a different realm from all your alts, and the bank alt was not found. AltGlance now never saves an empty realm name, tries the game's other ways of reading it, and otherwise works out the realm from your other characters on the same realm server. The profession planner's "who can mail it" uses the same fix.

## 0.9.0

- **Send materials keeps what your quests need.** Cloth, ore, herbs and other materials a quest in your log asks you to collect ("Linen Cloth: 4/6") now stay in your bags instead of being mailed to your bank alt. Enough stacks are kept to cover what the quest wants, and the rest still go. The panel says what it kept ("Kept for quests: Linen Cloth 10"). Once the quest is handed in, they are sent as usual.

## 0.8.2

- Profession planner tidied up: **Craft** and **Add to plan** are now two large buttons along the bottom (Craft no longer overlaps Most), with the reason Craft can't be pressed shown just above it. Each material's line reads "Shannbizz has 2 - Alts: Bizzall 8, Shannizz 8 +7 on the other faction": the characters who can mail it come first, the other faction is summed up. The window is a little taller, showing more recipes and materials.

## 0.8.1

- **Craft** in the profession planner: makes the chosen recipe, the number set under Make (as many as the materials in your bags allow). It works on the character who knows the recipe; if their profession window is closed, the button opens it, then press Craft. Open each profession window once after updating so AltGlance learns how to craft each recipe.

## 0.8.0

- **Profession planner** (`/alts prof`, or the new **Professions** button in the list). Open a profession window once on each character and AltGlance records their recipes. Then, for any of your characters' professions:
  - every recipe they know, green when they can make it now with what they hold, yellow with a * when they can with materials from your other characters, and how many;
  - for the chosen recipe: each material, how many it takes, how many the crafter has, which of your characters holds the rest (a character on the other faction is marked, as mail cannot cross factions), and what is still to buy or gather;
  - Make: choose how many, or Most for as many as your characters' materials allow.
- **Add to plan**, then **Planned for crafting** on the Send materials panel: at the mailbox on your other characters, the materials the plan needs are sent to the crafter (the panel switches to them and says so). Materials the crafter already has enough of stay put. **Clear plan** in the planner empties it.

## 0.7.2

- Fixed: the first time a mailbox was opened, the Send materials panel could appear at the far side of the screen instead of beside it. Blizzard puts the mail window in place a moment after it opens; the panel now follows its edge.

## 0.7.1

- **Other trade goods** on the Send materials panel (off until you turn it on): every crafting material no other kind covers, such as parts, elemental reagents, meat and spices for cooking, and enchanting materials. Gems, fish and the rest stay with their own kinds.
- **Your own mail to the bank alt:** put items on the Send Mail page yourself, then press Send on the panel, and that mail goes to your bank alt as it is (then any materials follow). Handy in gamepad mode, where the bank alt's name is not filled in. A mail with money or C.O.D. on it is left for the mailbox's own Send button.

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
