# /usr/local/bin/prelaunch-kiosk-session.sh
#!/usr/bin/expect -f

spawn /usr/bin/xrdp-sesrun astronaut-kiosk
expect "Password:"
send "\r"
expect eof
