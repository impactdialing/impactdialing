describe 'survey module', ->

  describe 'idSurvey directive', ->

    $rootScope = ''
    $compile = ''
    $httpBackend = ''
    surveyTemplate = ''
    scope = ''
    ele = ''

    # Load module under test
    beforeEach module 'survey'

    # Load template module
    # beforeEach module '/scripts/survey/survey.tpl.html'

    beforeEach(inject((_$rootScope_, _$compile_, _$httpBackend_) ->
      $rootScope = _$rootScope_
      $compile = _$compile_
      $httpBackend = _$httpBackend_
      $httpBackend.whenGET('/call_center/api/survey_fields.json').respond({})
      @tpl = '<div data-id-survey></div>'
      scope = $rootScope
      scope.survey = {}
      ele = $compile(@tpl)(scope)
      scope.$digest()
    ))

    it 'contains a "Save & stop calling" button', ->
      el = angular.element(ele.find('button')[0])
      expect(el.text()).toEqual('Save & stop calling')

    it 'contains a "Save & continue" button', ->
      el = angular.element(ele.find('button')[1])
      expect(el.text()).toEqual('Save & continue')

    it 'hides buttons when survey.hideButtons = true', ->
      scope.$apply('survey.hideButtons = true')
      el = angular.element(ele.find('div')[2])
      expect(el.hasClass('btn-group ng-hide')).toBeTruthy()

    it 'shows buttons when survey.hideButtons = false', ->
      scope.$apply('survey.hideButtons = false')
      el = angular.element(ele.find('div')[2])
      expect(el.hasClass('btn-group ng-hide')).toBeFalsy()

    it 'renders item.content from scriptText type items to <pre/>', ->
      scope.$apply("survey.form = [
        {type: 'scriptText', content: 'Lorem Ipsum dolla etsa...'}
      ]")
      el = angular.element(ele.find('pre')[0])
      expect(el.text()).toEqual('Lorem Ipsum dolla etsa...')

    it 'renders item.content from !scriptText type items to label', ->
      scope.$apply("survey.form = [{type: 'blah', content: 'myLabel'}]")
      el = angular.element(ele.find('label')[0])
      expect(el.text()).toEqual('myLabel')

    it 'sets label:for attr to "item_{{item.id}}"', ->
      scope.$apply("survey.form = [{type: 'blah', id: 'myFor'}]")
      el = angular.element(ele.find('label')[0])
      expect(el.attr('for')).toEqual('item_myFor')

    it 'renders <input> w/ id of item_{{item.id}} for note type items', ->
      scope.$apply("survey.form = [{type: 'note', id: 'myNote'}]")
      el = angular.element(ele.find('input')[0])
      expect(el.attr('id')).toEqual('item_myNote')

    it 'binds <input> to survey.responses.notes[item.id]', ->
      scope.$apply("survey.form = [{type: 'note', id: 'myNote'}]")
      scope.$apply("survey.responses = {notes: {myNote: 'notes are neat'}}")
      el = angular.element(ele.find('input')[0])
      expect(el.val()).toEqual('notes are neat')

    it 'renders <select/> w/ id of item_{{item.id}} for question type items', ->
      scope.$apply("survey.form = [{type: 'question', id: 'myQuestion'}]")
      el = angular.element(ele.find('select')[0])
      expect(el.attr('id')).toEqual('item_myQuestion')

    it 'renders <option/>s from item.possibleResponses', ->
      scope.$apply("survey.form = [{
        type: 'question',
        id: 'myQuestion',
        possibleResponses: [
          {id: 'resp_1', value: 'Blue'},
          {id: 'resp_2', value: 'Green'}
        ]
      }]")
      expect(ele.find('option').length).toEqual(3)
      el = angular.element(ele.find('option')[1])
      expect(el.attr('value')).toEqual('resp_1')
      expect(el.text()).toEqual('Blue')
      el = angular.element(ele.find('option')[2])
      expect(el.attr('value')).toEqual('resp_2')
      expect(el.text()).toEqual('Green')

    it 'binds <select/> to survey.responses.answers[item.id]', ->
      scope.$apply("survey.form = [{
        type: 'question',
        id: 'myQuestion',
        possibleResponses: [
          {id: 'resp_1', value: 'Blue'},
          {id: 'resp_2', value: 'Green'}
        ]
      }]")
      scope.$apply("survey.responses = {answers: {myQuestion: 'resp_2'}}")
      el = angular.element(ele.find('select')[0])
      expect(el.val()).toEqual('resp_2')
