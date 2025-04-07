# ToasterGen Spin

ToasterGen Spin is a commissioned roulette game for an in-game ComputerCraft casino. It features a dynamic, animated roulette board along with supporting utilities for archiving and compression, all written in Lua.

## Features

- **Dynamic Roulette Board**:
  Draws a complete roulette ring with animated ball movement and decorative elements (see [`src/ring.lua`](src/ring.lua)). The ring is rendered on a ComputerCraft monitor, utilizing functions to draw elements, lines, and the animated ball. The `launchBall` function animates the ball's movement, and the winning number is highlighted with a blinking effect.

- **Interactive Betting Carpet**:
  Provides a user interface for placing bets, rendered on a separate monitor (see [`src/carpet.lua`](src/carpet.lua)). The carpet module defines the layout of betting options and handles touch events to register bets. The `findClickedNumber` function determines which betting option was selected based on the coordinates of the touch event.

- **Server Communication**:
  Communicates with a central server to manage player balances and process payouts (see [`src/modem.lua`](src/modem.lua) and [`stator.lua`](stator.lua)). The `sendWin`, `getBallance`, and `resetBallance` functions in `modem.lua` handle communication with the server, while `stator.lua` on the server side manages player data and processes requests.

- **Player Detection**:
  Detects players in a defined area using a player detector peripheral. The `stator.lua` script uses the `getPlayersInBorders` function to identify players within the designated zone.

- **Chat Integration**:
  Allows players to register and redeem their winnings through in-game chat commands (see [`src/chat.lua`](src/chat.lua)). The `handleChatEvent` function processes chat messages, and the `msgFuncs` table provides functions for sending messages to players.

- **Configuration**:
  Customizable behavior and appearance via TOML configuration files (see [`config.toml`](config.toml) and [`tools/config.lua`](tools/config.lua)). The `config.lua` script provides functions for configuring the game's settings, including peripheral devices, reward multipliers, and server parameters.

- **Modular Design**:
  Organized into multiple modules such as [`spin.lua`](spin.lua) for the main game logic, [`carpet.lua`](src/carpet.lua) for the betting carpet, [`ring.lua`](src/ring.lua) for the roulette wheel, and [`chat.lua`](src/chat.lua) for chat integration.

## System Architecture

The ToasterGen Spin system consists of three main components:

1. **Client**: The roulette table itself with monitors for the betting carpet and roulette wheel
2. **Server**: Manages player data, processes bets, and handles payouts
3. **Player Interaction**: Through chat commands, physical buttons, and monitor touches

### Communication Flow Diagrams

#### Overall System Architecture

```mermaid
graph TB
    Player[Player] -->|Places Bets| Client
    Player -->|Chat Commands| Client
    Client -->|Monitor Display| Player
    Client -->|Chat Messages| Player
    Client -->|Modem Messages| Server
    Server -->|Modem Responses| Client
    Server -->|Database Operations| DB[(Database)]
    Server -->|Player Detection| PlayerDetector[Player Detector]

    subgraph Client Components
        Carpet[Carpet Monitor]
        Ring[Ring Monitor]
        Inventory[Inventory Manager]
        ChatBox[Chat Box]
        ClientModem[Modem]
    end

    subgraph Server Components
        ServerModem[Modem]
        DBManager[Database Manager]
        PlayerTracker[Player Tracker]
        ServerChat[Chat Manager]
    end
```

#### Betting and Payout Sequence

```mermaid
sequenceDiagram
    participant Player
    participant Chat
    participant Client
    participant Server
    participant Database

    Player->>Chat: $register (registers for betting)
    Chat->>Client: Signals player registration
    Client-->>Player: Confirms registration

    Player->>Client: Places physical emerald in inventory
    Client-->>Player: Confirms emerald received

    Player->>Client: Touches betting carpet
    Client->>Client: Places bet on selected number/option
    Client-->>Player: Displays bet on carpet

    Player->>Client: Touches ring to spin
    Client->>Client: Animates ball and determines winning number

    alt Winning Bet
        Client->>Server: sendWin(player, bet, payout)
        Server->>Database: Updates player balance
        Server-->>Client: Confirms win recorded
        Client->>Client: Adds emeralds to player inventory
        Client-->>Player: Displays win animation and payout
    else Losing Bet
        Client->>Client: Removes bet from display
        Client-->>Player: Shows losing result
    end

    Player->>Chat: $redeem (requests payout)
    Chat->>Client: Signals redemption request
    Client->>Server: getBallance(player)
    Server->>Database: Retrieves player balance
    Server-->>Client: Returns balance information
    Client->>Client: Processes payout to player
    Client-->>Player: Provides emeralds to player
    Client->>Server: resetBallance(player)
    Server->>Database: Resets player balance to zero
    Server-->>Client: Confirms balance reset
```

#### Player Detection Flow

```mermaid
flowchart LR
    A[Player Approaches Table] --> B{In Detection Zone?}
    B -->|No| C[Player Cannot Interact]
    B -->|Yes| D{Player Registered?}
    D -->|No| E[Player Uses $register Command]
    D -->|Yes| F[Player Can Place Bets]
    E --> F
    F --> G[Player Places Bet on Carpet]
    G --> H[Wheel Spins]
    H --> I{Winning Bet?}
    I -->|Yes| J[Calculate Payout]
    I -->|No| L[End Game Session]
    J --> K[Update Player Balance]
    K --> L
```

## Event Handling

The game uses ComputerCraft's event system to handle user input and peripheral events. The main loop in `spin.lua` listens for `redstone` and `monitor_touch` events.

- **Redstone Events**: Triggered when a player presses a button to register for betting.
- **Monitor Touch Events**: Triggered when a player touches the betting carpet or the roulette wheel.

### Event Flow Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle: System Start
    Idle --> PlayerRegistration: Redstone Event
    PlayerRegistration --> BettingPhase: Player Registered
    BettingPhase --> SpinningPhase: Touch Ring Monitor
    SpinningPhase --> ResultCalculation: Ball Stops
    ResultCalculation --> PayoutPhase: Calculate Winnings
    PayoutPhase --> Idle: Complete Transaction

    BettingPhase --> BettingPhase: Touch Carpet Monitor (Add Bet)
```

## Technical Implementation

### Modem Communication Protocol

The client and server communicate using the ComputerCraft modem peripheral on channel 1. Messages follow this format:

```mermaid
classDiagram
    class Message {
        type: string
        player?: string
        bet?: Bet
        payout?: number
        startPos?: Position
        endPos?: Position
    }

    class Response {
        type: string
        code: number
        message: string
        balance?: number
        players?: string[]
        numberOfPlayers?: number
    }

    Message --> Response: Triggers
```

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
