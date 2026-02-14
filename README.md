![Alt text](https://media.forgecdn.net/attachments/1533/21/prettychat-logo-png.png "Logo")

# Pretty Chat

**Pretty Chat** is the ultimate World of Warcraft addon designed to transform your in-game chat into a stunning and visually captivating experience. Say goodbye to the bland and mundane chat interface, and say hello to a world of vibrant colors that will take your communication in Azeroth to the next level. Whether you're a role-player seeking immersion or a casual player looking to add a touch of style to your game, this addon will make your chat interface a work of art. Download Pretty Chat today and embark on a journey to make your in-game conversations as visually appealing as the world of Azeroth itself.

_**Without Pretty Chat**_

![Without Pretty Chat](https://media.forgecdn.net/attachments/738/967/before.png)

_**With Pretty Chat**_

![With Pretty Chat](https://media.forgecdn.net/attachments/738/969/after.png)

### Features include

**Configurable**: Pretty Chat works out of the box with beautiful defaults, and includes a full configuration UI accessible via `/pc` for fine-tuning every format string.

**Colorful Text**: Express yourself like never before with Pretty Chat's support for colored text and emojis. Add a splash of color to your messages during epic battles or lighthearted role-playing sessions.

**Addon Compatibility**: Pretty Chat seamlessly integrates with other popular World of Warcraft addons, ensuring that your chat remains beautiful and functional no matter what other enhancements you use.

### Configuration

Type `/pc` or `/prettychat` in-game to open the settings panel. From there you can:

- **Enable/disable categories** — Toggle entire groups of format strings (Loot, Currency, Money, Reputation, Experience, Honor, Tradeskill, Misc) on or off.
- **Enable/disable individual strings** — Each format string has its own toggle, so you can selectively override only the strings you want. Disabled strings revert to Blizzard defaults.
- **Edit individual strings** — Each format string is shown with raw WoW escape codes so you can tweak colors and labels directly. A preview edit box beneath each input shows the current value.
- **Reset to defaults** — Reset a single category or all categories back to the built-in PrettyChat formatting at any time.

Settings are saved per-character profile via AceDB.

### How it works

Pretty Chat does not do any sort of parsing of chat messages, instead it overrides the format of [GlobalStrings.lua](https://www.townlong-yak.com/framexml/live/Helix/GlobalStrings.lua) and changes the formatting of those strings. Because of this, it should work out of the box for the default Blizzard interface or any sort of UI package such as ElvUI.

### Bug Reports

Please report any issues in the [Issues](https://github.com/tusharsaxena/prettychat/issues) tab, not as a comment!

## Version History

# Changelog

***1.1.0***
- Added full configuration UI (accessible via `/pc` or `/prettychat`)
- Per-string customization with live preview
- Per-category enable/disable toggles
- Reset to defaults (per-category or all at once)
- AceDB profile support for saved settings
- Per-string enable/disable toggles — selectively override individual format strings
- Disabled strings now revert to Blizzard defaults instead of staying overridden
- Improved settings panel layout with spacers and horizontal rules between string sets

***1.0.0***
- Updated the TOC to 120000

***0.0.3***
- Tagging for initial release

***0.0.2***
- Some stuff

***0.0.1***
- Initial release. Yay!
