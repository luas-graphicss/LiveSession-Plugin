# LiveSession

[Leia em português](README.pt-BR.md)

LiveSession is a Roblox Studio plugin that runs your game while you are still in edit mode. Instead of pressing Play and waiting for a separate test session, you start a live session and the scripts begin running inside the place you are editing, so you can watch everything work while you keep building.

To do that the plugin hosts the server and client scripts by itself and replaces the services that normally do not work outside of Play, like RunService, MarketplaceService, MessagingService, TeleportService and TextChatService, with compatible versions. It also drives physics and animations, bridges remotes between the server side and the client side and reloads scripts when you change them. A fidelity panel shows how close each part is to the real behavior, and warnings show up in the status panel when something needs attention.

Before a session starts the plugin takes a snapshot of the world, and every change made while the game runs goes into a journal. When you stop, a review screen shows what changed and the world goes back to how it was, keeping only what you decide to keep. It also works with Team Create, using locks so two people do not run sessions on top of each other, and it can be controlled by AI agents through my Roblox Studio MCP.

## How to use

Bring the LiveSession folder into Studio keeping its structure, using Rojo or another sync tool. The folder has the Main script with the module folders next to it. Select the LiveSession folder, right click it and choose Save as Local Plugin. The toolbar gets buttons to start and stop the session, open the status panel and open the session output.

## Development time

LiveSession was built in five days and works in its current state.

## License

GNU General Public License version 3. The full text is in the LICENSE file.
