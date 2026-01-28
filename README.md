# Denon & Marantz Telnet Controller

A Swift-based application that communicates with **Denon** and **Marantz** AV receivers over **Telnet via Wi‑Fi**, enabling remote control and status monitoring without relying on proprietary SDKs or cloud services.

This project began as a **passion project during the summer of my junior year** and continues to be updated when time allows.

---

## Overview

Denon and Marantz receivers expose a Telnet-based control protocol over the local network. This application connects directly to that interface, allowing commands to be sent and responses parsed in real time.

The goal of the project is to:

* Learn low-level network communication
* Work directly with real-world hardware protocols
* Build a lightweight, local-first controller in Swift

---

## Features

* 📡 **Telnet over Wi‑Fi** communication with receivers
* 🎚 **Basic receiver control** (power, volume, input selection, etc.)
* 📊 **Real-time status parsing** from receiver responses
* 🧠 **Protocol-driven design** based on official Denon/Marantz command specs
* 🍎 **Written in Swift**, focusing on clean and readable architecture

---

## Supported Devices

This project targets **Denon and Marantz AV receivers** that support Telnet control (typically enabled by default on port `23`).

> Note: Compatibility may vary by model and firmware version.

---

## How It Works

1. The application connects to the receiver's local IP address over Wi‑Fi
2. A Telnet session is established using standard TCP sockets
3. Commands are sent as plain-text strings defined by the receiver protocol
4. Responses are parsed and mapped to application state

All communication happens **locally** on the network — no internet or cloud services required.

---

## Tech Stack

* **Language:** Swift
* **Networking:** Raw TCP sockets (Telnet protocol)
* **Platform:** Apple platforms (macOS / iOS, depending on build target)

---

## Motivation

This project started as a way to:

* Explore Swift beyond typical UI-driven apps
* Understand how consumer electronics expose control interfaces
* Build something useful for a real audio setup

It also served as a hands-on introduction to:

* Network protocols
* Stateful device communication
* Parsing and handling asynchronous responses

---

## Availability

📱 **iOS App Store**

The app is currently available on the **Apple App Store** for iOS under the name **Telepath: AVR**.

---

## Project Status

🛠 **Actively maintained when time permits**

Development primarily happens during free time, with updates focused on stability, protocol coverage, and code cleanup.

---

## Future Ideas

* Expanded command support
* Improved error handling and reconnection logic
* UI enhancements
* Preset and automation support

---

## Disclaimer

This project is **not affiliated with or endorsed by Denon or Marantz**.
All trademarks belong to their respective owners.

---

## License

This project is provided as-is for educational and personal use.

Feel free to explore, modify, and learn from the code.
