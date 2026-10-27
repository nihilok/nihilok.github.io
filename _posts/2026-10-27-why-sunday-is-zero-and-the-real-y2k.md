---
date: 2026-10-27
layout: post
title: "Why Sunday is Zero (and When the Real Y2K Hits)"
---

I was sitting in my terminal on a Monday evening, pair-programming with the Antigravity CLI.

We were building a new [ESP32](https://en.wikipedia.org/wiki/ESP32) controller destined to replace the clunky Raspberry Pi + [ESP8266](https://en.wikipedia.org/wiki/ESP8266) + relay board set-up running my home’s central heating that I had [first cobbled together back in 2020](/2021/01/23/central-heating-with-python.html).

Back then, the project started with a £7 Raspberry Pi Zero W, a Pi 3B tucked inside the airing cupboard next to a tangle of unlabelled brown mains wires, a couple of soldered BME280 sensors, and a Python `while True` loop calling `datetime.utcnow()` and `pigpio`. Over the years it had grown into a two-machine affair: the Pi 3B running a FastAPI server, SQLite, and a React frontend, talking over Wi-Fi to a separate ESP8266 node just to click the upstairs and downstairs relays.

Tonight’s goal was to collapse both machines: the Python web server, the database, the React UI, and the relay node, onto a single £4 ESP32 microcontroller flashed with embedded Rust firmware. We had just got Wi-Fi associating, pulled an IP lease from DHCP, and spun up an [SNTP](https://en.wikipedia.org/wiki/Network_Time_Protocol#SNTP) client to sync wall-clock time so the heating schedules could actually trigger. Awesome in and of itself already.

The code compiled. The logs started streaming. And then I took a break from prompting and had a read of the code:

```rust
Some(WallTime {
    year: tm.tm_year + 1900,
    month: (tm.tm_mon + 1) as u8,
    day: tm.tm_mday as u8,
    hour: tm.tm_hour as u8,
    minute: tm.tm_min as u8,
    second: tm.tm_sec as u8,
    weekday: tm.tm_wday as u8, // 0 = Sun, 1 = Mon, ..., 6 = Sat
})
```

I blinked at the screen.

Why exactly was Sunday 0? Is that a Unix thing, or is it an American thing? Should we switch it since I'm British (where Monday is typically situated at the far left of a calendar), and since central heating systems would traditionally only care about weekdays/weekends? And while we're at it, what's up with that way of representing the year? Computer scientists are most likely rolling their eyes. I asked the agent anyway.

What followed was a delightful rabbit hole into the fossilised archaeological layers of computing history - that I was vaguely aware of but not academically grounded in - and the discovery that our collective Y2K panic was merely a dress rehearsal for what’s quietly ticking away on embedded hardware right now.

---

## 1. The 1900 Hangover

To understand why `tm.tm_year + 1900` exists in a modern Rust codebase, you have to rewind half a century to [Bell Labs](https://en.wikipedia.org/wiki/Bell_Labs) in Murray Hill, New Jersey.

When Ken Thompson and Dennis Ritchie were hammering out early Unix and ANSI C in the early 1970s, every byte of [core memory](https://en.wikipedia.org/wiki/Magnetic-core_memory) was precious; if you could represent an integer in fewer bits, you did.

When Ritchie defined `struct tm` in [`<time.h>`](https://en.wikipedia.org/wiki/C_date_and_time_functions), he needed a field for the year. But why store a full four-digit number like `1972` when you could treat 1900 as the baseline of the modern century?

By defining `tm_year` as _"years since 1900"_, 1970 became `70`. Conveniently, any year between 1900 and 2027 could fit into a single signed 8-bit byte (`-128..127`).

Except humans are lazy creatures of habit. Over the next three decades, millions of developers writing C forgot the definition. They looked at `tm_year` returning `98` in 1998 and assumed it was just "the last two digits of the year".

So they wrote code like this:

```c
// Worked like a charm in 1999...
printf("19%d\n", tm.tm_year);
```

When midnight struck on January 1, 2000, `tm_year` ticked over to `100`. The code didn't print `2000`. It printed **`19100`**.

That single misunderstanding was responsible for a significant slice of the actual Y2K bugs that caused bank receipts to glitch and government websites to look foolish a quarter of a century ago.

---

## 2. Why Sunday is Zero

The next papercut in `struct tm` was the weekday:

```c
int tm_wday; /* days since Sunday - [0, 6] */
```

My hunch was right: it’s an American thing that became a Unix thing.

Dennis Ritchie and Ken Thompson lived and worked in New Jersey. In the traditional North American calendar, Sunday sits on the far left of the wall planner as the first column of the printed grid. Combine a Sunday-first wall calendar with C’s zero-indexed arrays, and `Sunday = 0` became computing gospel—even though [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) later codified the international standard with Monday as `1` and Sunday as `7`.

Then came the copy-paste chain:

1. **[POSIX](https://en.wikipedia.org/wiki/POSIX) & C89** standardised `struct tm` verbatim.
2. **Java (1995)** copied C's date conventions into `java.util.Calendar`.
3. **JavaScript (1995)** was famously hacked together by [Brendan Eich](https://en.wikipedia.org/wiki/Brendan_Eich) in ten days for Netscape Navigator. He was instructed to "make it look like Java". Naturally, `Date.prototype.getDay()` returns `0` for Sunday.

Fifty years later, millions of web developers building React forms still have to remember that `getDay() === 0` means they need to go to church.

---

## 3. The Rollover Timeline

Once we started pulling on the thread, my Antigravity CLI session turned into a countdown of the various ticking time-bombs embedded across the world's infrastructure.

Here is the actual maths on when computer time runs out:

| Target Date           | The Mechanism                        | What Actually Breaks                                                                                                                                             | Severity                                                                                                   |
| :-------------------- | :----------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------- |
| **Jan 1, 2000**       | 2-digit assumptions & `19%d`         | Date formatting printed `19100`; sorting broke.                                                                                                                  | The Original Y2K                                                                                           |
| **Jan 1, 2028**       | Signed 8-bit `tm_year` overflow      | Any legacy firmware packing `tm_year` into an `int8` rolls from `127` to `-128`, catapulting the date to **1772**.                                               | Obscure embedded microcontrollers & old [SCADA](https://en.wikipedia.org/wiki/SCADA)                       |
| **Feb 7, 2036**       | NTP 32-bit epoch rollover            | [Network Time Protocol](https://en.wikipedia.org/wiki/Network_Time_Protocol) unsigned 32-bit seconds since Jan 1, 1900 reach $2^{32}-1$. Wraps back to **1900**. | Unpatched IoT devices & old NTP clients                                                                    |
| **Jan 19, 2038**      | Unix `time_t` 32-bit signed overflow | Signed 32-bit seconds since 1970 hit `2,147,483,647`. Wraps to negative, jumping to **Dec 13, 1901**.                                                            | **[The Real Y2K](https://en.wikipedia.org/wiki/Year_2038_problem)**: massive disruption for 32-bit systems |
| **Year ~292 Billion** | 64-bit `time_t`                      | Signed 64-bit seconds since 1970.                                                                                                                                | The heat death of the universe                                                                             |

The 2028 one is mostly a curiosity—standard C defined `tm_year` as a full `int`, so it only bites devices where an engineer decided to bit-pack the struct into a single signed byte to save flash memory.

The **2036** and **2038** rollovers, however, are very real.

NTPv4 introduced the concept of "eras" to mitigate the 2036 rollover, but cheap smart plugs and abandoned IP cameras running stripped-down NTP implementations will wake up on February 8, 2036 convinced Queen Victoria is still on the British throne.

And 2038 is the Big One. Every legacy 32-bit Linux kernel running on industrial water pumps, older automotive ECUs, power grid monitoring gear, and legacy aerospace telemetry has a signed 32-bit counter quietly inching towards `2,147,483,647`.

---

## 4. Fixing it in Rust

Sitting there looking at our raw ESP32 code, the fix for our central heating controller was obvious.

With C's `0..=6` numbering, the weekend isn't even contiguous: Saturday (`6`) and Sunday (`0`) sit at opposite ends of the number line. For a British central heating programmer where the whole mental model is **Weekdays** (Monday–Friday) versus **Weekends** (Saturday–Sunday), `Sunday = 0` splits your weekend in half and is asking for an off-by-one bug that fires the boiler up at 5:30 AM on a Sunday morning (although it's definitely getting to the point where AI probably wouldn't make the same idle mistakes that humans make!).

With ISO 8601 (`Monday = 1 .. Sunday = 7`), weekdays are a clean `1..=5` and the weekend sits side-by-side at `6..=7`.

So we refactored [`src/time.rs`](https://github.com/nihilok/central-heating-esp32/blob/main/src/time.rs) into a strongly-typed, ISO 8601-aligned enum right at the C boundary, and paired it with our schedule's `Days` mask in [`src/model.rs`](https://github.com/nihilok/central-heating-esp32/blob/main/src/model.rs):

```rust
#[derive(Debug, Copy, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Weekday {
    Monday = 1,
    Tuesday = 2,
    Wednesday = 3,
    Thursday = 4,
    Friday = 5,
    Saturday = 6,
    Sunday = 7,
}

impl Weekday {
    /// Convert from C `struct tm::tm_wday` (0 = Sunday, 1 = Monday, ..., 6 = Saturday).
    pub fn from_tm_wday(wday: i32) -> Self {
        match wday {
            1 => Weekday::Monday,
            2 => Weekday::Tuesday,
            3 => Weekday::Wednesday,
            4 => Weekday::Thursday,
            5 => Weekday::Friday,
            6 => Weekday::Saturday,
            0 => Weekday::Sunday,
            _ => Weekday::Sunday, // safe fallback
        }
    }

    pub fn next(&self) -> Self {
        match self {
            Weekday::Monday => Weekday::Tuesday,
            Weekday::Tuesday => Weekday::Wednesday,
            Weekday::Wednesday => Weekday::Thursday,
            Weekday::Thursday => Weekday::Friday,
            Weekday::Friday => Weekday::Saturday,
            Weekday::Saturday => Weekday::Sunday,
            Weekday::Sunday => Weekday::Monday,
        }
    }
}
```

And in the heating schedule evaluator, checking whether a time period is active today—or rolling forward to tomorrow when you hit the **+1h Advance** button—reads like plain English:

```rust
impl Days {
    pub fn is_enabled(&self, weekday: Weekday) -> bool {
        match weekday {
            Weekday::Monday => self.monday,
            Weekday::Tuesday => self.tuesday,
            Weekday::Wednesday => self.wednesday,
            Weekday::Thursday => self.thursday,
            Weekday::Friday => self.friday,
            Weekday::Saturday => self.saturday,
            Weekday::Sunday => self.sunday,
        }
    }
}
```

Yeah it's a bit of boilerplate, and AI would have probably got it right either way. But you can't argue with how cleanly it reads. No magic numbers. No mental gymnastics about whether Sunday is at the start or the end. Zero ambiguity.

---

## 5. Two Machines Into One (and Ready for 2038)

By the end of the session, using a mix of Opus 5.5, Gemini Flash 3.8, and Gemini Argon, which are all available in `agy`, the rest of the stack fell into place faster and more cleanly than I would have thought possible on an £18.99 a month subscription (that also covers my family and comes with 5TB storage and various other bits and bobs 🤯):

- **Schedules in NVS:** Instead of a Raspberry Pi wearing out an SD card writing `persistence.json` on every poll, the ESP32 stores the zone schedules directly in non-volatile flash (`EspNvs`).
- **Pre-gzipped React [PWA](https://en.wikipedia.org/wiki/Progressive_web_app):** The 620 KB compiled React frontend bundle shrinks to 207 KB with `gzip -9`, embedded directly into the Rust binary via `include_bytes!` and served by `EspHttpServer` with `Content-Encoding: gzip`.
- **Direct Relay Control:** The network hop to the old ESP8266 relay board is gone. A dedicated [FreeRTOS](https://en.wikipedia.org/wiki/FreeRTOS) thread on the ESP32 polls the upstairs and downstairs BME280 sensors over HTTP every 10 seconds, evaluates the [hysteresis](https://en.wikipedia.org/wiki/Hysteresis) loop, and pulls [GPIO](https://en.wikipedia.org/wiki/General-purpose_input/output) 26 and GPIO 27 low—failing safe to `OFF` if Wi-Fi drops, a sensor goes dark, or SNTP hasn't synced.

| Metric               | 2020–2023 Stack (Pi 3B + ESP8266)         | 2026 Stack (Single ESP32 in Rust)                  |
| :------------------- | :---------------------------------------- | :------------------------------------------------- |
| **Hardware**         | Raspberry Pi 3B + ESP8266 + SD card       | 1× ESP-WROOM-32 (4 MB flash)                       |
| **Runtime**          | Linux + Python (FastAPI/Uvicorn) + SQLite | Embedded Rust firmware (ESP-IDF / FreeRTOS)        |
| **Relay Actuation**  | HTTP request over Wi-Fi to second board   | Direct GPIO 26 / 27 (active-low, glitch-free boot) |
| **Frontend Hosting** | Nginx + Uvicorn on Pi                     | `include_bytes!` gzipped in flash (207 KB)         |
| **Idle Power**       | ~3.5 W + ~0.5 W                           | ~0.3 W                                             |

As for the 2038 problem on our little microcontroller?

Earlier in the evening, when setting up the Cargo target flags in `.cargo/config.toml`, my agent had added:

```toml
[target.xtensa-esp32-espidf]
rustflags = ["--cfg", "espidf_time64"]
```

Starting in ESP-IDF v5, Espressif quietly upgraded `time_t` from 32-bit to a **64-bit integer**. By passing `--cfg espidf_time64` to the compiler, the Rust standard library mappings switch over to 64-bit time types.

Our single-chip ESP32 heating controller will happily tick past January 19, 2038 without a hitch. In fact, it won't run out of time until approximately the year **292,277,026,596**.

Two machines replaced by one. The radiators might rust through, and the sun will have swallowed the Earth, but the schedule will still fire on time.

```bash
# Check out the ESP32 Rust firmware
git clone https://github.com/nihilok/central-heating-esp32
```
