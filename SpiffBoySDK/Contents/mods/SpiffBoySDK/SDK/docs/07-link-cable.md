# 7. The link cable

Two consoles joined by a link cable can run a two player game. Each player keeps their own console, cartridge and screen; the cable carries only the short messages the two games send each other. This page describes the port, then lockstep, the technique Spiff-Pong uses to run a fast two player match over it.

A game for one player can ignore the cable entirely.

## The port: self.link

The game reaches the port through `self.link`, which has four methods:

| Call | Returns |
|---|---|
| `self.link:isConnected()` | True while the cable joins two consoles, both switched on, both running this same cartridge. |
| `self.link:seat()` | 1 on the console that holds the cable, 2 on the other one, nil while the cable joins nothing. The seats tell the two games apart. A seat is given as soon as the cable joins the two consoles, even before the other one runs the same game: test `isConnected()` before playing. |
| `self.link:send(message)` | Queues a message for the other console and returns true. Returns false when `isConnected()` is false, or when the port already took 4 messages this tick. |
| `self.link:receive()` | The next message received, in the order they were sent, or nil when none waits. |

A message is a string of 1 to 16 bytes, every byte below 256; anything else is an error. Pack numbers into bytes with `string.char` and read them back with `string.byte`:

```lua
local function tickBytes(tick)
    local value = tick % 65536
    return string.char(math.floor(value / 256), value % 256)
end

local function tickAt(message, position)
    return string.byte(message, position) * 256 + string.byte(message, position + 1)
end
```

Start every message with one letter naming its kind (`"I"` for an input, `"S"` for a start), and check the kind and the length of every message you receive before reading it.

### How messages travel

The port sends the queued messages in batches, every 100 ms, or sooner once 24 are queued. Between two players on the same computer a batch goes straight to the other console; in multiplayer it goes through the server, which adds the delay of the network. Messages arrive in order, but late. A batch that arrives after a newer one is left out with its messages, so a message can be lost.

The port keeps at most 256 messages waiting and drops the oldest beyond that. Read it on every tick, even on screens that do not use it; Spiff-Pong reads it at the start of every `tick`.

### When the connection ends

The connection ends when the cable comes out, or when the other console is switched off or changes cartridge. Two cases follow:

- If your game used the port in the last second, by a call to `send` (even one that returned false) or a message `receive` returned, the console freezes on its last picture with a notice of its own, until it is switched off. Your game has nothing to do for this case.
- Otherwise `isConnected()` simply turns false. Your game must notice it and leave its two player screens, as Spiff-Pong does:

  ```lua
  if self:onCable() and not port:isConnected() then
      self:openTitle("CableLost")
      return
  end
  ```

To test a two player game in the game, take a link cable from the developer menu and join the consoles of two players: two local players on one computer, or two players on a server.

## Why not send the ball?

The first idea for a two player Pong is to let one console run the match and send the position of the ball to the other. It fails:

- The ball moves every tick, 60 times a second; the port takes 4 short messages per tick, and they arrive late. The second player would see a ball from the past, jumping.
- Both players move a paddle. Neither console can decide alone where both paddles are.

## Lockstep: send the buttons, not the world

Lockstep solves both problems:

- Both consoles run the whole match themselves, with the same code.
- They start from the same seed, so they draw the same random numbers.
- Each tick, each console sends only its buttons for that tick, in one byte.
- A tick of the match runs only when both inputs for that tick are known, and both consoles apply them in the same order.

Same start, same code, same inputs: the two matches stay identical, tick for tick, and the ball never travels on the cable.

The buttons pressed now are applied a few ticks later, `delay` ticks ahead, so they have that long to cross the cable before the other console needs them:

```
delay = 3

frame:              1      2      3      4      5      6
console 1 sends:   in 3   in 4   in 5   in 6   in 7   in 8      (buttons of frame F for tick F - 1 + delay)
console 2 sends:   in 3   in 4   in 5   in 6   in 7   in 8
match runs tick:    0      1      2      3      4      5
                    ticks 0 to 2 need no message: both consoles read them as "nothing pressed"
```

- Ticks 0 to `delay - 1` are known in advance: nobody pressed anything yet.
- After that, each console runs tick T only once it holds its own input for T and the input of the other console for T.
- When the other input is late, the match waits (a stall), then catches up a few ticks per frame.

A short delay stalls often; a long one makes the buttons feel slow. Spiff-Pong measures the cable first and picks a delay just long enough.

## How Spiff-Pong does it

The two player code of Spiff-Pong lives in `Link.lua` (the messages) and `Play.lua` (running the match). The match itself, `Match.lua`, knows nothing about the cable: it takes the inputs of the left and the right paddle and moves the world one tick.

