'use strict'

describe 'Service: currentYear', () ->

  # load the service's module
  beforeEach module 'callveyor'

  # instantiate service
  currentYear = {}
  beforeEach inject (_currentYear_) ->
    currentYear = _currentYear_

  it 'should do something', () ->
    expect(currentYear).toEqual((new Date()).getFullYear())
