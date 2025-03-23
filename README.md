# ToasterGen Spin

ToasterGen Spin is a commissioned roulette game for an in-game ComputerCraft casino. It features a dynamic, animated roulette board along with supporting utilities for archiving and compression, all written in Lua.

## Features

- **Dynamic Roulette Board**:
  Draws a complete roulette ring with animated ball movement and decorative elements (see [`src/ring.lua`](src/ring.lua)).

- **Modular Design**:
  Organized into multiple modules such as [`spin.lua`](spin.lua) for the main game logic and [`carpet.lua`](src/carpet.lua) for auxiliary features.

## Usage

- Run the game by executing `spin.lua` on your ComputerCraft setup.
- Customize behaviour and appearance via the configuration file.
- Explore and test individual components in the [`tests`](tests/) directory.

## Licence

Distributed under the GNU Lesser General Public Licence. See [LICENCE](LICENCE) for details.

Enjoy your spin and happy coding!
