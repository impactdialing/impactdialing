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
- careful naming of scripts (see Twilio awesomeness)

### Twilio awesomeness

When twilio.js is loaded it performs a scan of all script tags attempting to locate
the script tag that loaded itself. The regex is weak though and expects that
only the official twilio script itself will have a filename like `twilio.js`.
So naming of scripts must be such that no script ends with the word `twilio`
immediately preceding the `js` extension.

A ticket has been submitted: https://www.twilio.com/user/account/support/ticket/205640

## AngularUI Notes

### $stateParams

States are defined during the config phase. ui-router's $stateParams requires state params to be communicated via URL.

Ideally, when using nested views it would be possible to call `$state.go('my.state', {param1: 'blue'})` and rather than `templateUrl` as a fn loading params via `$location.current` it would have access to `$stateParams`.

Currently, this means that dynamically selecting a template at run time via `templateUrl` as a fn does not work unless state is being tracked in the URL.

Bottom line: while $state is functional w/out providing a `url` property, $stateParams is not.

### Unit testing Directives

Scenario: there is a directive to test and the controller this directive depends on sets some object to $scope.

```
survey.controller('SurveyFormCtrl', ($scope) ->
  survey = {}
  survey.hideStuff = true
  ...
  $scope.survey = survey
)
survey.directive('idSurvey', ->
  {
    restrict: 'A'
    templateUrl: '/callveyor/survey/survey.tpl.html'
    controller: 'SurveyFormCtrl'
  }
)
```

Note `$scope.survey = survey` above. When unit testing this directive any changes
to the `$scope.survey` object from the test itself will be overridden when the controller runs.
Instead, use `$scope.survey ||= survey` or refactor potential problem properties off of the `survey`
object and put them directly on `$scope`.

### $scope vs $rootScope

When setting a variable intended for `$rootScope` in an HTML attribute e.g. `data-ng-click="transitionInProgress = true"` it makes it possible to lose
the reference to the $rootScope property, setting the property on $scope instead.