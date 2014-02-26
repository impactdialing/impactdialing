'use strict'

surveyForm = angular.module('callveyor.dialer.survey', [])

surveyForm.config(['$stateProvider', ($stateProvider) ->

])

surveyForm.controller('SurveyFormCtrl', [
  '$scope', '$filter', '$state', '$http', 'usSpinnerService', '$timeout'
  ($scope,   $filter,   $state,   $http,   usSpinnerService,   $timeout) ->
    console.log 'SurveyFormCtrl', $scope.dialer
    # Init public
    survey = {}

    surveyFormData = $http.get('/scripts/dialer/survey/script.json')

    e = (r) -> console.log 'survey load error', r.stack, r.message
    c = (r) -> console.log 'survey load notify', r.stack, r.message

    prepareSurveyForm = (payload) ->
      console.log 'prepareSurveyForm', payload
      selectNonEmpty = (val) -> val?

      normalizeObj = (object, type) ->
        obj = {
          id: object.id
          order: object.script_order
          type: ''
          content: ''
        }
        switch type
          when 'notes'
            obj.type = 'note'
            obj.content = object.note
          when 'script_texts'
            obj.type = 'scriptText'
            obj.content = object.content
          when 'questions'
            obj.type = 'question'
            obj.content = object.text
            obj.possibleResponses = $filter('filter')(object.possible_responses, selectNonEmpty)
        obj

      normalizedSurvey = []
      normalizeSurvey  = (arr, type) ->
        switch type
          when 'notes', 'script_texts', 'questions'
            angular.forEach(arr, (obj) ->
              normalizedSurvey.push(normalizeObj(obj, type))
            )

      angular.forEach(payload.data, (obj, type) ->
        normalizeSurvey(obj, type)
      )
      # For the public
      survey.form = $filter('orderBy')(normalizedSurvey, 'order')

    # When $http promise resolves...
    surveyFormData.then(prepareSurveyForm, e, c)

    # Public API
    survey.responses = {
      notes: {}
      answers: {}
    }
    survey.saving = false
    survey.hideButtons = -> !$state.is('dialer.wrap')
    survey.save = ($event, andContinue) ->
      console.log 'survey.save clicked', $event
      if survey.saving
        console.log 'Save in progress. Button press is no-op.'
        return
      usSpinnerService.spin('global-spinner')
      angular.element($event.target).parent().children().prop('disabled', true)
      survey.saving = true

      # p = $http.post('/survey/responses')
      # s = (r) -> console.log 'success', r.stack, r.message
      # e = (r) -> console.log 'error', r.stack, r.message
      # c = (r) -> console.log 'notify', r.stack, r.message
      # p.then(s,e,c)
      reset = ->
        survey.responses = {
          notes: {}
          answers: {}
        }

      fakeSave = ->
        if andContinue
          $state.go('dialer.hold')
        else
          $state.go('dialer.stop')
        # Pretend success
        usSpinnerService.stop('global-spinner')
        angular.element($event.target).parent().children().prop('disabled', false)
        survey.saving = false
        reset()
      $timeout(fakeSave, 3000)

    $scope.survey = survey
])

surveyForm.directive('idSurvey', ->
  {
    restrict: 'A'
    templateUrl: '/scripts/dialer/survey/survey.tpl.html'
  }
)
