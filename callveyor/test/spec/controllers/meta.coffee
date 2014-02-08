'use strict'

describe 'Controller: MetaCtrl', () ->

  # load the controller's module
  beforeEach module 'callveyorApp'

  MetaCtrl = {}
  scope = {}

  # Initialize the controller and a mock scope
  beforeEach inject ($controller, $rootScope) ->
    scope = $rootScope.$new()
    MetaCtrl = $controller 'MetaCtrl', {
      $scope: scope
    }

  it 'should attach a meta object to the scope', () ->
    expect(scope.meta).toBeDefined()

  it 'should set a currentYear property on meta to YYYY', ->
    expect(scope.meta.currentYear).toEqual((new Date()).getFullYear())
