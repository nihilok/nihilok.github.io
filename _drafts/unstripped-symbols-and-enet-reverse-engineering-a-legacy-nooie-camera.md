---
layout: post
title: "Unstripped Symbols and ENet: Reverse-Engineering a Legacy Nooie Camera"
---

You spin up `nooie-proxy` to pull a £25 Nooie Cam 360 (`IPC100B`) into Home Assistant, hit connect, and get `code=1104` on `create_session`. Or, if it gets past session creation, it sits there for thirty seconds waiting on a WebRTC `SdpOffer` answer that never arrives.

Oh, and if you logged in with the same Nooie account your phone uses, it just kicked your phone out of the app too.

Welcome to **The WebRTC Cliff**.

[`ltrgoddard/hass-nooie`](https://github.com/ltrgoddard/hass-nooie) and [`ltrgoddard/nooie-proxy`](https://github.com/ltrgoddard/nooie-proxy) (`v0.3.1`) are tidy, well-built tools for newer Nooie cameras that speak WebRTC (`aiortc` + WebSocket signalling). They even include partial `apeman.py` and `twofish.py` scaffolding. But older hardware (`IPC100`, `IPC100A`, `IPC100B`, `IPC100C`, `IPC100D`, `IPC200A`, tracked in `hass-nooie#3`) does not speak WebRTC at all. It speaks Apeman's legacy UDP P2P protocol (`hb_domain:hb_port`).

No RTSP. No ONVIF. No WebRTC.

Just a stubborn plastic dome sitting on `192.168.1.151` (firmware `4.4.18`) waiting for an Android app to talk to it. So I unpacked the Android APK.

---

## 1. The Unstripped Gift (`libnooie.so`)

Unpacking `com.nooie.home` (`v3.9.7`, `config.arm64_v8a.apk`) dropped a 10.9 MB ARM64 shared library on disk: `libnooie.so`.

And whoever shipped the build forgot to strip it. **10,216 exported symbols**, sitting right there in plain sight.

Between the symbols and disassembling the init paths, the entire legacy Apeman P2P stack unfolded step by step:

1. **Cloud auth & JWT claims:** Standard `nooie-proxy` login (`/account/country` -> `/login/login` -> `/user/put`) returns an `api_token` JWT containing `t_id` (a 32-character P2P token) and `sch` (a 16-character schema string). `/device/list` then gives each camera's `uuid`, 16-character `secret`, `hb_domain` (e.g. `p2p31-eu.nooie.com`), and `hb_port` (`6116`).
2. **NAT registration & punch:** Every RPC uses `apeman.py` framing (`4-byte BE total len` + nanopb `ReqHeader` + Twofish-256-ECB body keyed by `md5(f"{method}{trans_id}ApEMaNSNoOiE").hexdigest()`). You run `Getsrv` (TCP `:9000` on `policy-eu.nooie.com`), `NatOne`, `NatGetInfo`, and `PutNatInfo`, then send a UDP `P2pInit` to `hb_domain:hb_port` with your `uid`, `camera_uuid`, `localIp`, `localPort`, `t_id`, and `sch`.
3. **The punch:** `P2pInfo` returns the camera's WAN/LAN IP:port and a 16-byte `security_key`. From the bound `localPort`, you send `P2pConn` (`tag 1 = security_key`) directly to the camera's LAN or WAN address; the camera sends `P2pConn` (`rpc_type=1`) back; you reply with `P2pConn` (`rpc_type=2`, `code=0`, `encrypt=0`).

That gets you through the door. What happens *after* the punch is where things get interesting.

---

## 2. The Transport Plot Twist: ENet and Partial Twofish-CBC

Disassembling `apeman_reliable_udp_init` revealed that the "proprietary" reliable UDP layer isn't custom at all: **it wraps standard ENet (`libenet7`)**, bound to the exact same local UDP IP:port used for the `P2pConn` handshake, with two channels (channel `1` reliable for commands).

Once the ENet peer connects, commands use a 20-byte header (`total_len`, magic `89abcdef113c2b1a`, `0x50 | ch`, `0x00`, `cmd_id`, `trans_id`) with a payload encrypted in **Twofish-256-ECB** (PKCS#5/7) keyed by `md5(camera_secret).hexdigest()`:

* `ASDP2pCmdStartLiveAV` (`0x003E`, 16-byte zero payload): starts live 1080p HEVC video and G.711 A-law audio.
* `ASDP2pCmdHeartbeat` (`0x000E`, 104-byte zero payload): must be sent roughly every 10 seconds, or the camera drops the ENet peer after ~36 seconds.
* `ASDP2pCmdStopLiveVideo` (`0x0011`) and `ASDP2pCmdStopLiveAudio` (`0x0013`): clean teardown.

Media packets then arrive with a 16-byte header starting with `0xaa55`, packet `type`, `flags`, sequence number, payload length, and timestamp:

* **Video (`type == 5`, HEVC Annex-B):** Fragments accumulate until `flags & 0x01`. Bytes `0..15` are cleartext; up to `256` bytes starting at offset `16` are encrypted with **Twofish-256-CBC (zero IV)** using `md5(camera_secret).hexdigest()`; the rest of the frame is cleartext.
* **Audio (`type == 2`, G.711 A-law, 8 kHz mono, 800 B / 100 ms):** Encrypted with **Twofish-256-CBC (zero IV)** on complete 16-byte blocks.

Encrypting only the first 256 bytes of an Annex-B video frame keeps CPU load down on cheap camera silicon while scrambling the slice headers enough to make raw captures useless without the key.

---

## 3. On-Demand Streaming on `pi5` (Without Waking It 24/7)

Since this is a kids' room camera, I did not want it streaming continuously into Frigate's recorder or burning background cycles when nobody was watching.

So I built a small on-demand streamer (`nooie-p2p.service`) on `pi5` (`192.168.1.252`, Debian ARM64) using Python's stdlib, `twofish.py`, `libenet.so.7` via `ctypes`, and `ffmpeg` (`-c:v copy` for 1080p HEVC, `alaw` -> `aac` 16 kHz mono):

```text
Home Assistant (Generic Camera, TCP, no still_image_url)
        │
        ▼  rtsp://127.0.0.1:8554/kids_room
Frigate go2rtc (on-demand only; omitted from cameras:)
        │
        ▼  http://192.168.1.252:8560/stream.ts
nooie-p2p.service (ctypes libenet7 + Twofish + ffmpeg)
        │
        ▼  ENet UDP + 10s 0x000E heartbeats
Nooie IPC100B (192.168.1.151)
```

Three small details make it livable in daily use:

1. **Lazy wake, clean sleep:** The service only runs `P2pInit` and `StartLiveAV` when the first HTTP viewer hits `:8560/stream.ts`. Concurrent viewers share the single camera session, and 2.5 seconds after the last viewer disconnects, it sends `StopLiveVideo`/`StopLiveAudio` and tears down the ENet peer.
2. **No thumbnail polling:** Home Assistant uses the **Generic Camera** integration (`rtsp_transport: tcp`) with `still_image_url` left blank, and Frigate omits `kids_room` from `cameras:` (keeping it strictly under `go2rtc.streams` with a transcode fallback for WebRTC browsers). Nothing polls the camera in the background.
3. **Second account:** Nooie's backend invalidates existing sessions on a fresh login. Sharing the camera to a dedicated second Nooie account stops Home Assistant from logging your phone out.

A 45-second continuous `ffmpeg` soak test passed with the 10-second heartbeat keeping the peer alive (`SOAK_45S_OK`), `ffprobe` confirmed `hevc 1920x1080` + `aac 16000 Hz mono`, and the live feed opened cleanly in the Home Assistant Android app.

---

## 4. Next Up: Pure-Python Upstream PR

Using `ctypes` against `libenet.so.7` and shelling out to `ffmpeg` works nicely on a Debian `pi5` host, but it won't fly upstream in `ltrgoddard/nooie-proxy`: Home Assistant OS and Docker containers run on Alpine (`musl`), where `libenet7` isn't installed by `pip`.

The clean upstream path is already mapped out:

* **Pure-Python ENet client (`~250` lines):** Just the single-peer subset of ENet 1.3.x (`CONNECT`, `VERIFY_CONNECT`, `ACKNOWLEDGE`, `SEND_RELIABLE` on channel `1`, `SEND_UNRELIABLE`/`SEND_FRAGMENT`, `PING`, `DISCONNECT`) using `asyncio`/`socket` + `struct`.
* **In-process muxing with `PyAV`:** `nooie-proxy` already depends on `av`, which can mux decrypted HEVC + G.711 A-law straight to MPEG-TS without spawning `ffmpeg`.
* **Automatic fallback:** Try WebRTC (`create_session` + `rtc.py`) first, and fall back to legacy Apeman P2P on `code=1104` or 30-second timeout (plus a `--transport auto|webrtc|legacy` CLI flag).

---

No RTSP. No vendor bridge. Just an unstripped `.so`, a 20-year-old game networking library, and 256 bytes of Twofish between a legacy camera and Home Assistant.
