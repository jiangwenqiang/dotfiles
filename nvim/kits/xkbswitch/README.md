# Console keyboard layout switcher for Mac OS X

## install
```bash
cd xkbswitch
make && sudo mv xkbswitch ../../bin && sudo rm xkbswitch-arm xkbswitch-x86
```

## usage

```bash
xkbswitch # prints com.apple.keylayout.ABC
xkbswitch com.apple.keylayout.ABC # sets up keyboard layout to com.apple.keylayout.ABC
```
