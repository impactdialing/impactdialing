'use strict'

callScript = angular.module('callveyor.dialer.callScript', [])

callScript.config(['$stateProvider', ($stateProvider) ->

])

callScript.controller('SurveyFormCtrl', [
  '$scope', '$filter', '$state'
  ($scope,   $filter,   $state) ->
    console.log 'SurveyFormCtrl', $scope.dialer.callScript

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
          obj.possibleResponses = object.possible_responses
      obj

    normalizedSurvey = []
    normalizeSurvey  = (arr, type) ->
      switch type
        when 'notes', 'script_texts', 'questions'
          angular.forEach(arr, (obj) ->
            normalizedSurvey.push(normalizeObj(obj, type))
          )

    angular.forEach($scope.dialer.callScript, (obj, type) ->
      normalizeSurvey(obj, type)
    )

    # Public API
    survey = {
      form: $filter('orderBy')(normalizedSurvey, 'order')
      responses: {
        notes: {}
        answers: {}
      }
      save: (andContinue) ->
        # p = $http.post('/survey/responses')
        # s = (r) -> console.log 'success', r.stack, r.message
        # e = (r) -> console.log 'error', r.stack, r.message
        # c = (r) -> console.log 'notify', r.stack, r.message
        # p.then(s,e,c)
        andContinue = confirm("Pretend it saved!\nOk to continue calling.\nCancel to stop calling.")
        if andContinue
          $state.go('dialer.hold')
        else
          $state.go('dialer.stop')
    }

    $scope.dialer.survey = survey
])
