describe 'transitionGateway module', ->
  describe 'constants', ->
    validTransitions = {}

    beforeEach module('transitionGateway')

    beforeEach(inject((_validTransitions_) ->
      validTransitions = _validTransitions_
    ))

    it '"validTransitions" contains a mapping of allowed transitions', ->
      expect(validTransitions.toString()).toBe('[object Object]')

  describe 'transitionValidator', ->

    $state       = ''
    $rootScope   = ''
    transitionValidator = ''

    beforeEach module('transitionGateway', ($stateProvider, $provide) ->
      ->
        $provide.constant('validTransitions', {
          'root': ['mod'],
          'mod': ['mod.state1'],
          'mod.state1': ['mod', 'mod.state2'],
          'mod.state2': ['mod.state1', 'mod.state3'],
          'mod.state3': ['mod.state2', 'mod.state1']
        })
        $stateProvider.state('mod', {})
        $stateProvider.state('blah', {})
        $stateProvider.state('mod.state1', {})
        $stateProvider.state('mod.state2', {})
        $stateProvider.state('mod.state3', {})
    )

    beforeEach(inject(
      (_$rootScope_, _$state_, _$httpBackend_, _transitionValidator_) ->
        $state = _$state_
        $rootScope = _$rootScope_
        transitionValidator = _transitionValidator_
    ))

    it 'allows transitions where fromState.name matches a key and toState.name is included in the corresponding array value', ->
      for state in ['mod', 'mod.state1', 'mod', 'mod.state1', 'mod.state2', 'mod.state3', 'mod.state1']
        $state.go(state)
        $rootScope.$apply()
        expect($state.is(state)).toBeTruthy()

    it 'prevents transitions where fromState.name does not match any key', ->
      $state.go('blah')
      $rootScope.$apply()
      expect($state.is('blah')).toBeFalsy()

    it 'prevents transitions where fromState.name matches a key and toState.name is NOT included in the corresponding array value', ->
      $state.go('mod')
      $rootScope.$apply()
      $state.go('mod.state2')
      $rootScope.$apply()
      expect($state.is('mod.state2')).toBeFalsy()
      expect($state.is('mod')).toBeTruthy()