describe 'survey controller', ->
  $scope = ''
  $rootScope = ''
  $controller = ''
  $httpBackend = ''
  $cacheFactory = ''
  usSpinnerService = ''
  SurveyFormFieldsFactory = ''
  callCache = ''
  idFlashFactory = ''

  call = {id: 3}

  beforeEach(module('survey'))

  beforeEach(inject((_$rootScope_, _$controller_, _$httpBackend_, _$cacheFactory_, _usSpinnerService_, _SurveyFormFieldsFactory_, _idFlashFactory_) ->
    $rootScope = _$rootScope_
    $controller = _$controller_
    $scope = $rootScope
    $httpBackend = _$httpBackend_
    $cacheFactory = _$cacheFactory_
    idFlashFactory = _idFlashFactory_
    callCache = $cacheFactory('call')
    callCache.put('id', call.id)

    $httpBackend.whenGET('/call_center/api/survey_fields.json').respond({})
    usSpinnerService = _usSpinnerService_
    SurveyFormFieldsFactory = _SurveyFormFieldsFactory_
    $controller('SurveyFormCtrl', {$scope})
  ))

  it 'creates a survey obj', ->
    expect($scope.survey).toBeDefined()

  it 'survey.disable is false initially', ->
    expect($scope.survey.disable).toBeFalsy()

  it 'surve.hideButtons is true initially', ->
    expect($scope.survey.hideButtons).toBeTruthy()

  describe 'survey.responses', ->
    it 'have a notes key with an empty obj value', ->
      expect($scope.survey.responses.notes).toEqual({})

    it 'have a question key with an empty obj value', ->
      expect($scope.survey.responses.question).toEqual({})

  describe 'survey.save($event, andContinue=true|false)', ->
    beforeEach ->
      $httpBackend.whenPOST("/call_center/api/#{call.id}/submit_result").respond(200, {})
      $httpBackend.whenPOST("/call_center/api/#{call.id}/submit_result_and_stop").respond(200, {})
      usSpinnerService.spin = jasmine.createSpy('-usSpinnerService.spin Spy-')
      usSpinnerService.stop = jasmine.createSpy('-usSpinnerService.stop Spy-')

      @notes = {"42": 367}
      @question = {"73": 91}

    it 'is a no-op if survey.requestInProgress is true', ->
      $scope.$apply('survey.requestInProgress = true')
      $scope.survey.save()
      expect(usSpinnerService.spin).not.toHaveBeenCalled()

    it 'spins the global spinner', ->
      $scope.survey.save({})
      expect(usSpinnerService.spin).toHaveBeenCalled()

    it 'sets survey.requestInProgress to true', ->
      expect($scope.survey.requestInProgress).toBeFalsy()
      $scope.survey.save({})
      expect($scope.survey.requestInProgress).toBeTruthy()

    describe 'request completes', ->
      it 'stops the global spinner', ->
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect(usSpinnerService.stop).toHaveBeenCalled()

      it 'sets survey.disable to false', ->
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect($scope.survey.disable).toBeFalsy()

    describe 'request is success', ->
      beforeEach ->
        $scope.survey.responses.notes = @notes
        $scope.survey.responses.question = @question

      it 'resets survey.responses', ->
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect($scope.survey.responses).toEqual({notes: {}, question: {}})

      it 'broadcasts survey:save:success', ->
        successSpy = jasmine.createSpy('-survey:save:success callback spy-')
        $rootScope.$on('survey:save:success', successSpy)
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect(successSpy).toHaveBeenCalled()

      it 'notifies the user of success, hiding the notification after some seconds', ->
        idFlashFactory.now = jasmine.createSpy('-idFlashFactory.now spy-')
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect(idFlashFactory.now).toHaveBeenCalledWith('success', jasmine.any(String), jasmine.any(Number))

    describe 'request is error', ->
      beforeEach ->
        idFlashFactory.now = jasmine.createSpy('-idFlashFactory.now spy-')
        $httpBackend.flush()

      it 'preserves survey.responses', ->
        $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(444, {})
        $scope.survey.responses.notes = @notes
        $scope.survey.responses.question = @question
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect($scope.survey.responses.notes).toEqual(@notes)
        expect($scope.survey.responses.question).toEqual(@question)

      it 'displays a message to the user', ->
        $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(444, {})
        idFlashFactory.now = jasmine.createSpy('-idFlashFactory.now spy-')
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect(idFlashFactory.now).toHaveBeenCalledWith('error', jasmine.any(String))

      it 'sets survey.disable to false', ->
        $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(444, {})
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect($scope.survey.disable).toBeFalsy()

      describe 'error is 400', ->
        it 'displays bad request message', ->
          $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(400, {})
          $scope.survey.save({}, true)
          $httpBackend.flush()
          expect(idFlashFactory.now).toHaveBeenCalledWith('error', jasmine.any(String))

      describe 'error is 408 (server timeout) or 504 (gateway timeout)', ->

        it 'displays timeout message', ->
          angular.forEach([408, 504], (errorCode) ->
            $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(errorCode, {})
            $scope.survey.save({}, true)
            $httpBackend.flush()
            expect(idFlashFactory.now).toHaveBeenCalledWith('error', jasmine.any(String))
          )

      describe 'error is 500', ->
        it 'displays server error message', ->
          $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(500, {})
          $scope.survey.save({}, true)
          $httpBackend.flush()
          expect(idFlashFactory.now).toHaveBeenCalledWith('error', jasmine.any(String))

      describe 'error is 503', ->
        it 'displays maintenance message', ->
          $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(503, {})
          $scope.survey.save({}, true)
          $httpBackend.flush()
          expect(idFlashFactory.now).toHaveBeenCalledWith('error', jasmine.any(String))

    describe 'andContinue=true', ->

      afterEach ->
        $httpBackend.verifyNoOutstandingExpectation()

      it 'POSTs survey.responses to /call_center/api/:call_id/submit_result', ->
        expectedData = {
          question: {"1": 321},
          notes: {"1": "Some text"}
        }
        $scope.survey.responses = expectedData
        $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result", expectedData).respond(200, {})
        $scope.survey.save({}, true)

    describe 'andContinue=false', ->

        afterEach ->
          $httpBackend.verifyNoOutstandingExpectation()

      it 'POSTs survey.responses to /call_center/api/:call_id/submit_result_and_stop', ->
        $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result_and_stop").respond({})
        $scope.survey.save({}, false)
