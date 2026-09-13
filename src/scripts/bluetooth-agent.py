#!/usr/bin/env python3
"""Basalt bluetooth pairing agent.

Registers a bluez agent that hands out the display PINs and auto-confirms
Simple Secure Pairing (Just Works), so pairing from the Basalt bluetooth
panel works with no other desktop running. Without ANY registered agent
bluez fails every pairing with "Authentication Failed".

Usage: bluetooth-agent.py [pin]
Optional hex PIN is displayed for legacy PIN devices; not implemented as a
prompt (headless by design) — the handshake completes either Just Works,
NoInputNoOutput auto-accept, or fails loudly in the system journal.
"""

import sys

from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import dbus
import dbus.exceptions
import dbus.service

BUS = None
MAINLOOP = None

BLUEZ_SERVICE = "org.bluez"
AGENT_MANAGER = "/org/bluez"  # org.bluez exports AgentManager1 here
AGENT_PATH = "/basalt/bluetooth/agent"

CAPABILITY = "KeyboardDisplay"  # broadest: accepts Just Works + passkey/modes

# Fixed numeric PIN for legacy PIN devices; SSP devices are numeric
# compare and never use it. 6 digits.
AGENT_PIN = 0


class Rejected(dbus.exceptions.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Failed(dbus.exceptions.DBusException):
    _dbus_error_name = "org.bluez.Error.Failed"


class Agent(dbus.service.Object):
    @dbus.service.method(BLUEZ_SERVICE, in_signature="", out_signature="")
    def Release(self):
        sys.exit(0)

    @dbus.service.method(BLUEZ_SERVICE, in_signature="", out_signature="s")
    def RequestPinCode(self, device):
        # Legacy PIN path — with no UI, hand out the fixed configurable PIN.
        return str(AGENT_PIN)

    @dbus.service.method(BLUEZ_SERVICE, in_signature="ou", out_signature="")
    def DisplayPinCode(self, device, pin_code):
        pass  # headless: the peer shows it; nothing to render

    @dbus.service.method(BLUEZ_SERVICE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        # Passkey path: accept the peer's passkey prompt with a fixed key.
        return dbus.UInt32(AGENT_PIN)

    @dbus.service.method(BLUEZ_SERVICE, in_signature="ouu", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        pass

    @dbus.service.method(BLUEZ_SERVICE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        # SSP Just Works / numeric compare: accept. Documented behaviour of
        # a headless agent — the alternative is unrecoverable pairing.
        return

    @dbus.service.method(BLUEZ_SERVICE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        return

    @dbus.service.method(BLUEZ_SERVICE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        # Accept service auto-connects for already-paired devices.
        return

    @dbus.service.method(BLUEZ_SERVICE, in_signature="", out_signature="")
    def Cancel(self):
        raise Rejected("Pairing canceled")


def main():
    global MAINLOOP

    DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus, AGENT_PATH)

    manager = dbus.Interface(
        bus.get_object(BLUEZ_SERVICE, AGENT_MANAGER),
        BLUEZ_SERVICE + ".AgentManager1")
    manager.RegisterAgent(dbus.ObjectPath(AGENT_PATH), CAPABILITY)
    manager.RequestDefaultAgent(dbus.ObjectPath(AGENT_PATH))

    MAINLOOP = GLib.MainLoop()
    try:
        MAINLOOP.run()
    except KeyboardInterrupt:
        agent.Release()


if __name__ == "__main__":
    main()
