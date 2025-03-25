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

'lua-toml' is licensed under [MIT](https://opensource.org/licenses/MIT).

```txt
Copyright (c) 2017 Jonathan Stoler

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
