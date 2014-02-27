## callveyor

### Components

- dialer
- survey

Dialer

    Responsible for managing call flow and loading/displaying contact info.
    Every call state should map to a defined state in the dialer.

Survey

    Responsible for display, collection and persistance of call results.

## Coding guidelines

- 3rd party libraries must be loaded asynchronously and be wrapped as an angular service
- structure & organization follow the guidelines of ngbp (https://github.com/ngbp/ngbp)

## AngularJS Notes

### $state params

States are defined during the config phase. ui-router expects state params to be communicated via URL.

Ideally, when using nested views it would be possible to call `$state.go('my.state', {param1: 'blue'})` and rather than `templateUrl` as a fn loading params via `$location.current` it would have access to `$stateParams`.

Currently, this means that dynamically selecting a template at run time via `templateUrl` as a fn does not work unless state is being tracked in the URL.
