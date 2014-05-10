'use strict'

surveyForm = angular.module('survey', [
  'ui.router',
  'angularSpinner',
  'idFlash',
  'idCacheFactories'
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
  '$rootScope', '$scope', '$filter', '$state', '$http', 'TransferCache', 'CallCache', 'usSpinnerService', '$timeout', 'SurveyFormFieldsFactory', 'idFlashFactory', 'SurveyCache',
  ($rootScope,   $scope,   $filter,   $state,   $http,   TransferCache,   CallCache,   usSpinnerService,   $timeout,   SurveyFormFieldsFactory,   idFlashFactory,   SurveyCache) ->
    # Init public
    survey = {}

    # :tmp: to maintain back compat (where transfers are sent alongside call script data)
    # todo: move transfer data out of survey related modules to dialer
    cacheTransferList = (payload) ->
      list          = payload.data.transfers
      coldOnly      = (transfer) -> transfer.transfer_type == 'cold'
      list          = $filter('filter')(list, coldOnly)
      TransferCache.put('list', list)
    # :endtmp:

    fetchErr = (e) ->
      ErrorCache.put('SurveyFormFieldsFactory.fetch Error', e)
      idFlashFactory.now('error', 'Survey failed to load. Please refresh the page to try again.')
    prepForm = (payload) ->
      SurveyFormFieldsFactory.prepareSurveyForm(payload)
      survey.form = SurveyFormFieldsFactory.data
      survey.disable = false
      # :tmp:
      cacheTransferList(payload)
      # :endtmp:
      $rootScope.$broadcast('survey:load:success')

    loadForm = ->
      survey.disable = true
      SurveyFormFieldsFactory.fetch().then(prepForm, fetchErr)

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      switch toState.name
        when 'dialer.wrap'
          survey.hideButtons = false
        else
          survey.disable = false
          survey.hideButtons = true

    $rootScope.$on('$stateChangeSuccess', handleStateChange)

    # Public API
    survey.responses = {
      notes: {}
      question: {}
    }
    survey.disable = false
    survey.hideButtons = true
    survey.requestInProgress = false

    survey.save = ($event, andContinue) ->
      if survey.requestInProgress
        # console.log 'survey.requestInProgress', survey.requestInProgress
        return

      survey.disable = true

      if CallCache?
        call_id = CallCache.get('id')
      else
        # submit error report somewhere
        idFlashFactory.now('error', 'You found a bug! Please Report problem and we will have you up and running ASAP.')
        return

      usSpinnerService.spin('global-spinner')

      action = 'submit_result'
      action += '_and_stop' unless andContinue

      success = (resp) ->
        reset()
        idFlashFactory.now('success', 'Results saved.', 4000)
        $rootScope.$broadcast('survey:save:success', {andContinue})
      error = (resp) ->
        # console.log 'error', resp
        msg = 'Survey results failed to save.'
        switch resp.status
          when 400 # bad request, try again and contact support
            msg += ' The browser sent a bad request. Please try again and Report problem if error continues.'
          when 408, 504 # server/gatewa timeout, try again and contact support
            msg += ' The browser took too long sending the data. Verify the internet connection before trying again and Report problem if the error continues.'
          when 500 # server error, try again and contact support
            msg += ' Server is having some trouble. We are looking into it and will update account holders soon. Please Report problem then Stop calling.'
          when 503 # server unavailable/in maintenance, wait a minute, try again and contact support
            msg += ' Server is undergoing minor maintenance. Please try again in a minute or so and Report problem if the error continues.'
          else
            msg += ' Please try again and Report problem if the error continues.'
        idFlashFactory.now('error', msg)
      always = (resp) ->
        survey.requestInProgress = false
        usSpinnerService.stop('global-spinner')
        $rootScope.$broadcast('survey:save:done', {andContinue})

      # make a request, get a promise
      survey.requestInProgress = true
      $http.post("/call_center/api/#{call_id}/#{action}", survey.responses)
      .then(success, error).finally(always)

      reset = ->
        survey.responses = {
          notes: {}
          question: {}
        }

    unless SurveyCache.get('eventsBound')
      $rootScope.$on('survey:save:click', survey.save)
      $rootScope.$on('survey:reload', loadForm)
      SurveyCache.put('eventsBound', true)

    loadForm()

    $scope.survey ||= survey
])

surveyForm.directive('idSurvey', ->
  {
    restrict: 'A'
    templateUrl: '/callveyor/survey/survey.tpl.html'
    controller: 'SurveyFormCtrl'
  }
)
