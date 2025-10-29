#!/usr/bin/env bash
systemctl --user restart x0vncser-xrdp && exec dbus-run-session -- startplasma-x11
