# Claveilleur

`Claveilleur /kla.vɛ.jœʁ/` is a simple input source switching daemon for macOS.

Inspired by a native Windows functionality, it can automatically switch the current input source for you according to the current application (rather than the current document).

**WARNING**: This is still a work in progress. Use it with care!

## Building & Installation

### Installing with `brew`

```sh
brew install rami3l/tap/claveilleur
```

### Building from source

```sh
# The recommended way is to use `mint`, so we will install it first:
brew install mint

# To live on the bleeding edge:
mint install rami3l/Claveilleur@master
```

## Usage

Getting started is as simple as:

```sh
# Installs the launch agent under `~/Library/LaunchAgents`
claveilleur --install-service

# Starts the service through launchd
claveilleur --start-service
```

If this is your first time using `Claveilleur`, please note that you might need to grant necessary privileges through `System Settings > Privacy & Security > Accessibility`.
After doing so, you might need to stop the service and start it again for those changes to take effect:

```sh
# Restarts the service through launchd
claveilleur --stop-service && claveilleur --start-service
```

To uninstall the service, you just need to run the following:

```sh
# Stops the service through launchd
claveilleur --stop-service

# Removes the launch agent from `~/Library/LaunchAgents`
claveilleur --uninstall-service
```
