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

##
# SurveyFormCtrl manages
# - loading of survey form data, including the list of transfers
#   associated w/ the campaign
# - saving survey responses
#
# Notifications:
# - survey:load:success - $broadcast when form data is fetched and loaded.
# - survey:save:success, {andContinue} - $broadcast when survey save returns success response
# - survey:save:done, {andContinue} - $broadcast when survey save returns failure response
#
# Listeners:
# - $stateChangeSuccess - triggers hide/show buttons according to toState.name
# - survey:save:click - triggers survey response submission
# - survey:reload - triggers re-fetch/load of survey form data & transfer list
#
surveyForm.controller('SurveyFormCtrl', [
  '$rootScope', '$scope', '$filter', '$state', '$http', 'TransferCache', 'CallCache', 'usSpinnerService', '$timeout', 'SurveyFormFieldsFactory', 'idFlashFactory', 'SurveyCache',
  ($rootScope,   $scope,   $filter,   $state,   $http,   TransferCache,   CallCache,   usSpinnerService,   $timeout,   SurveyFormFieldsFactory,   idFlashFactory,   SurveyCache) ->
    # Init public
    survey = {
      hideButtons: true
    }

    # :tmp: to maintain back compat (where transfers are sent alongside call script data)
    # todo: move transfer data out of survey related modules to dialer
    cacheTransferList = (payload) ->
      list          = payload.data.transfers
      coldOnly      = (transfer) -> transfer.transfer_type == 'cold'
      list          = $filter('filter')(list, coldOnly)
      TransferCache.put('list', list)
    # :endtmp:

    fetchErr = (e) ->
      ErrorCache.put('SurveyFormFieldsFactory.fetch.failed', e)
      idFlashFactory.now('danger', 'Survey failed to load. Please refresh the page to try again.')
    prepForm = (payload) ->
      SurveyFormFieldsFactory.prepareSurveyForm(payload)
      survey.form = SurveyFormFieldsFactory.data
      # :tmp:
      cacheTransferList(payload)
      # :endtmp:
      $rootScope.$broadcast('survey:load:success')

    loadForm = ->
      SurveyFormFieldsFactory.fetch().then(prepForm, fetchErr)

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      switch toState.name
        when 'dialer.wrap'
          survey.hideButtons = false
        else
          survey.hideButtons = true

    $rootScope.$on('$stateChangeSuccess', handleStateChange)

    # Public API
    survey.responses = {
      notes: {}
      question: {}
    }

    requestInProgress = false
    survey.save = ($event, andContinue) ->
      if requestInProgress
        console.log 'survey.requestInProgress, returning'
        return

      call_id = CallCache.get('id')
      unless call_id?
        ErrorCache.put('survey.save.failed', "CallCache had no ID.")
        idFlashFactory.now('danger', 'You found a bug! Please Report problem and we will have you up and running ASAP.')
        return

      usSpinnerService.spin('global-spinner')

      action = 'submit_result'
      action += '_and_stop' unless andContinue

      successRan = false
      success = (resp) ->
        console.log 'survey.success', resp
        reset()
        idFlashFactory.now('success', 'Results saved.', 4000)
        $rootScope.$broadcast('survey:save:success', {andContinue})
        successRan = true
      error = (resp) ->
        console.log 'survey.error', resp
        msg = ''
        switch resp.status
          when 400 # bad request, try again and contact support
            msg += 'Bad request. Try again and Report problem if error continues.'
          when 408, 504 # server/gatewa timeout, try again and contact support
            msg += 'Browser took too long sending data. Verify internet connection and try again. Report problem if the error continues.'
          when 500 # server error, try again and contact support
            msg += 'Server error. We have been notified and will update account holders soon. Report problem then Stop calling.'
          when 503 # server unavailable/in maintenance, wait a minute, try again and contact support
            msg += 'Minor maintenance in-progress. Try again in a minute or so. Report problem if the error continues.'
          else
            msg += 'Please try again and Report problem if the error continues.'
        idFlashFactory.now('danger', msg)
        $rootScope.transitionInProgress = false
      always = (resp) ->
        console.log 'survey.always, successRan', successRan
        requestInProgress = false

        if andContinue and successRan
          usSpinnerService.spin('global-spinner')
        else
          usSpinnerService.stop('global-spinner')
          $rootScope.transitionInProgress = false

        $rootScope.$broadcast('survey:save:done', {andContinue})

      requestInProgress               = true
      $rootScope.transitionInProgress = true
      # make a request, get a promise
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