### The messages

```
H              hello: this console waits on the two player screen
B              bye: this console left the two player game
P t t          ping stamped with a tick, answered by Q t t
S m s s s s d v p   start of match m: 4 byte seed, delay, speed and points options
I m t t b      input of match m for tick t: b holds up (1) and down (2)
C m t t c c    checksum c of match m after tick t
```

The match number `m` lets a console ignore the messages of an older match.

### Meeting and measuring

1. Both players choose **2 PLAYERS** on the title. The entry is refused while `isConnected()` is false.
2. The waiting screen sends a hello every half second. When a hello comes back, each console knows the other one is there.
3. The console in seat 1, the leader, sends four pings, one at a time. The other console answers each with a pong carrying the same tick. The leader keeps the longest round trip.
4. The leader picks the delay, half the round trip plus 3 ticks, between 4 and 20:

   ```lua
   function Link:delay()
       return SpiffBoy.clamp(self:halfTrip() + Link.EXTRA_DELAY, Link.MIN_DELAY, Link.MAX_DELAY)
   end
   ```

5. The leader draws a seed from `self.random`, sends the start message with the seed, the delay and its options, and opens the match. The other console opens the same match when the start arrives.

   ```lua
   local seed = self.random:int(1, SEED_MAX)
   local delay = port:delay()
   if port:sendStart(seed, delay, self.options.speed, self.options.points) then
       self:startLinkedMatch(seed, delay, self.options.speed, self.options.points, port:halfTrip())
   end
   ```

The start message takes half a round trip to arrive, so the leader holds its first match tick back by that long (the last argument): both consoles then begin at about the same moment. The leader plays the left paddle, the other console the right one; both know their seat, so no message is needed for that.

### Each frame of the match

`Game:tickLinked` runs once per tick of the console:

```lua
function Game:tickLinked(held)
    local port = self.port
    local match = self.match
    self.frame = self.frame + 1
    while self.sentTick < self.frame - 1 + self.delay do
        if not port:sendInput(self.sentTick + 1, held) then
            break
        end
        self.sentTick = self.sentTick + 1
    end
    local steps = 0
    while steps < CATCH_UP and self.simTick < self.frame and not match:isOver() do
        local mine, theirs = self:inputsOf(self.simTick)
        if not mine then
            break
        end
        if self.mySide == 1 then
            match:tick(mine, theirs)
        else
            match:tick(theirs, mine)
        end
        port:forget(self.simTick)
        if self.simTick % CHECK_EVERY == 0 then
            port:sendCheck(self.simTick, match:checksum())
        end
        self.simTick = self.simTick + 1
        steps = steps + 1
    end
    ...
end
```

It sends the input of this frame for the tick `delay` ahead, runs every tick whose two inputs are known (at most `CATCH_UP`, 3, per frame), and now and then sends a checksum. The comments of `Play.lua` explain each line. The details that matter:

- Both consoles call `match:tick(left, right)` with the same two inputs in the same order: the leader passes `(mine, theirs)`, the other console `(theirs, mine)`.
- What is kept locally is exactly what was sent. When the port refuses a message (4 per tick at most), the tick is sent on the next frame with the buttons held then, and only then kept, so both consoles simulate the same input.
- When no tick could run for half a second, the screen writes `WAITING`.
- There is no pause on the cable: the other console would keep waiting.
- Every 60 ticks both consoles sum up the whole match into one number and compare. A difference means something broke determinism; the link test fails on it.

### Leaving

B on the waiting screen sends a bye before going back to the title. A console that receives a bye, or sees `isConnected()` turn false, while on a two player screen, goes back to the title with a short notice (`OTHER PLAYER LEFT`, `CABLE LOST`).

## Determinism

Lockstep works only if both consoles compute exactly the same match. The code that runs the match must follow the rules of [Determinism](10-kahlua-and-pitfalls.md#determinism): chance only from a generator seeded with the seed of the match, whole numbers, no `%` or division on negative values without care, no `pairs` where order matters, nothing read from outside the match, and drawing and sound kept out of it.

The robot plays alone and sees the cable as unplugged. `tests/spiff_pong/run_link_test.py` joins two Spiff-Pong consoles by a simulated cable and checks after every tick that both matches are identical; `link_test.lua` is a model for a test of your own game ([Testing](09-testing.md#testing-the-link-cable-offline)). The [walkthrough](12-spiff-pong-walkthrough.md) tours the rest of Spiff-Pong.

Next: [The cartridge item](08-the-cartridge-item.md).
