describe 'survey controller', ->
  $scope = ''
  $rootScope = ''
  $controller = ''
  $httpBackend = ''
  $cacheFactory = ''
  usSpinnerService = ''
  SurveyFormFieldsFactory = ''
  cSCache = ''
  idFlashFactory = ''

  caller = {id: 3}

  beforeEach(module('survey'))

  beforeEach(inject((_$rootScope_, _$controller_, _$httpBackend_, _$cacheFactory_, _usSpinnerService_, _SurveyFormFieldsFactory_, _idFlashFactory_) ->
    $rootScope = _$rootScope_
    $controller = _$controller_
    $scope = $rootScope
    $httpBackend = _$httpBackend_
    $cacheFactory = _$cacheFactory_
    idFlashFactory = _idFlashFactory_
    cSCache = $cacheFactory('callStation')
    cSCache.put('data', {caller})

    $httpBackend.whenGET('/call_center/api/survey_fields.json').respond({})
    usSpinnerService = _usSpinnerService_
    SurveyFormFieldsFactory = _SurveyFormFieldsFactory_
    $controller('SurveyFormCtrl', {$scope})
  ))

  it 'creates a survey obj', ->
    expect($scope.survey).toBeDefined()

  it 'survey.saving is false initially', ->
    expect($scope.survey.saving).toBeFalsy()

  it 'surve.hideButtons is true initially', ->
    expect($scope.survey.hideButtons).toBeTruthy()

  describe 'survey.responses', ->
    it 'have a notes key with an empty obj value', ->
      expect($scope.survey.responses.notes).toEqual({})

    it 'have a question key with an empty obj value', ->
      expect($scope.survey.responses.question).toEqual({})

  describe 'survey.save($event, andContinue=true|false)', ->
    beforeEach ->
      $httpBackend.whenPOST("/call_center/api/#{caller.id}/submit_result").respond(200, {})
      $httpBackend.whenPOST("/call_center/api/#{caller.id}/submit_result_and_stop").respond(200, {})
      usSpinnerService.spin = jasmine.createSpy('-usSpinnerService.spin Spy-')
      usSpinnerService.stop = jasmine.createSpy('-usSpinnerService.stop Spy-')

      @notes = {"42": 367}
      @quesiton = {"73": 91}

    it 'is a no-op if survey.saving is true', ->
      $scope.$apply('survey.saving = true')
      $scope.survey.save()
      expect(usSpinnerService.spin).not.toHaveBeenCalled()

    it 'spins the global spinner', ->
      $scope.survey.save({})
      expect(usSpinnerService.spin).toHaveBeenCalled()

    it 'sets survey.saving to true', ->
      expect($scope.survey.saving).toBeFalsy()
      $scope.survey.save({})
      expect($scope.survey.saving).toBeTruthy()

    describe 'request completes', ->
      it 'stops the global spinner', ->
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect(usSpinnerService.stop).toHaveBeenCalled()

      it 'sets survey.saving to false', ->
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect($scope.survey.saving).toBeFalsy()

    describe 'request is success', ->
      it 'resets survey.responses', ->
        $scope.survey.responses.notes = @notes
        $scope.survey.responses.question = @question
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect($scope.survey.responses).toEqual({notes: {}, question: {}})

    describe 'request is error', ->
      beforeEach ->
        $httpBackend.flush()
        $httpBackend.expectPOST("/call_center/api/#{caller.id}/submit_result").respond(400, {})

      it 'preserves survey.responses', ->
        $scope.survey.responses.notes = @notes
        $scope.survey.responses.question = @question
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect($scope.survey.responses.notes).toEqual(@notes)
        expect($scope.survey.responses.question).toEqual(@question)
      it 'displays a message to the user', ->
        idFlashFactory.now = jasmine.createSpy('-idFlashFactory.now spy-')
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect(idFlashFactory.now).toHaveBeenCalledWith('error', "Survey results failed to save. Please try again and contact support if this problem persists.")
      it 'sets survey.saving to false', ->
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect($scope.survey.saving).toBeFalsy()

      describe 'andContinue=true', ->
        it 'transitions $state to dialer.hold... OR does it?'

      describe 'andContinue=false', ->
        it 'transitions $state to dialer.stop... OR does it?'

    describe 'andContinue=true', ->

      afterEach ->
        $httpBackend.verifyNoOutstandingExpectation()

      it 'POSTs survey.responses to /call_center/api/:caller_id/submit_result', ->
        expectedData = {
          question: {"1": 321},
          notes: {"1": "Some text"}
        }
        $scope.survey.responses = expectedData
        $httpBackend.expectPOST("/call_center/api/#{caller.id}/submit_result", expectedData).respond(200, {})
        $scope.survey.save({}, true)

    describe 'andContinue=false', ->

        afterEach ->
          $httpBackend.verifyNoOutstandingExpectation()

      it 'POSTs survey.responses to /call_center/api/:caller_id/submit_result_and_stop', ->
        $httpBackend.expectPOST("/call_center/api/#{caller.id}/submit_result_and_stop").respond({})
        $scope.survey.save({}, false)
