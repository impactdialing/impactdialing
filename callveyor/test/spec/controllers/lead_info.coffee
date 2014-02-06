'use strict'

describe 'Controller: LeadInfoCtrl', () ->

  # load the controller's module
  beforeEach module 'callveyorApp'

  LeadInfoCtrl = {}
  scope = {}

  # Initialize the controller and a mock scope
  beforeEach inject ($controller, $rootScope) ->
    scope = $rootScope.$new()
    LeadInfoCtrl = $controller 'LeadInfoCtrl', {
      $scope: scope
    }

  it 'should attach a lead_info object to the scope', () ->
    expect(scope.lead_info).toBeDefined()

  it 'should attach a meta obj to lead_info', ->
    expect(scope.lead_info.meta).toBeDefined()

  it 'sets lead_info.meta.collapse to false', ->
    expect(scope.lead_info.meta.collapse).toBeFalsy()
