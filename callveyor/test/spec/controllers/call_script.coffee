'use strict'

describe 'Controller: CallScriptCtrl', () ->

  # load the controller's module
  beforeEach module 'callveyorApp'

  CallscriptCtrl = {}
  scope = {}

  # Initialize the controller and a mock scope
  beforeEach inject ($controller, $rootScope) ->
    scope = $rootScope.$new()
    CallScriptCtrl = $controller 'CallScriptCtrl', {
      $scope: scope
    }

  it 'should attach a call_script obj to the scope', () ->
    expect(scope.call_script).toBeDefined()

