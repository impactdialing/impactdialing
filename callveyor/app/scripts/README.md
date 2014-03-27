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
- state should not be tracked in the url in order to avoid History & Refresh complications; i.e. the `url` property should never be set on any state.
- $rootScope should not be used to share data among views, use $cacheFactory
- $rootScope can be used to share e.g. view state across the app (collapse/expand, etc)
- if $rootScope is used then it should be maintained as shallow as possible

## AngularUI Notes

### $stateParams

States are defined during the config phase. ui-router's $stateParams requires state params to be communicated via URL.

Ideally, when using nested views it would be possible to call `$state.go('my.state', {param1: 'blue'})` and rather than `templateUrl` as a fn loading params via `$location.current` it would have access to `$stateParams`.

Currently, this means that dynamically selecting a template at run time via `templateUrl` as a fn does not work unless state is being tracked in the URL.

Bottom line: while $state is functional w/out providing a `url` property, $stateParams is not.
