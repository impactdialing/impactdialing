describe 'survey controller', ->
  $scope = ''
  $rootScope = ''
  $controller = ''
  $httpBackend = ''
  $cacheFactory = ''
  usSpinnerService = ''
  SurveyFormFieldsFactory = ''
  CallCache = ''
  idFlashFactory = ''

  call = {id: 3}

  beforeEach(module('survey'))

  beforeEach(inject((_$rootScope_, _$controller_, _$httpBackend_, _$cacheFactory_, _usSpinnerService_, _SurveyFormFieldsFactory_, _idFlashFactory_, _ErrorCache_, _CallCache_) ->
    $rootScope              = _$rootScope_
    $controller             = _$controller_
    $scope                  = $rootScope
    $httpBackend            = _$httpBackend_
    $cacheFactory           = _$cacheFactory_
    idFlashFactory          = _idFlashFactory_
    CallCache               = _CallCache_
    ErrorCache              = _ErrorCache_
    usSpinnerService        = _usSpinnerService_
    SurveyFormFieldsFactory = _SurveyFormFieldsFactory_

    CallCache.put('id', call.id)
    $httpBackend.whenGET('/call_center/api/survey_fields.json').respond({})
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

  describe 'survey.save($event, andContinue=true|false) request completes UNsuccessfully', ->
    beforeEach ->
      $httpBackend.whenPOST("/call_center/api/#{call.id}/submit_result").respond(400, {})
      usSpinnerService.spin = jasmine.createSpy('-usSpinnerService.spin Spy-')
      usSpinnerService.stop = jasmine.createSpy('-usSpinnerService.stop Spy-')
      @notes = {"42": "some notes"}
      @question = {"73": {id: 12, value: "Yes"}}

    it 'stops the global spinner', ->
      $scope.survey.save({}, true)
      $httpBackend.flush()
      expect(usSpinnerService.stop).toHaveBeenCalled()

    it 'sets $rootScope.transitionInProgress to false', ->
      $scope.survey.save({}, true)
      $httpBackend.flush()
      expect($rootScope.transitionInProgress).toBeFalsy()

    it '$broadcasts survey:save:done, {andContinue}', ->
      spy = jasmine.createSpy('--survey:save:done spy--')
      $rootScope.$on('survey:save:done', spy)
      $scope.survey.save({}, true)
      $httpBackend.flush()
      expect(spy).toHaveBeenCalledWith(jasmine.any(Object), {andContinue: true})

  describe 'survey.save($event, andContinue=true|false)', ->
    beforeEach ->
      $httpBackend.whenPOST("/call_center/api/#{call.id}/submit_result").respond(200, {})
      $httpBackend.whenPOST("/call_center/api/#{call.id}/submit_result_and_stop").respond(200, {})
      usSpinnerService.spin = jasmine.createSpy('-usSpinnerService.spin Spy-')
      usSpinnerService.stop = jasmine.createSpy('-usSpinnerService.stop Spy-')
      @notes = {"42": "some notes"}
      @question = {"73": {id: 12, value: "Yes"}}

    it 'is a no-op if survey.requestInProgress is true', ->
      $scope.survey.save()
      $scope.survey.save()
      expect(usSpinnerService.spin.calls.length).toEqual(1)

    it 'spins the global spinner', ->
      $scope.survey.save({})
      expect(usSpinnerService.spin).toHaveBeenCalled()

    describe 'request completes successfully', ->
      it 'spins the global spinner when andContinue is true', ->
        $scope.survey.save({}, true)
        $httpBackend.flush()
        expect(usSpinnerService.spin).toHaveBeenCalled()

      it 'stops the global spinner when andContinue is false', ->
        $scope.survey.save({}, false)
        $httpBackend.flush()
        $httpBackend.verifyNoOutstandingRequest()
        expect(usSpinnerService.stop).toHaveBeenCalled()

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
        expect(idFlashFactory.now).toHaveBeenCalledWith('danger', jasmine.any(String))

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
          expect(idFlashFactory.now).toHaveBeenCalledWith('danger', jasmine.any(String))

      describe 'error is 408 (server timeout) or 504 (gateway timeout)', ->

        it 'displays timeout message', ->
          angular.forEach([408, 504], (errorCode) ->
            $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(errorCode, {})
            $scope.survey.save({}, true)
            $httpBackend.flush()
            expect(idFlashFactory.now).toHaveBeenCalledWith('danger', jasmine.any(String))
          )

      describe 'error is 500', ->
        it 'displays server error message', ->
          $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(500, {})
          $scope.survey.save({}, true)
          $httpBackend.flush()
          expect(idFlashFactory.now).toHaveBeenCalledWith('danger', jasmine.any(String))

      describe 'error is 503', ->
        it 'displays maintenance message', ->
          $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result").respond(503, {})
          $scope.survey.save({}, true)
          $httpBackend.flush()
          expect(idFlashFactory.now).toHaveBeenCalledWith('danger', jasmine.any(String))

    describe 'andContinue=true', ->

      afterEach ->
        $httpBackend.verifyNoOutstandingExpectation()

      it 'POSTs survey.responses to /call_center/api/:call_id/submit_result', ->
        responses = {
          question: {"1": {id: 321, value: 'Yes'}},
          notes: {"1": "Some text"}
        }
        expectedData = {
          question: {"1": responses.question["1"].id},
          notes: responses.notes
        }
        $scope.survey.responses = responses
        $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result", expectedData).respond(200, {})
        $scope.survey.save({}, true)

    describe 'andContinue=false', ->

        afterEach ->
          $httpBackend.verifyNoOutstandingExpectation()

      it 'POSTs survey.responses to /call_center/api/:call_id/submit_result_and_stop', ->
        $httpBackend.expectPOST("/call_center/api/#{call.id}/submit_result_and_stop").respond({})
        $scope.survey.save({}, false)
