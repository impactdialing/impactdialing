'use strict'

surveyForm = angular.module('survey', [
  'ui.router',
  'angularSpinner',
  'idFlash'
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
  '$rootScope', '$scope', '$filter', '$state', '$http', '$cacheFactory', 'usSpinnerService', '$timeout', 'SurveyFormFieldsFactory', 'idFlashFactory'
  ($rootScope,   $scope,   $filter,   $state,   $http,   $cacheFactory,   usSpinnerService,   $timeout,   SurveyFormFieldsFactory,   idFlashFactory) ->
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
        reset()
      error = (resp) ->
        console.log 'error', resp
        msg = 'Survey results failed to save.'
        switch resp.status
          when 400 # bad request, try again and contact support
            msg += ' The browser sent a bad request.'
          when 408, 504 # server/gatewa timeout, try again and contact support
            msg += ' The browser took too long sending the data. Verify the internet connection before trying again and Report problem if the error continues.'
          when 500 # server error, try again and contact support
            msg += ' Server is having some trouble. We are looking into it and will update account holders soon. Please Report problem then Stop calling.'
          when 503 # server unavailable/in maintenance, wait a minute, try again and contact support
            msg += ' Server undergoing minor maintenance. Please try again in a minute or so and Report problem if the error continues.'
          else
            msg += ' Please try again and Report problem if the error continues.'
        idFlashFactory.now('error', msg)
      notify = (resp) ->
        console.log 'notify', resp
      always = (resp) ->
        survey.saving = false
        usSpinnerService.stop('global-spinner')

      # make a request, get a promise
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
