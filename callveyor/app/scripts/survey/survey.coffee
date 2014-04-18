'use strict'

surveyForm = angular.module('survey', [
  'ui.router',
  'angularSpinner'
])

# surveyForm.config([])

surveyForm.factory('SurveyFormFieldsFactory', [
  '$http', '$filter',
  ($http,   $filter) ->
    fields = {
      data: {}
      prepareSurveyForm: (payload) ->
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

        fields.data = $filter('orderBy')(normalizedSurvey, 'order')

      fetch: ->
        $http.get('/call_center/api/survey_fields.json')
    }
])

surveyForm.controller('SurveyFormCtrl', [
  '$rootScope', '$scope', '$filter', '$state', '$http', '$cacheFactory', 'usSpinnerService', '$timeout', 'SurveyFormFieldsFactory'
  ($rootScope,   $scope,   $filter,   $state,   $http,   $cacheFactory,   usSpinnerService,   $timeout,   SurveyFormFieldsFactory) ->
    callStationCache = $cacheFactory.get('callStation')
    if callStationCache?
      callStation = callStationCache.get('data')
      caller = callStation.caller
    # Init public
    survey = {}

    e = (r) -> console.log 'survey load error', r.stack, r.message
    c = (r) -> console.log 'survey load notify', r.stack, r.message
    prepForm = (payload) ->
      SurveyFormFieldsFactory.prepareSurveyForm(payload)
      survey.form = SurveyFormFieldsFactory.data

    SurveyFormFieldsFactory.fetch().then(prepForm, e, c)

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      switch toState.name
        when 'dialer.wrap'
          survey.hideButtons = false
        else
          surve.hideButtons = true

    # Public API
    survey.responses = {
      notes: {}
      question: {}
    }
    survey.saving = false
    survey.hideButtons = true

    survey.save = ($event, andContinue) ->
      return if survey.saving

      usSpinnerService.spin('global-spinner')
      survey.saving = true

      action = 'submit_result'
      action += '_and_stop' unless andContinue

      success = (resp) ->
        console.log 'success', resp
        reset()
      error = (resp) ->
        console.log 'error', resp
      notify = (resp) ->
        console.log 'notify', resp
      always = (resp) ->
        console.log 'always', resp
        survey.saving = false
        usSpinnerService.stop('global-spinner')

      # make a request, get a promise
      console.log 'making request'
      $http.post("/call_center/api/#{caller.id}/#{action}", survey.responses)
      .then(success, error, notify).finally(always)

      reset = ->
        survey.responses = {
          notes: {}
          question: {}
        }

      # fakeSave = ->
      #   if andContinue
      #     $state.go('dialer.hold')
      #   else
      #     $state.go('dialer.stop')
      #   # Pretend success
      #   usSpinnerService.stop('global-spinner')
      #   # angular.element($event.target).parent().children().prop('disabled', false)
      #   survey.saving = false
      #   reset()
      # $timeout(fakeSave, 3000)

    $scope.survey ||= survey
])

surveyForm.directive('idSurvey', ->
  {
    restrict: 'A'
    templateUrl: '/callveyor/survey/survey.tpl.html'
    controller: 'SurveyFormCtrl'
  }
)
